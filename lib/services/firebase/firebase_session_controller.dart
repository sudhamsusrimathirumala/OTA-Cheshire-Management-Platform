import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../models/student_profile.dart';
import '../../models/student.dart';
import '../../models/user_account.dart';
import 'firebase_authentication_service.dart';
import 'firebase_app_data_service.dart';
import 'firebase_identity_contract.dart';
import 'profile_membership_service.dart';
import '../firestore/firestore_collections.dart';

enum SessionStage {
  loading,
  signedOut,
  unverified,
  needsProfiles,
  incomplete,
  pending,
  approved,
  rejected,
  disabled,
  admin,
  error,
}

class FirebaseSessionController extends ChangeNotifier {
  FirebaseSessionController({
    AuthenticationService? authentication,
    FirebaseFirestore? firestore,
    FirestoreProfileMembershipService? membership,
  }) : authentication = authentication ?? FirebaseAuthenticationService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       membership = membership ?? FirestoreProfileMembershipService();

  final AuthenticationService authentication;
  final FirebaseFirestore _firestore;
  final FirestoreProfileMembershipService membership;

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

  bool get isApprovedMember => stage == SessionStage.approved;
  bool get isAdministrator => stage == SessionStage.admin;

  void start() {
    if (_started) return;
    _started = true;
    _authSubscription = authentication.authStateChanges().listen(
      _handleAuthUser,
      onError: (_) => _setError('Unable to observe authentication state.'),
    );
  }

  Future<void> retry() async {
    final user = authentication.currentUser;
    if (user == null) {
      _handleAuthUser(null);
      return;
    }
    stage = SessionStage.loading;
    errorMessage = null;
    notifyListeners();
    await authentication.refreshUser();
    _handleAuthUser(authentication.currentUser);
  }

  Future<void> signOut() async {
    justCreatedProfiles = false;
    await authentication.signOut();
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
    await membership.selectProfile(profileId);
  }

  void _handleAuthUser(User? user) {
    authUser = user;
    unawaited(_cancelFirestoreSubscriptions());
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
    final hasVerifiedGoogle =
        user.emailVerified &&
        user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );
    if (!user.emailVerified && !hasVerifiedGoogle) {
      stage = SessionStage.unverified;
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
          _handleUserSnapshot,
          onError: (_) => _setError('Unable to load your OTA account.'),
        );
  }

  void _handleUserSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      account = null;
      profiles = const [];
      selectedProfile = null;
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
    if (account!.role == UserAccountRole.admin ||
        account!.role == UserAccountRole.superAdmin) {
      if (account!.approvalStatus == UserAccountApprovalStatus.approved) {
        stage = SessionStage.admin;
        errorMessage = null;
      } else {
        stage = SessionStage.disabled;
      }
      notifyListeners();
      return;
    }
    final linkedIds = account!.linkedStudentProfileIds;
    if (linkedIds.isEmpty) {
      _setError('Your account has no linked student profiles.');
      return;
    }
    unawaited(_profilesSubscription?.cancel());
    _profilesSubscription = _firestore
        .collection(FirestoreCollections.studentProfiles)
        .where(FieldPath.documentId, whereIn: linkedIds)
        .snapshots()
        .listen(
          _handleProfilesSnapshot,
          onError: (_) => _setError('Unable to load linked student profiles.'),
        );
  }

  void _handleProfilesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
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
        unawaited(membership.selectProfile(loaded.first.id));
        selectedProfile = loaded.first;
      }
      _evaluateSelectedProfile();
    } catch (_) {
      _setError('A linked student profile is incomplete or invalid.');
    }
  }

  void _evaluateSelectedProfile() {
    final profile = selectedProfile!;
    unawaited(_locationSubscription?.cancel());
    selectedLocationName = null;
    final locationId = profile.locationId.trim();
    switch (profile.approvalStatus) {
      case StudentApprovalStatus.incomplete:
        stage = SessionStage.incomplete;
      case StudentApprovalStatus.pending:
        stage = SessionStage.pending;
      case StudentApprovalStatus.rejected:
        stage = SessionStage.rejected;
      case StudentApprovalStatus.disabled:
        stage = SessionStage.disabled;
      case StudentApprovalStatus.approved:
        if (locationId.isEmpty) {
          _setError('Approved profile has no academy location.');
          return;
        }
        stage = SessionStage.loading;
    }
    if (locationId.isNotEmpty) {
      _locationSubscription = _firestore
          .collection(FirestoreCollections.locations)
          .doc(locationId)
          .snapshots()
          .listen((snapshot) {
            final data = snapshot.data();
            final name = data?['name'];
            selectedLocationName = name is String && name.trim().isNotEmpty
                ? name.trim()
                : null;
            if (profile.approvalStatus == StudentApprovalStatus.approved) {
              if (data?['isActive'] == true) {
                stage = SessionStage.approved;
                errorMessage = null;
              } else {
                stage = SessionStage.disabled;
                errorMessage = 'This academy location is unavailable.';
              }
            }
            notifyListeners();
          }, onError: (_) => _setError('Unable to verify academy location.'));
    }
    errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    errorMessage = message;
    stage = SessionStage.error;
    notifyListeners();
  }

  Future<void> _cancelFirestoreSubscriptions() async {
    await _userSubscription?.cancel();
    await _profilesSubscription?.cancel();
    await _locationSubscription?.cancel();
    _userSubscription = null;
    _profilesSubscription = null;
    _locationSubscription = null;
    selectedLocationName = null;
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_cancelFirestoreSubscriptions());
    super.dispose();
  }
}

final FirebaseSessionController firebaseSessionController =
    FirebaseSessionController();
