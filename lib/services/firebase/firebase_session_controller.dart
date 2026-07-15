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
       _firestore = firestore ?? FirebaseFirestore.instance,
       profileService = profileService ?? FirestoreProfileService();

  final AuthenticationService authentication;
  final FirebaseFirestore _firestore;
  final FirestoreProfileService profileService;

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

  void markProfilesCreated() {
    justCreatedProfiles = true;
    notifyListeners();
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
    _userSubscription = _firestore
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
      _setError('Your account record is incomplete or invalid.');
      return;
    }

    final loadedAccount = account!;
    if (loadedAccount.role == UserAccountRole.admin ||
        loadedAccount.role == UserAccountRole.superAdmin) {
      stage = adminAccessStageFor(account: loadedAccount);
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
    _locationSubscription = _firestore
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
    _profilesSubscription = _firestore
        .collection(FirestoreCollections.studentProfiles)
        .where(FieldPath.documentId, whereIn: linkedIds)
        .snapshots()
        .listen(
          (snapshot) {
            if (_isCurrentProfiles(
              sessionGeneration,
              generation,
              linkedFingerprint,
            )) {
              _handleProfilesSnapshot(snapshot, sessionGeneration, generation);
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

  void _handleProfilesSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int sessionGeneration,
    int profilesGeneration,
  ) {
    try {
      final loaded = snapshot.docs
          .map(
            (document) =>
                studentProfileFromFirestoreData(document.id, document.data()),
          )
          .whereType<StudentProfile>()
          .toList();
      final linkedIds = account!.linkedStudentProfileIds;
      loaded.sort(
        (a, b) => linkedIds.indexOf(a.id).compareTo(linkedIds.indexOf(b.id)),
      );
      if (loaded.length != linkedIds.length) {
        _setError('One or more linked student profiles could not be loaded.');
        return;
      }
      profiles = List.unmodifiable(loaded);
      final selectedId = account!.selectedStudentProfileId;
      selectedProfile = loaded
          .where((profile) => profile.id == selectedId)
          .firstOrNull;
      if (selectedProfile == null) {
        unawaited(profileService.selectProfile(loaded.first.id));
        selectedProfile = loaded.first;
      }
      unawaited(
        _evaluateSelectedProfile(sessionGeneration, profilesGeneration),
      );
    } catch (_) {
      _setError('A linked student profile is incomplete or invalid.');
    }
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
    stage = SessionStage.loading;
    _locationSubscription = _firestore
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
