import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/student.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../firestore/firestore_collections.dart';
import 'firebase_app_data_service.dart';
import 'firebase_authentication_service.dart';
import 'firebase_identity_contract.dart';
import 'linked_profile_reconciler.dart';
import 'profile_service.dart';

enum SessionStage {
  loading,
  signedOut,
  needsProfiles,
  member,
  disabled,
  adminDisabled,
  admin,
  error,
}

class FirebaseSessionController extends ChangeNotifier {
  FirebaseSessionController({
    AuthenticationService? authentication,
    FirebaseFirestore? firestore,
    FirestoreProfileService? profileService,
  }) : authentication = authentication ?? FirebaseAuthenticationService(),
       _firestoreOverride = firestore,
       _profileServiceOverride = profileService;

  final AuthenticationService authentication;
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _database =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirestoreProfileService? _profileServiceOverride;
  FirestoreProfileService get profileService =>
      _profileServiceOverride ??= FirestoreProfileService();

  SessionStage stage = SessionStage.loading;
  User? authUser;
  UserAccount? account;
  List<StudentProfile> profiles = const [];
  StudentProfile? selectedProfile;
  String? selectedLocationName;
  String? errorMessage;
  bool justCreatedProfiles = false;
  bool _started = false;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _profilesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _locationSubscription;
  int _sessionGeneration = 0;
  int _profilesGeneration = 0;
  int _locationGeneration = 0;
  String? _profilesLinkedFingerprint;
  String? _profileRecoveryFingerprint;
  bool _profileCreationInProgress = false;
  bool _disposed = false;

  bool get hasActiveAcademyAccess => stage == SessionStage.member;
  bool get isAdministrator => stage == SessionStage.admin;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = authentication.authStateChanges().listen(
      (user) => unawaited(_replaceAuthUser(user)),
      onError: (_) => _setError('Unable to observe authentication state.'),
    );
  }

  Future<void> retry() async {
    final user = authentication.currentUser;
    if (user == null) {
      await _replaceAuthUser(null);
      return;
    }
    stage = SessionStage.loading;
    errorMessage = null;
    notifyListeners();
    await authentication.refreshUser();
    await _replaceAuthUser(authentication.currentUser);
  }

  Future<void> signOut() async {
    justCreatedProfiles = false;
    ++_sessionGeneration;
    ++_profilesGeneration;
    ++_locationGeneration;
    stage = SessionStage.loading;
    notifyListeners();
    await authentication.signOut();
    await _replaceAuthUser(null);
  }

  Future<void> createProfiles(ProfileCreationRequest request) async {
    _profileCreationInProgress = true;
    try {
      await profileService.createProfiles(request);
    } finally {
      _profileCreationInProgress = false;
    }
    justCreatedProfiles = true;
    final user = authUser;
    if (user == null) {
      notifyListeners();
      return;
    }
    await _replaceAuthUser(user);
  }

  void dismissCreatedConfirmation() {
    justCreatedProfiles = false;
    notifyListeners();
  }

  Future<void> selectProfile(String profileId) async {
    await profileService.selectProfile(profileId);
  }

  Future<void> _replaceAuthUser(User? user) async {
    final generation = ++_sessionGeneration;
    _profilesGeneration++;
    _locationGeneration++;
    await _cancelFirestoreSubscriptions();
    if (_disposed || generation != _sessionGeneration) return;
    authUser = user;
    account = null;
    profiles = const [];
    selectedProfile = null;
    selectedLocationName = null;
    errorMessage = null;
    if (user == null) {
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }
    stage = SessionStage.loading;
    notifyListeners();
    _userSubscription = _database
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (_isCurrentSession(generation, user.uid)) {
              _handleUserSnapshot(snapshot, generation);
            }
          },
          onError: (_) {
            if (_isCurrentSession(generation, user.uid)) {
              _setError('Unable to load your OTA account.');
            }
          },
        );
  }

  void _handleUserSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    int sessionGeneration,
  ) {
    final data = snapshot.data();
    if (data == null) {
      if (shouldHoldProfileSetupDuringCreation(
        creationInProgress: _profileCreationInProgress,
        current: stage,
      )) {
        errorMessage = null;
        notifyListeners();
        return;
      }
      account = null;
      profiles = const [];
      selectedProfile = null;
      unawaited(_replaceProfilesSubscription(null, sessionGeneration));
      stage = SessionStage.needsProfiles;
      errorMessage = null;
      notifyListeners();
      return;
    }
    try {
      account = userAccountFromFirestoreData(snapshot.id, data);
    } catch (_) {
      if (shouldRetainAccountForPendingSnapshot(
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        hasValidAccount: account != null,
        profileCreationInProgress: _profileCreationInProgress,
      )) {
        errorMessage = null;
        notifyListeners();
        return;
      }
      _setError('Your account record is incomplete or invalid.');
      return;
    }

    final loadedAccount = account!;
    if (loadedAccount.role == UserAccountRole.admin ||
        loadedAccount.role == UserAccountRole.superAdmin) {
      final evaluatedStage = adminAccessStageFor(account: loadedAccount);
      stage = evaluatedStage == SessionStage.loading
          ? sessionStageDuringAccessRefresh(
              current: stage,
              established: SessionStage.admin,
            )
          : evaluatedStage;
      if (stage == SessionStage.adminDisabled) {
        errorMessage = 'This administrator account is disabled.';
        unawaited(_cancelLocationSubscription());
      } else if (stage == SessionStage.admin) {
        errorMessage = null;
        unawaited(_cancelLocationSubscription());
      } else {
        unawaited(_replaceAdminLocationSubscription(sessionGeneration));
      }
      unawaited(_cancelProfilesSubscription());
      notifyListeners();
      return;
    }

    if (!loadedAccount.isActive) {
      stage = SessionStage.disabled;
      errorMessage = 'This account is unavailable.';
      unawaited(_cancelProfilesSubscription());
      notifyListeners();
      return;
    }
    if (loadedAccount.linkedStudentProfileIds.isEmpty) {
      _setError('Your account has no linked student profiles.');
      return;
    }
    final linkedFingerprint = loadedAccount.linkedStudentProfileIds.join(
      '\u0000',
    );
    if (_profilesSubscription != null &&
        _profilesLinkedFingerprint == linkedFingerprint) {
      errorMessage = null;
      notifyListeners();
      return;
    }
    unawaited(
      _replaceProfilesSubscription(
        loadedAccount.linkedStudentProfileIds,
        sessionGeneration,
      ),
    );
  }

  Future<void> _replaceAdminLocationSubscription(int sessionGeneration) async {
    final generation = ++_locationGeneration;
    final previous = _locationSubscription;
    _locationSubscription = null;
    await previous?.cancel();
    final locationId = account?.locationId.trim() ?? '';
    if (!_isCurrentSession(sessionGeneration, authUser?.uid ?? '') ||
        generation != _locationGeneration) {
      return;
    }
    if (locationId.isEmpty) {
      _setError('This administrator has no assigned academy location.');
      return;
    }
    _locationSubscription = _database
        .collection(FirestoreCollections.locations)
        .doc(locationId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_isCurrentAdminLocation(
              sessionGeneration,
              generation,
              locationId,
            )) {
              return;
            }
            final data = snapshot.data();
            selectedLocationName = _locationName(data);
            stage = adminAccessStageFor(
              account: account,
              locationActive: data?['isActive'] == true,
            );
            if (stage == SessionStage.admin) {
              errorMessage = null;
            } else {
              errorMessage = 'This academy location is unavailable.';
            }
            notifyListeners();
          },
          onError: (_) {
            if (_isCurrentAdminLocation(
              sessionGeneration,
              generation,
              locationId,
            )) {
              _setError('Unable to verify academy location.');
            }
          },
        );
  }

  Future<void> _cancelProfilesSubscription() async {
    ++_profilesGeneration;
    final previous = _profilesSubscription;
    _profilesSubscription = null;
    _profilesLinkedFingerprint = null;
    _profileRecoveryFingerprint = null;
    profiles = const [];
    selectedProfile = null;
    await previous?.cancel();
  }

  Future<void> _cancelLocationSubscription() async {
    ++_locationGeneration;
    final previous = _locationSubscription;
    _locationSubscription = null;
    selectedLocationName = null;
    await previous?.cancel();
  }

  Future<void> _replaceProfilesSubscription(
    List<String>? linkedIds,
    int sessionGeneration,
  ) async {
    final generation = ++_profilesGeneration;
    ++_locationGeneration;
    final previousProfiles = _profilesSubscription;
    final previousLocation = _locationSubscription;
    _profilesSubscription = null;
    _profilesLinkedFingerprint = null;
    _profileRecoveryFingerprint = null;
    _locationSubscription = null;
    await Future.wait<void>([
      if (previousProfiles != null) previousProfiles.cancel(),
      if (previousLocation != null) previousLocation.cancel(),
    ]);
    if (_disposed ||
        sessionGeneration != _sessionGeneration ||
        generation != _profilesGeneration ||
        linkedIds == null) {
      return;
    }
    final linkedFingerprint = linkedIds.join('\u0000');
    _profilesLinkedFingerprint = linkedFingerprint;
    _profilesSubscription = _database
        .collection(FirestoreCollections.studentProfiles)
        .where(FieldPath.documentId, whereIn: linkedIds)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (_isCurrentProfiles(
              sessionGeneration,
              generation,
              linkedFingerprint,
            )) {
              unawaited(
                _handleProfilesSnapshot(
                  snapshot,
                  sessionGeneration,
                  generation,
                  linkedFingerprint,
                ),
              );
            }
          },
          onError: (_) {
            if (_isCurrentProfiles(
              sessionGeneration,
              generation,
              linkedFingerprint,
            )) {
              _setError('Unable to load linked student profiles.');
            }
          },
        );
  }

  Future<void> _handleProfilesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int sessionGeneration,
    int profilesGeneration,
    String linkedFingerprint,
  ) async {
    try {
      final loaded = snapshot.docs
          .map(
            (document) =>
                studentProfileFromFirestoreData(document.id, document.data()),
          )
          .whereType<StudentProfile>()
          .toList(growable: false);
      final linkedIds = account!.linkedStudentProfileIds;
      final loadedIds = loaded.map((profile) => profile.id).toList()..sort();
      final recoveryFingerprint = [
        linkedFingerprint,
        ...loadedIds,
      ].join('\u0001');
      if (!snapshot.metadata.isFromCache &&
          loaded.length != linkedIds.length &&
          _profileRecoveryFingerprint == recoveryFingerprint) {
        return;
      }
      if (!snapshot.metadata.isFromCache && loaded.length != linkedIds.length) {
        _profileRecoveryFingerprint = recoveryFingerprint;
      }
      final resolution = await reconcileLinkedProfiles(
        expectedIds: linkedIds,
        snapshotProfiles: loaded,
        isFromCache: snapshot.metadata.isFromCache,
        loadMissingFromServer: _loadProfilesFromServer,
      );
      if (!_isCurrentProfiles(
        sessionGeneration,
        profilesGeneration,
        linkedFingerprint,
      )) {
        return;
      }
      if (resolution.status == LinkedProfileResolutionStatus.transitional) {
        if (!shouldHoldProfileSetupDuringCreation(
          creationInProgress: _profileCreationInProgress,
          current: stage,
        )) {
          stage = sessionStageDuringProfileReconciliation(
            current: stage,
            hasEstablishedProfiles: profiles.isNotEmpty,
          );
        }
        errorMessage = null;
        notifyListeners();
        return;
      }
      if (resolution.status == LinkedProfileResolutionStatus.missing) {
        if (shouldHoldProfileSetupDuringCreation(
          creationInProgress: _profileCreationInProgress,
          current: stage,
        )) {
          errorMessage = null;
          notifyListeners();
          return;
        }
        _setError('One or more linked student profiles could not be loaded.');
        return;
      }
      if (resolution.status == LinkedProfileResolutionStatus.unreadable) {
        if (shouldHoldProfileSetupDuringCreation(
          creationInProgress: _profileCreationInProgress,
          current: stage,
        )) {
          errorMessage = null;
          notifyListeners();
          return;
        }
        _setError('Unable to load linked student profiles.');
        return;
      }
      _profileRecoveryFingerprint = null;
      final reconciledProfiles = resolution.profiles;
      profiles = reconciledProfiles;
      final selectedId = account!.selectedStudentProfileId;
      selectedProfile = reconciledProfiles
          .where((profile) => profile.id == selectedId)
          .firstOrNull;
      if (selectedProfile == null) {
        unawaited(profileService.selectProfile(reconciledProfiles.first.id));
        selectedProfile = reconciledProfiles.first;
      }
      if (shouldHoldProfileSetupDuringCreation(
        creationInProgress: _profileCreationInProgress,
        current: stage,
      )) {
        errorMessage = null;
        notifyListeners();
        return;
      }
      unawaited(
        _evaluateSelectedProfile(sessionGeneration, profilesGeneration),
      );
    } catch (_) {
      _setError('A linked student profile is incomplete or invalid.');
    }
  }

  Future<List<StudentProfile>> _loadProfilesFromServer(
    List<String> profileIds,
  ) async {
    final snapshots = await Future.wait(
      profileIds.map(
        (id) => _database
            .collection(FirestoreCollections.studentProfiles)
            .doc(id)
            .get(const GetOptions(source: Source.server)),
      ),
    );
    return snapshots
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map(
          (snapshot) =>
              studentProfileFromFirestoreData(snapshot.id, snapshot.data()!),
        )
        .whereType<StudentProfile>()
        .toList(growable: false);
  }

  Future<void> _evaluateSelectedProfile(
    int sessionGeneration,
    int profilesGeneration,
  ) async {
    final profile = selectedProfile!;
    final loadedAccount = account!;
    final generation = ++_locationGeneration;
    final previous = _locationSubscription;
    _locationSubscription = null;
    await previous?.cancel();
    if (!_isCurrentProfiles(
          sessionGeneration,
          profilesGeneration,
          loadedAccount.linkedStudentProfileIds.join('\u0000'),
        ) ||
        generation != _locationGeneration) {
      return;
    }
    selectedLocationName = null;
    if (!profile.isActive) {
      stage = SessionStage.disabled;
      errorMessage = 'This student profile is unavailable.';
      notifyListeners();
      return;
    }
    if (profile.locationId.isEmpty ||
        profile.locationId != loadedAccount.locationId) {
      _setError('The selected profile has invalid academy access data.');
      return;
    }

    final locationId = loadedAccount.locationId;
    stage = sessionStageDuringAccessRefresh(
      current: stage,
      established: SessionStage.member,
    );
    _locationSubscription = _database
        .collection(FirestoreCollections.locations)
        .doc(locationId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_isCurrentLocation(
              sessionGeneration,
              profilesGeneration,
              generation,
              profile.id,
              locationId,
            )) {
              return;
            }
            final data = snapshot.data();
            selectedLocationName = _locationName(data);
            final locationActive = data?['isActive'] == true;
            if (hasActiveAcademyAccessFor(
              account: account,
              selectedProfile: selectedProfile,
              locationActive: locationActive,
            )) {
              stage = SessionStage.member;
              errorMessage = null;
            } else {
              stage = SessionStage.disabled;
              errorMessage = 'This academy location is unavailable.';
            }
            notifyListeners();
          },
          onError: (_) {
            if (_isCurrentLocation(
              sessionGeneration,
              profilesGeneration,
              generation,
              profile.id,
              locationId,
            )) {
              _setError('Unable to verify academy location.');
            }
          },
        );
    errorMessage = null;
    notifyListeners();
  }

  String? _locationName(Map<String, dynamic>? data) {
    final name = data?['name'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  void _setError(String message) {
    if (_disposed) return;
    ++_profilesGeneration;
    ++_locationGeneration;
    final profiles = _profilesSubscription;
    final location = _locationSubscription;
    _profilesSubscription = null;
    _profilesLinkedFingerprint = null;
    _profileRecoveryFingerprint = null;
    _locationSubscription = null;
    unawaited(
      Future.wait<void>([
        if (profiles != null) profiles.cancel(),
        if (location != null) location.cancel(),
      ]),
    );
    errorMessage = message;
    stage = SessionStage.error;
    notifyListeners();
  }

  Future<void> _cancelFirestoreSubscriptions() async {
    final user = _userSubscription;
    final profiles = _profilesSubscription;
    final location = _locationSubscription;
    _userSubscription = null;
    _profilesSubscription = null;
    _profilesLinkedFingerprint = null;
    _profileRecoveryFingerprint = null;
    _locationSubscription = null;
    selectedLocationName = null;
    await Future.wait<void>([
      if (user != null) user.cancel(),
      if (profiles != null) profiles.cancel(),
      if (location != null) location.cancel(),
    ]);
  }

  bool _isCurrentSession(int generation, String uid) =>
      listenerCallbackIsCurrent(
        disposed: _disposed,
        callbackGeneration: generation,
        currentGeneration: _sessionGeneration,
        callbackIdentity: uid,
        currentIdentity: authUser?.uid,
      );

  bool _isCurrentProfiles(
    int sessionGeneration,
    int profilesGeneration,
    String linkedFingerprint,
  ) =>
      !_disposed &&
      sessionGeneration == _sessionGeneration &&
      profilesGeneration == _profilesGeneration &&
      account?.linkedStudentProfileIds.join('\u0000') == linkedFingerprint;

  bool _isCurrentLocation(
    int sessionGeneration,
    int profilesGeneration,
    int locationGeneration,
    String profileId,
    String locationId,
  ) =>
      _isCurrentProfiles(
        sessionGeneration,
        profilesGeneration,
        account?.linkedStudentProfileIds.join('\u0000') ?? '',
      ) &&
      locationGeneration == _locationGeneration &&
      selectedProfile?.id == profileId &&
      selectedProfile?.locationId == locationId;

  bool _isCurrentAdminLocation(
    int sessionGeneration,
    int locationGeneration,
    String locationId,
  ) =>
      _isCurrentSession(sessionGeneration, authUser?.uid ?? '') &&
      locationGeneration == _locationGeneration &&
      account?.role == UserAccountRole.admin &&
      account?.locationId == locationId;

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    ++_profilesGeneration;
    ++_locationGeneration;
    final auth = _authSubscription;
    _authSubscription = null;
    unawaited(auth?.cancel());
    unawaited(_cancelFirestoreSubscriptions());
    super.dispose();
  }
}

final FirebaseSessionController firebaseSessionController =
    FirebaseSessionController();

bool listenerCallbackIsCurrent({
  required bool disposed,
  required int callbackGeneration,
  required int currentGeneration,
  required String? callbackIdentity,
  required String? currentIdentity,
}) {
  return !disposed &&
      callbackGeneration == currentGeneration &&
      callbackIdentity == currentIdentity;
}

@visibleForTesting
bool shouldRetainAccountForPendingSnapshot({
  required bool hasPendingWrites,
  required bool hasValidAccount,
  bool profileCreationInProgress = false,
}) => hasPendingWrites && (hasValidAccount || profileCreationInProgress);

@visibleForTesting
bool shouldHoldProfileSetupDuringCreation({
  required bool creationInProgress,
  required SessionStage current,
}) => creationInProgress && current == SessionStage.needsProfiles;

@visibleForTesting
SessionStage sessionStageDuringAccessRefresh({
  required SessionStage current,
  required SessionStage established,
}) {
  return current == established ? established : SessionStage.loading;
}

@visibleForTesting
SessionStage sessionStageDuringProfileReconciliation({
  required SessionStage current,
  required bool hasEstablishedProfiles,
}) {
  return current == SessionStage.member && hasEstablishedProfiles
      ? SessionStage.member
      : SessionStage.loading;
}

@visibleForTesting
bool hasActiveAcademyAccessFor({
  required UserAccount? account,
  required Student? selectedProfile,
  required bool locationActive,
}) {
  if (account == null || selectedProfile == null) return false;
  return [
        UserAccountRole.student,
        UserAccountRole.parent,
      ].contains(account.role) &&
      account.isActive &&
      selectedProfile.isActive &&
      account.locationId.isNotEmpty &&
      selectedProfile.locationId == account.locationId &&
      account.selectedStudentProfileId == selectedProfile.id &&
      account.linkedStudentProfileIds.contains(selectedProfile.id) &&
      locationActive;
}

@visibleForTesting
SessionStage adminAccessStageFor({
  required UserAccount? account,
  bool? locationActive,
}) {
  if (account == null ||
      ![
        UserAccountRole.admin,
        UserAccountRole.superAdmin,
      ].contains(account.role)) {
    return SessionStage.error;
  }
  if (!account.isActive) return SessionStage.adminDisabled;
  if (account.role == UserAccountRole.superAdmin) return SessionStage.admin;
  if (account.locationId.isEmpty) return SessionStage.error;
  if (locationActive == null) return SessionStage.loading;
  return locationActive ? SessionStage.admin : SessionStage.adminDisabled;
}
