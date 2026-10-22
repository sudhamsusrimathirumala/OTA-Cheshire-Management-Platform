import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_environment.dart';
import '../models/user_account.dart';
import 'debug_view_controller.dart';
import 'firebase/firebase_session_controller.dart';

const otaUpdatesChannelId = 'ota_updates';
const otaUpdatesChannelName = 'OTA Updates';

abstract interface class PushTokenProvider {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();
}

class FirebasePushTokenProvider implements PushTokenProvider {
  FirebasePushTokenProvider(this.messaging);

  final FirebaseMessaging messaging;

  @override
  Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus != AuthorizationStatus.denied;
  }

  @override
  Future<String?> getToken() => messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => messaging.deleteToken();
}

abstract interface class DeviceRegistrationStore {
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
    required String environment,
  });

  Future<void> delete({required String uid, required String installationId});
}

class FirestoreDeviceRegistrationStore implements DeviceRegistrationStore {
  FirestoreDeviceRegistrationStore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
    required String environment,
  }) async {
    final reference = firestore
        .collection('users')
        .doc(uid)
        .collection('pushDevices')
        .doc(installationId);
    final exists = (await reference.get()).exists;
    await reference.set({
      'fcmToken': token,
      'platform': platform,
      'appEnvironment': environment,
      'enabled': true,
      if (!exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete({required String uid, required String installationId}) =>
      firestore
          .collection('users')
          .doc(uid)
          .collection('pushDevices')
          .doc(installationId)
          .delete();
}

abstract interface class InstallationIdStore {
  Future<String> getOrCreate();
}

class SharedPreferencesInstallationIdStore implements InstallationIdStore {
  static const _key = 'ota_push_installation_id';

  @override
  Future<String> getOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key);
    if (existing != null && existing.length == 32) return existing;
    final random = Random.secure();
    final generated = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await preferences.setString(_key, generated);
    return generated;
  }
}

class PushNotificationService {
  PushNotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    PushTokenProvider? tokenProvider,
    InstallationIdStore? installationIds,
    DeviceRegistrationStore? registrationStore,
  }) : _messaging = messaging,
       _tokenProvider =
           tokenProvider ??
           FirebasePushTokenProvider(messaging ?? FirebaseMessaging.instance),
       _installationIds =
           installationIds ?? SharedPreferencesInstallationIdStore(),
       _registrationStore =
           registrationStore ??
           FirestoreDeviceRegistrationStore(
             firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseMessaging? _messaging;
  final PushTokenProvider _tokenProvider;
  final InstallationIdStore _installationIds;
  final DeviceRegistrationStore _registrationStore;
  StreamSubscription<String>? _tokenSubscription;
  String? _registeredUid;
  String? _installationId;
  String? _registrationFingerprint;
  int _registrationGeneration = 0;
  int? _runningGeneration;
  String? _sessionUid;
  Future<String>? _installationIdLoad;
  Future<void>? _registrationWrite;
  bool _permissionRequested = false;
  bool? _permissionGranted;
  final diagnostics = ValueNotifier<PushDiagnostics>(
    const PushDiagnostics(state: PushRegistrationState.idle),
  );

  Future<void> handleSession(
    FirebaseSessionController session, {
    bool refreshPermission = false,
  }) async {
    final account = session.account;
    final eligible = shouldRegisterPushDevice(
      stage: session.stage,
      account: account,
      hasAuthenticatedUser: session.authUser != null,
      debugViewActive: debugViewController.isActive,
    );
    final uid = eligible ? account!.id : null;
    if (_sessionUid != uid) {
      _sessionUid = uid;
      ++_registrationGeneration;
    }
    if (!eligible || uid == null) {
      diagnostics.value = PushDiagnostics(
        state: PushRegistrationState.idle,
        sessionEligible: false,
      );
      return;
    }
    final generation = _registrationGeneration;
    if (_runningGeneration == generation) return;
    _runningGeneration = generation;
    try {
      diagnostics.value = const PushDiagnostics(
        state: PushRegistrationState.requestingPermission,
        sessionEligible: true,
      );
      if (refreshPermission || !_permissionRequested) {
        final granted = await _tokenProvider.requestPermission();
        if (!_isCurrentRegistration(uid, generation)) return;
        _permissionGranted = granted;
        _permissionRequested = true;
      }
      if (_permissionGranted != true) {
        diagnostics.value = const PushDiagnostics(
          state: PushRegistrationState.permissionDenied,
          sessionEligible: true,
        );
        return;
      }
      diagnostics.value = const PushDiagnostics(
        state: PushRegistrationState.requestingToken,
        sessionEligible: true,
        permissionGranted: true,
      );
      final token = await _tokenProvider.getToken();
      if (!_isCurrentRegistration(uid, generation)) return;
      if (token == null || token.trim().isEmpty) {
        diagnostics.value = const PushDiagnostics(
          state: PushRegistrationState.tokenUnavailable,
          sessionEligible: true,
          permissionGranted: true,
        );
        return;
      }
      diagnostics.value = const PushDiagnostics(
        state: PushRegistrationState.writingRegistration,
        sessionEligible: true,
        permissionGranted: true,
        tokenExists: true,
      );
      await _writeRegistration(uid, token, generation);
      if (!_isCurrentRegistration(uid, generation)) return;
      diagnostics.value = const PushDiagnostics(
        state: PushRegistrationState.registered,
        sessionEligible: true,
        permissionGranted: true,
        tokenExists: true,
        registrationSucceeded: true,
      );
      await _tokenSubscription?.cancel();
      if (!_isCurrentRegistration(uid, generation)) return;
      _tokenSubscription = _tokenProvider.onTokenRefresh.listen((value) {
        if (value.trim().isNotEmpty && _isCurrentRegistration(uid, generation)) {
          unawaited(_refreshRegistration(uid, value, generation));
        }
      });
    } on FirebaseException catch (error) {
      if (_isCurrentRegistration(uid, generation)) _failed(error.code);
    } on PlatformException catch (error) {
      if (_isCurrentRegistration(uid, generation)) _failed(error.code);
    } catch (_) {
      if (_isCurrentRegistration(uid, generation)) _failed('unknown');
    } finally {
      if (_runningGeneration == generation) _runningGeneration = null;
    }
  }

  void _failed(String code) {
    diagnostics.value = PushDiagnostics(
      state: PushRegistrationState.failed,
      sessionEligible: true,
      permissionGranted: diagnostics.value.permissionGranted,
      tokenExists: diagnostics.value.tokenExists,
      errorCode: code.replaceAll(RegExp(r'[^a-zA-Z0-9_/-]'), '-'),
    );
  }

  bool _isCurrentRegistration(String uid, int generation) =>
      _sessionUid == uid && generation == _registrationGeneration;

  Future<void> _refreshRegistration(String uid, String token, int generation) async {
    try {
      await _writeRegistration(uid, token, generation);
      if (_isCurrentRegistration(uid, generation)) {
        diagnostics.value = const PushDiagnostics(
          state: PushRegistrationState.registered,
          sessionEligible: true,
          permissionGranted: true,
          tokenExists: true,
          registrationSucceeded: true,
        );
      }
    } on FirebaseException catch (error) {
      if (_isCurrentRegistration(uid, generation)) _failed(error.code);
    } catch (_) {
      if (_isCurrentRegistration(uid, generation)) _failed('token-refresh-failed');
    }
  }

  Future<void> _writeRegistration(String uid, String token, int generation) async {
    final installationId = _installationId ??= await (
      _installationIdLoad ??= _installationIds.getOrCreate()
    );
    if (!_isCurrentRegistration(uid, generation)) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    final environment = AppEnvironmentConfig.current.name;
    final fingerprint =
        '$uid\u0000$installationId\u0000$token\u0000$platform\u0000$environment';
    final previousWrite = _registrationWrite;
    final write = () async {
      try {
        await previousWrite;
      } catch (_) {
        // A later token can recover a failed registration.
      }
      if (!_isCurrentRegistration(uid, generation) ||
          _registrationFingerprint == fingerprint) return;
      await _registrationStore.upsert(
        uid: uid,
        installationId: installationId,
        token: token,
        platform: platform,
        environment: environment,
      );
      if (!_isCurrentRegistration(uid, generation)) return;
      _registeredUid = uid;
      _registrationFingerprint = fingerprint;
    }();
    _registrationWrite = write;
    try {
      await write;
    } finally {
      if (identical(_registrationWrite, write)) _registrationWrite = null;
    }
  }

  Future<void> unregisterForSignOut() async {
    final uid = _registeredUid ?? _sessionUid ?? FirebaseAuth.instance.currentUser?.uid;
    _sessionUid = null;
    final generation = ++_registrationGeneration;
    _registeredUid = null;
    _registrationFingerprint = null;
    final subscription = _tokenSubscription;
    _tokenSubscription = null;
    await subscription?.cancel();
    try {
      await _registrationWrite;
    } catch (_) {
      // Complete an in-flight write before removing its device document.
    }
    final installationId = _installationId ??= await (
      _installationIdLoad ??= _installationIds.getOrCreate()
    );
    try {
      if (uid != null) {
        await _registrationStore.delete(
          uid: uid,
          installationId: installationId,
        );
      }
    } catch (_) {
      // Sign-out cleanup is intentionally best effort.
    }
    if (generation != _registrationGeneration) return;
    try {
      await _tokenProvider.deleteToken();
    } catch (_) {
      // Token deletion must not prevent sign-out.
    }
  }

  FirebaseMessaging get messaging => _messaging ?? FirebaseMessaging.instance;
}

enum PushRegistrationState {
  idle,
  requestingPermission,
  permissionDenied,
  requestingToken,
  tokenUnavailable,
  writingRegistration,
  registered,
  failed,
}

class PushDiagnostics {
  const PushDiagnostics({
    required this.state,
    this.sessionEligible = false,
    this.permissionGranted = false,
    this.tokenExists = false,
    this.registrationSucceeded = false,
    this.errorCode,
  });
  final PushRegistrationState state;
  final bool sessionEligible;
  final bool permissionGranted;
  final bool tokenExists;
  final bool registrationSucceeded;
  final String? errorCode;
}

bool shouldRegisterPushDevice({
  required SessionStage stage,
  required UserAccount? account,
  required bool hasAuthenticatedUser,
  required bool debugViewActive,
}) =>
    hasAuthenticatedUser &&
    !debugViewActive &&
    stage == SessionStage.member &&
    account?.isActive == true &&
    (account?.role == UserAccountRole.parent ||
        account?.role == UserAccountRole.student) &&
    account!.linkedStudentProfileIds.isNotEmpty;

enum PushContentType { announcement, event, resource }

class PushDestination {
  const PushDestination({
    required this.type,
    required this.contentId,
    required this.locationId,
    this.occurrenceId,
    this.reminderId,
  });

  final PushContentType type;
  final String contentId;
  final String locationId;
  final String? occurrenceId;
  final String? reminderId;

  String encode() => jsonEncode({
    'contentType': type.name,
    'contentId': contentId,
    'locationId': locationId,
    if (occurrenceId != null) 'occurrenceId': occurrenceId,
    if (reminderId != null) 'reminderId': reminderId,
  });

  static PushDestination? tryParse(Map<String, dynamic> data) {
    final contentId = data['contentId'];
    final locationId = data['locationId'];
    final rawType = data['contentType'];
    if (contentId is! String ||
        contentId.trim().isEmpty ||
        locationId is! String ||
        locationId.trim().isEmpty ||
        rawType is! String) {
      return null;
    }
    final type = PushContentType.values
        .where((value) => value.name == rawType)
        .firstOrNull;
    if (type == null) return null;
    return PushDestination(
      type: type,
      contentId: contentId.trim(),
      locationId: locationId.trim(),
      occurrenceId: data['occurrenceId'] is String
          ? data['occurrenceId'] as String
          : null,
      reminderId: data['reminderId'] is String
          ? data['reminderId'] as String
          : null,
    );
  }

  static PushDestination? tryDecode(String? value) {
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? tryParse(Map<String, dynamic>.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }
}

class PendingPushDestination {
  PushDestination? _pending;
  String? _lastOpenedKey;

  void queue(PushDestination destination) => _pending = destination;

  PushDestination? takeIfAuthorized({
    required SessionStage stage,
    required String? memberLocationId,
    required bool navigatorReady,
  }) {
    final pending = _pending;
    if (pending == null ||
        !navigatorReady ||
        stage != SessionStage.member ||
        pending.locationId != memberLocationId) {
      return null;
    }
    final key =
        '${pending.type.name}:${pending.contentId}:${pending.locationId}:${pending.occurrenceId ?? ''}:${pending.reminderId ?? ''}';
    _pending = null;
    if (_lastOpenedKey == key) return null;
    _lastOpenedKey = key;
    return pending;
  }
}
