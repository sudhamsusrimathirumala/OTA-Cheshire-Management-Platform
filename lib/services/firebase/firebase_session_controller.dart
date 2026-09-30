import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/student.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../firestore/firestore_collections.dart';
import '../location_time_service.dart';
import '../performance_diagnostics.dart';
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
  guest,
  disabled,
  adminDisabled,
  admin,
  error,
}

enum ProfileCreationPhase { savingProfiles, finishingAccountSetup }

class FirebaseSessionController extends ChangeNotifier {
  FirebaseSessionController({
    AuthenticationService? authentication,
    FirebaseFirestore? firestore,
    FirestoreProfileService? profileService,
    AuthenticationDiagnosticSink? diagnostics,
  }) : authentication = authentication ?? FirebaseAuthenticationService(),
       _firestoreOverride = firestore,
       _profileServiceOverride = profileService,
       _diagnostics = diagnostics ?? logAuthenticationDiagnostic;

  final AuthenticationService authentication;
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _database =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirestoreProfileService? _profileServiceOverride;
  final AuthenticationDiagnosticSink _diagnostics;
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
  Future<void> Function()? signOutCleanup;
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
  Set<String> _recentlyCreatedProfileIds = const {};
  bool _deferCreatedProfileRecovery = false;
  Timer? _createdProfileRecoveryTimer;
  QuerySnapshot<Map<String, dynamic>>? _latestProfilesSnapshot;
  bool _authenticatedGuestClaim = false;
  bool _disposed = false;
  bool _authStateTimingReported = false;
  bool _firstUserSnapshotPending = false;
  bool _firstProfilesSnapshotPending = false;
  bool _firstLocationSnapshotPending = false;
  PerformanceTrace? _sessionLoadTrace;
  DateTime? _lastWebResumeRequest;

  bool get hasActiveAcademyAccess => stage == SessionStage.member;
  bool get isAdministrator => stage == SessionStage.admin;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = authentication.authStateChanges().listen((user) {
      if (!_authStateTimingReported) {
        _authStateTimingReported = true;
        PerformanceDiagnostics.webStartupStage('auth_state_resolved');
      }
      unawaited(_replaceAuthUser(user));
    }, onError: (_) => _setError('Unable to observe authentication state.'));
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
    final runCleanup = shouldRunSignOutCleanup(stage);
    justCreatedProfiles = false;
    ++_sessionGeneration;
    ++_profilesGeneration;
    ++_locationGeneration;
    stage = SessionStage.loading;
    notifyListeners();
    if (runCleanup) {
      try {
        await signOutCleanup?.call();
      } catch (_) {
        // Best-effort device cleanup must not block authentication sign-out.
      }
    }
    await authentication.signOut();
    await _replaceAuthUser(null);
  }

  Future<void> completeAccountDeletion() async {
    try {
      await signOutCleanup?.call();
    } catch (_) {
      // Local push cleanup remains best effort after permanent deletion.
    }
    try {
      await authentication.signOut();
    } catch (_) {
      // The Auth user is already deleted; provider-session cleanup is best
      // effort and must not restore application access.
    }
    await _replaceAuthUser(null);
  }

  Future<void> createProfiles(
    ProfileCreationRequest request, {
    ValueChanged<ProfileCreationPhase>? onPhaseChanged,
  }) async {
    final generation = _sessionGeneration;
    final identity = authUser?.uid;
    final trace = PerformanceDiagnostics.start('profile_creation_total');
    _profileCreationInProgress = true;
    _deferCreatedProfileRecovery = true;
    _recentlyCreatedProfileIds = const {};
    var transitionStarted = false;
    onPhaseChanged?.call(ProfileCreationPhase.savingProfiles);
    try {
      final createdIds = await profileService.createProfiles(request);
      trace.stage('write_complete');
      if (!_isCurrentSession(generation, identity ?? '')) return;
      _recentlyCreatedProfileIds = createdIds.toSet();
      transitionStarted = true;
      justCreatedProfiles = true;
      _profileCreationInProgress = false;
      onPhaseChanged?.call(ProfileCreationPhase.finishingAccountSetup);
      notifyListeners();
      _scheduleCreatedProfileRecovery(generation);
      await _resumeProfileTransitionAfterWrite(generation);
      await _waitForProfileCreationTransition(generation);
      trace.stage('session_transition_complete');
    } finally {
      _profileCreationInProgress = false;
      if (!transitionStarted) _clearCreatedProfileRecovery();
    }
  }

  Future<void> _resumeProfileTransitionAfterWrite(int sessionGeneration) async {
    final snapshot = _latestProfilesSnapshot;
    if (snapshot != null &&
        sessionGeneration == _sessionGeneration &&
        _profilesLinkedFingerprint != null) {
      await _handleProfilesSnapshot(
        snapshot,
        sessionGeneration,
        _profilesGeneration,
        _profilesLinkedFingerprint!,
      );
      return;
    }
    final loadedAccount = account;
    if (loadedAccount == null || profiles.isEmpty || selectedProfile == null) {
      return;
    }
    final loadedIds = profiles.map((profile) => profile.id).toSet();
    if (!loadedIds.containsAll(loadedAccount.linkedStudentProfileIds)) return;
    await _evaluateSelectedProfile(sessionGeneration, _profilesGeneration);
  }

  Future<void> _waitForProfileCreationTransition(int sessionGeneration) async {
    if (_profileCreationTransitionFinished(sessionGeneration)) return;
    final completer = Completer<void>();
    void handleChange() {
      if (!completer.isCompleted &&
          _profileCreationTransitionFinished(sessionGeneration)) {
        completer.complete();
      }
    }

    addListener(handleChange);
    try {
      handleChange();
      await completer.future;
    } finally {
      removeListener(handleChange);
    }
  }

  bool _profileCreationTransitionFinished(int generation) =>
      generation != _sessionGeneration ||
      authUser == null ||
      stage == SessionStage.member ||
      stage == SessionStage.disabled ||
      stage == SessionStage.error ||
      stage == SessionStage.signedOut;

  void _scheduleCreatedProfileRecovery(int sessionGeneration) {
    _createdProfileRecoveryTimer?.cancel();
    _createdProfileRecoveryTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed || sessionGeneration != _sessionGeneration) return;
      _deferCreatedProfileRecovery = false;
      final snapshot = _latestProfilesSnapshot;
      final fingerprint = _profilesLinkedFingerprint;
      if (snapshot != null && fingerprint != null) {
        unawaited(
          _handleProfilesSnapshot(
            snapshot,
            sessionGeneration,
            _profilesGeneration,
            fingerprint,
          ),
        );
      }
    });
  }

  Future<void> handleAppResumed({
    bool? isWeb,
    Future<void> Function()? enableNetwork,
    DateTime? now,
  }) async {
    final web = isWeb ?? kIsWeb;
    final current = now ?? DateTime.now();
    if (!shouldRequestWebFirestoreResume(
      isWeb: web,
      hasAuthenticatedUser: authUser != null,
      lastRequest: _lastWebResumeRequest,
      now: current,
    )) {
      return;
    }
    _lastWebResumeRequest = current;
    final trace = PerformanceDiagnostics.start('web_resume');
    try {
      await (enableNetwork?.call() ?? _database.enableNetwork());
      trace.stage('firestore_network_enabled');
    } catch (_) {
      trace.stage('firestore_network_enable_failed');
    }
  }

  void dismissCreatedConfirmation() {
    justCreatedProfiles = false;
    notifyListeners();
  }

  Future<void> selectProfile(String profileId) async {
    await profileService.selectProfile(profileId);
  }

  Future<SessionStage> adoptAuthenticatedUserAfterSignup({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final user = authentication.currentUser;
    if (user == null) {
      throw StateError('No authenticated user is available for onboarding.');
    }
    if (authUser?.uid != user.uid || stage == SessionStage.signedOut) {
      await _replaceAuthUser(user);
    }
    if (stage != SessionStage.loading) return stage;

    final completer = Completer<SessionStage>();
    void handleStageChanged() {
      if (!completer.isCompleted && stage != SessionStage.loading) {
        completer.complete(stage);
      }
    }

    addListener(handleStageChanged);
    handleStageChanged();
    try {
      return await completer.future.timeout(timeout);
    } finally {
      removeListener(handleStageChanged);
    }
  }

  Future<void> _replaceAuthUser(User? user) async {
    final generation = ++_sessionGeneration;
    _sessionLoadTrace = user == null
        ? null
        : PerformanceDiagnostics.start('session_load');
    _sessionLoadTrace?.stage('authenticated_user_available');
    _firstUserSnapshotPending = user != null;
    _firstProfilesSnapshotPending = false;
    _firstLocationSnapshotPending = false;
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
      _authenticatedGuestClaim = false;
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }
    stage = SessionStage.loading;
    notifyListeners();
    try {
      final claims = await authentication.authenticationClaims
          ?.currentUserClaims();
      _authenticatedGuestClaim = claims?['otaGuest'] == true;
      _sessionLoadTrace?.stage('claims_fetch_complete');
    } catch (_) {
      _setError('Unable to verify this account authorization.');
      return;
    }
    if (!_isCurrentSession(generation, user.uid)) return;
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
    if (_firstUserSnapshotPending) {
      _firstUserSnapshotPending = false;
      _sessionLoadTrace?.stage(
        snapshot.metadata.isFromCache
            ? 'user_snapshot_first_cache'
            : 'user_snapshot_first_server',
      );
    }
    final data = snapshot.data();
    if (data == null) {
      _diagnostics(const AuthenticationDiagnostic('USER_DOC_MISSING'));
      if (_authenticatedGuestClaim) {
        _setError('This reviewer account is not configured correctly.');
        return;
      }
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
      _reportSessionLoaded(stage);
      notifyListeners();
      return;
    }
    _diagnostics(const AuthenticationDiagnostic('USER_DOC_FOUND'));
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
    final guestIdentity = guestIdentityStatusFor(
      account: loadedAccount,
      hasGuestClaim: _authenticatedGuestClaim,
    );
    if (guestIdentity == GuestIdentityStatus.mismatch) {
      _setError('This account authorization is inconsistent.');
      return;
    }
    if (guestIdentity == GuestIdentityStatus.guest) {
      stage = loadedAccount.isActive
          ? SessionStage.guest
          : SessionStage.disabled;
      errorMessage = loadedAccount.isActive
          ? null
          : 'This reviewer account is unavailable.';
      _reportSessionLoaded(stage);
      unawaited(_cancelProfilesSubscription());
      unawaited(_cancelLocationSubscription());
      notifyListeners();
      return;
    }
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
      if (stage != SessionStage.loading) _reportSessionLoaded(stage);
      unawaited(_cancelProfilesSubscription());
      notifyListeners();
      return;
    }

    if (!loadedAccount.isActive) {
      stage = SessionStage.disabled;
      errorMessage = 'This account is unavailable.';
      _reportSessionLoaded(stage);
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
      final cachedSelectedProfile = selectedProfileFromCachedProfiles(
        account: loadedAccount,
        profiles: profiles,
      );
      if (cachedSelectedProfile != null) {
        selectedProfile = cachedSelectedProfile;
      }
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
    _firstLocationSnapshotPending = true;
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
            if (_firstLocationSnapshotPending) {
              _firstLocationSnapshotPending = false;
              _sessionLoadTrace?.stage(
                snapshot.metadata.isFromCache
                    ? 'location_first_cache'
                    : 'location_first_server',
              );
            }
            const LocationTimeService().cacheLocationSnapshot(locationId, data);
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
            _reportSessionLoaded(stage);
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
    _latestProfilesSnapshot = null;
    _clearCreatedProfileRecovery();
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
    _latestProfilesSnapshot = null;
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
    _firstProfilesSnapshotPending = true;
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
      _latestProfilesSnapshot = snapshot;
      if (_firstProfilesSnapshotPending) {
        _firstProfilesSnapshotPending = false;
        _sessionLoadTrace?.stage(
          snapshot.metadata.isFromCache
              ? 'linked_profiles_first_cache'
              : 'linked_profiles_first_server',
        );
      }
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
      final missingIds = linkedIds
          .where((id) => !loadedIds.contains(id))
          .toList(growable: false);
      final deferCreatedRecovery = shouldDeferCreatedProfileServerRecovery(
        creationWritePending: _profileCreationInProgress,
        deferAfterWrite: _deferCreatedProfileRecovery,
        recentlyCreatedIds: _recentlyCreatedProfileIds,
        missingIds: missingIds,
      );
      if (!deferCreatedRecovery &&
          !snapshot.metadata.isFromCache &&
          loaded.length != linkedIds.length &&
          _profileRecoveryFingerprint == recoveryFingerprint) {
        return;
      }
      if (!deferCreatedRecovery &&
          !snapshot.metadata.isFromCache &&
          loaded.length != linkedIds.length) {
        _profileRecoveryFingerprint = recoveryFingerprint;
      }
      final reconciliationTrace = PerformanceDiagnostics.start(
        'linked_profile_reconciliation',
      );
      final resolution = await reconcileLinkedProfiles(
        expectedIds: linkedIds,
        snapshotProfiles: loaded,
        isFromCache: snapshot.metadata.isFromCache,
        deferServerRecovery: deferCreatedRecovery,
        loadMissingFromServer: _loadProfilesFromServer,
      );
      reconciliationTrace.stage('complete_${resolution.status.name}');
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
      _clearCreatedProfileRecovery();
      final reconciledProfiles = resolution.profiles;
      profiles = reconciledProfiles;
      final selectedId = account!.selectedStudentProfileId;
      selectedProfile = reconciledProfiles
          .where((profile) => profile.id == selectedId)
          .firstOrNull;
      if (selectedProfile == null) {
        final selectionTrace = PerformanceDiagnostics.start(
          'selected_profile_write',
        );
        unawaited(
          profileService
              .selectProfile(reconciledProfiles.first.id)
              .whenComplete(() => selectionTrace.stage('complete')),
        );
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
    final trace = PerformanceDiagnostics.start(
      'linked_profile_server_recovery',
    );
    final snapshots = await Future.wait(
      profileIds.map(
        (id) => _database
            .collection(FirestoreCollections.studentProfiles)
            .doc(id)
            .get(const GetOptions(source: Source.server)),
      ),
    );
    final loaded = snapshots
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map(
          (snapshot) =>
              studentProfileFromFirestoreData(snapshot.id, snapshot.data()!),
        )
        .whereType<StudentProfile>()
        .toList(growable: false);
    trace.stage('complete');
    return loaded;
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
    _firstLocationSnapshotPending = true;
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
              locationId,
            )) {
              return;
            }
            final data = snapshot.data();
            if (_firstLocationSnapshotPending) {
              _firstLocationSnapshotPending = false;
              _sessionLoadTrace?.stage(
                snapshot.metadata.isFromCache
                    ? 'location_first_cache'
                    : 'location_first_server',
              );
            }
            const LocationTimeService().cacheLocationSnapshot(locationId, data);
            selectedLocationName = _locationName(data);
            final locationActive = data?['isActive'] == true;
            if (hasActiveAcademyAccessFor(
              account: account,
              selectedProfile: selectedProfile,
              locationActive: locationActive,
            )) {
              stage = SessionStage.member;
              errorMessage = null;
              _reportSessionLoaded(stage);
              _sessionLoadTrace?.stage('member_ready');
            } else {
              stage = SessionStage.disabled;
              errorMessage = 'This academy location is unavailable.';
              _reportSessionLoaded(stage);
            }
            notifyListeners();
          },
          onError: (_) {
            if (_isCurrentLocation(
              sessionGeneration,
              profilesGeneration,
              generation,
              locationId,
            )) {
              _setError('Unable to verify academy location.');
            }
          },
        );
    errorMessage = null;
    notifyListeners();
  }

  void _clearCreatedProfileRecovery() {
    _createdProfileRecoveryTimer?.cancel();
    _createdProfileRecoveryTimer = null;
    _deferCreatedProfileRecovery = false;
    _recentlyCreatedProfileIds = const {};
  }

  String? _locationName(Map<String, dynamic>? data) {
    final name = data?['name'];
    return name is String && name.trim().isNotEmpty ? name.trim() : null;
  }

  void _setError(String message) {
    if (_disposed) return;
    _diagnostics(const AuthenticationDiagnostic('SESSION_LOAD_FAILED'));
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

  void _reportSessionLoaded(SessionStage loadedStage) {
    _diagnostics(
      AuthenticationDiagnostic(
        'SESSION_LOAD_SUCCEEDED',
        code: loadedStage.name,
      ),
    );
    if (loadedStage == SessionStage.member ||
        loadedStage == SessionStage.admin ||
        loadedStage == SessionStage.guest) {
      PerformanceDiagnostics.webStartupStage('session_ready');
    }
  }

  Future<void> _cancelFirestoreSubscriptions() async {
    final user = _userSubscription;
    final profiles = _profilesSubscription;
    final location = _locationSubscription;
    _userSubscription = null;
    _profilesSubscription = null;
    _profilesLinkedFingerprint = null;
    _profileRecoveryFingerprint = null;
    _latestProfilesSnapshot = null;
    _clearCreatedProfileRecovery();
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
    String locationId,
  ) =>
      _isCurrentProfiles(
        sessionGeneration,
        profilesGeneration,
        account?.linkedStudentProfileIds.join('\u0000') ?? '',
      ) &&
      locationGeneration == _locationGeneration &&
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
    _createdProfileRecoveryTimer?.cancel();
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
bool shouldDeferCreatedProfileServerRecovery({
  required bool creationWritePending,
  required bool deferAfterWrite,
  required Set<String> recentlyCreatedIds,
  required List<String> missingIds,
}) {
  if (missingIds.isEmpty) return false;
  if (creationWritePending) return true;
  return deferAfterWrite &&
      recentlyCreatedIds.isNotEmpty &&
      missingIds.every(recentlyCreatedIds.contains);
}

@visibleForTesting
bool shouldRequestWebFirestoreResume({
  required bool isWeb,
  required bool hasAuthenticatedUser,
  required DateTime? lastRequest,
  required DateTime now,
  Duration minimumInterval = const Duration(seconds: 3),
}) {
  if (!isWeb || !hasAuthenticatedUser) return false;
  return lastRequest == null || now.difference(lastRequest) >= minimumInterval;
}

@visibleForTesting
bool shouldRunSignOutCleanup(SessionStage stage) => stage != SessionStage.guest;

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

enum GuestIdentityStatus { notGuest, guest, mismatch }

@visibleForTesting
GuestIdentityStatus guestIdentityStatusFor({
  required UserAccount account,
  required bool hasGuestClaim,
}) {
  final hasGuestRole = account.role == UserAccountRole.guest;
  if (hasGuestRole != hasGuestClaim) return GuestIdentityStatus.mismatch;
  return hasGuestRole
      ? GuestIdentityStatus.guest
      : GuestIdentityStatus.notGuest;
}

@visibleForTesting
StudentProfile? selectedProfileFromCachedProfiles({
  required UserAccount account,
  required List<StudentProfile> profiles,
}) {
  final selectedId = account.selectedStudentProfileId;
  return profiles.where((profile) => profile.id == selectedId).firstOrNull;
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
