import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../models/academy_announcement.dart';
import '../../models/academy_event.dart';
import '../../models/academy_resource.dart';
import '../../models/class_session.dart';
import '../../models/curriculum_requirement.dart';
import '../../models/notification_item.dart';
import '../../models/student.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../debug_view_controller.dart';
import 'firebase_identity_contract.dart';
import 'firebase_session_controller.dart';
import 'admin_location_controller.dart';
import '../app_data_service.dart';
import '../firestore/firestore_collections.dart';
import '../location_time_service.dart';
import '../mock_app_data_service.dart';

const _debugAdminAccount = UserAccount(
  id: 'debug-admin',
  firstName: 'Development',
  lastName: 'Admin',
  email: 'debug-admin@example.invalid',
  role: UserAccountRole.admin,
  approvalStatus: UserAccountApprovalStatus.approved,
  linkedStudentProfileIds: [],
  locationId: LocationTimeService.otaCheshireLocationId,
);

class FirebaseAppDataService extends ChangeNotifier implements AppDataService {
  FirebaseAppDataService({
    required this._adminLocations,
    FirebaseFirestore? firestore,
    AppDataService? fallbackService,
  }) : _fallbackService = fallbackService ?? const MockAppDataService() {
    _firestore = firestore;
    firebaseSessionController.addListener(_handleSessionChanged);
    _adminLocations.addListener(_handleAdminLocationsChanged);
    _handleSessionChanged();
  }

  FirebaseFirestore? _firestore;
  final AppDataService _fallbackService;
  final AdminLocationController _adminLocations;
  Map<int, List<ClassSession>> _schedule = const <int, List<ClassSession>>{};
  List<NotificationItem> _notifications = const <NotificationItem>[];
  List<AcademyAnnouncement> _adminAnnouncements = const <AcademyAnnouncement>[];
  List<AcademyEvent> _events = const <AcademyEvent>[];
  List<AcademyResource> _resources = const <AcademyResource>[];
  List<StudentProfile> _adminStudentProfiles = const <StudentProfile>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _scheduleSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _announcementsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _resourcesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminStudentsSubscription;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _superAdminContentSubscriptions = [];
  final Map<String, Map<int, List<ClassSession>>> _superAdminSchedules = {};
  final Map<String, List<AcademyAnnouncement>> _superAdminAnnouncements = {};
  final Map<String, List<AcademyEvent>> _superAdminEvents = {};
  final Map<String, List<AcademyResource>> _superAdminResources = {};
  int _superAdminContentGeneration = 0;
  String _activeLocationsFingerprint = '';
  bool _superAdminContentInitialized = false;
  QuerySnapshot<Map<String, dynamic>>? _latestAnnouncementsSnapshot;
  bool _isScheduleLoading = true;
  String? _scheduleErrorMessage;
  bool _isAnnouncementsLoading = true;
  String? _announcementsErrorMessage;
  bool _isEventsLoading = true;
  String? _eventsErrorMessage;
  bool _isResourcesLoading = true;
  String? _resourcesErrorMessage;
  bool _isAdminStudentsLoading = true;
  String? _adminStudentsErrorMessage;
  bool _isUsingFallbackData = false;
  DebugViewMode _developmentViewMode = DebugViewMode.none;
  String? _listeningLocationId;
  bool _listeningAsSuperAdmin = false;

  bool get _developmentViewActive =>
      kDebugMode && _developmentViewMode != DebugViewMode.none;

  void setDevelopmentViewMode(DebugViewMode mode) {
    final effective = kDebugMode ? mode : DebugViewMode.none;
    if (_developmentViewMode == effective) return;
    _developmentViewMode = effective;
    if (_developmentViewActive) {
      _useFallbackDataForUnavailableFirebase();
    } else if (firebaseSessionController.stage != SessionStage.approved &&
        firebaseSessionController.stage != SessionStage.admin) {
      _clearData();
    }
    notifyListeners();
  }

  void _handleSessionChanged() {
    final session = firebaseSessionController;
    final account = session.account;
    final profile = session.selectedProfile;
    final superAdmin =
        session.stage == SessionStage.admin &&
        account?.role == UserAccountRole.superAdmin;
    final locationId = session.stage == SessionStage.admin
        ? account?.locationId
        : session.stage == SessionStage.approved
        ? profile?.locationId
        : null;
    if (!superAdmin && (locationId == null || locationId.isEmpty)) {
      _stopFirestoreListeners();
      if (_developmentViewActive) {
        _useFallbackDataForUnavailableFirebase();
        notifyListeners();
      }
      return;
    }
    if (_listeningLocationId == locationId &&
        _listeningAsSuperAdmin == superAdmin) {
      return;
    }
    _stopFirestoreListeners();
    _listeningLocationId = locationId;
    _listeningAsSuperAdmin = superAdmin;
    _listenToFirestore(locationId: locationId, superAdmin: superAdmin);
  }

  void _listenToFirestore({String? locationId, required bool superAdmin}) {
    try {
      if (_firestore == null && Firebase.apps.isEmpty) {
        _useFallbackDataForUnavailableFirebase();
        return;
      }

      final firestore = _firestore ?? FirebaseFirestore.instance;
      _firestore = firestore;
      if (locationId != null && locationId.isNotEmpty) {
        unawaited(
          const LocationTimeService().loadLocation(firestore, locationId),
        );
      }
      if (superAdmin) {
        _listenToSuperAdminContent(firestore);
      } else {
        _listenToSchedule(firestore, locationId, false);
        _listenToAnnouncements(firestore, locationId, false);
        _listenToEvents(firestore, locationId, false);
        _listenToResources(firestore, locationId, false);
      }
      if (firebaseSessionController.stage == SessionStage.admin) {
        _listenToAdminStudents(firestore, locationId, superAdmin);
      }
    } catch (_) {
      _useFallbackDataForUnavailableFirebase();
    }
  }

  void _stopFirestoreListeners() {
    unawaited(_scheduleSubscription?.cancel());
    unawaited(_announcementsSubscription?.cancel());
    unawaited(_eventsSubscription?.cancel());
    unawaited(_resourcesSubscription?.cancel());
    unawaited(_adminStudentsSubscription?.cancel());
    _cancelSuperAdminContentListeners();
    _scheduleSubscription = null;
    _announcementsSubscription = null;
    _eventsSubscription = null;
    _resourcesSubscription = null;
    _adminStudentsSubscription = null;
    _listeningLocationId = null;
    _listeningAsSuperAdmin = false;
    _clearData();
    notifyListeners();
  }

  void _clearData() {
    _schedule = const <int, List<ClassSession>>{};
    _notifications = const <NotificationItem>[];
    _adminAnnouncements = const <AcademyAnnouncement>[];
    _events = const <AcademyEvent>[];
    _resources = const <AcademyResource>[];
    _adminStudentProfiles = const <StudentProfile>[];
    _superAdminSchedules.clear();
    _superAdminAnnouncements.clear();
    _superAdminEvents.clear();
    _superAdminResources.clear();
    _activeLocationsFingerprint = '';
    _superAdminContentInitialized = false;
    _isUsingFallbackData = false;
    _isScheduleLoading = true;
    _isAnnouncementsLoading = true;
    _isEventsLoading = true;
    _isResourcesLoading = true;
    _isAdminStudentsLoading = true;
    _scheduleErrorMessage = null;
    _announcementsErrorMessage = null;
    _eventsErrorMessage = null;
    _resourcesErrorMessage = null;
    _adminStudentsErrorMessage = null;
  }

  void _useFallbackDataForUnavailableFirebase() {
    if (!_developmentViewActive) {
      _clearData();
      _isScheduleLoading = false;
      _isAnnouncementsLoading = false;
      _isEventsLoading = false;
      _isResourcesLoading = false;
      _isAdminStudentsLoading = false;
      _scheduleErrorMessage = 'Firebase data is unavailable.';
      _announcementsErrorMessage = 'Firebase data is unavailable.';
      _eventsErrorMessage = 'Firebase data is unavailable.';
      _resourcesErrorMessage = 'Firebase data is unavailable.';
      _adminStudentsErrorMessage = 'Firebase data is unavailable.';
      return;
    }
    _schedule = _fallbackService.schedule;
    _notifications = _fallbackService.notifications;
    _adminAnnouncements = _fallbackService.adminAnnouncements;
    _events = _fallbackService.events;
    _resources = _fallbackService.resources;
    _adminStudentProfiles = _fallbackService.adminStudentProfiles;
    _isUsingFallbackData = true;
    _isScheduleLoading = false;
    _isAnnouncementsLoading = false;
    _isEventsLoading = false;
    _isResourcesLoading = false;
    _isAdminStudentsLoading = false;
    _scheduleErrorMessage = null;
    _announcementsErrorMessage = null;
    _eventsErrorMessage = null;
    _resourcesErrorMessage = null;
    _adminStudentsErrorMessage = null;
  }

  void _listenToSchedule(
    FirebaseFirestore firestore,
    String? locationId,
    bool superAdmin,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      FirestoreCollections.classSessions,
    );
    if (!superAdmin) query = query.where('locationId', isEqualTo: locationId);
    _scheduleSubscription = query
        .orderBy('weekday')
        .orderBy('startMinutes')
        .snapshots()
        .listen(_handleScheduleSnapshot, onError: _handleScheduleError);
  }

  void _listenToAnnouncements(
    FirebaseFirestore firestore,
    String? locationId,
    bool superAdmin,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      FirestoreCollections.announcements,
    );
    if (!superAdmin) query = query.where('locationId', isEqualTo: locationId);
    _announcementsSubscription = query.snapshots().listen(
      _handleAnnouncementsSnapshot,
      onError: _handleAnnouncementsError,
    );
  }

  void _listenToEvents(
    FirebaseFirestore firestore,
    String? locationId,
    bool superAdmin,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      FirestoreCollections.events,
    );
    if (!superAdmin) query = query.where('locationId', isEqualTo: locationId);
    _eventsSubscription = query.snapshots().listen(
      _handleEventsSnapshot,
      onError: _handleEventsError,
    );
  }

  void _listenToResources(
    FirebaseFirestore firestore,
    String? locationId,
    bool superAdmin,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      FirestoreCollections.resources,
    );
    if (!superAdmin) query = query.where('locationId', isEqualTo: locationId);
    _resourcesSubscription = query.snapshots().listen(
      _handleResourcesSnapshot,
      onError: _handleResourcesError,
    );
  }

  void _listenToAdminStudents(
    FirebaseFirestore firestore,
    String? locationId,
    bool superAdmin,
  ) {
    Query<Map<String, dynamic>> query = firestore.collection(
      FirestoreCollections.studentProfiles,
    );
    if (!superAdmin) query = query.where('locationId', isEqualTo: locationId);
    _adminStudentsSubscription = query.snapshots().listen(
      _handleAdminStudentsSnapshot,
      onError: _handleAdminStudentsError,
    );
  }

  void _handleAdminLocationsChanged() {
    if (!_listeningAsSuperAdmin) return;
    final firestore = _firestore;
    if (firestore != null) _listenToSuperAdminContent(firestore);
  }

  void _listenToSuperAdminContent(FirebaseFirestore firestore) {
    final locationIds = _adminLocations.activeLocationIds.toList()..sort();
    final fingerprint = locationIds.join('\u0000');
    if (_activeLocationsFingerprint == fingerprint &&
        _superAdminContentInitialized) {
      return;
    }
    _activeLocationsFingerprint = fingerprint;
    _superAdminContentInitialized = true;
    _cancelSuperAdminContentListeners();
    final generation = _superAdminContentGeneration;
    _superAdminSchedules.clear();
    _superAdminAnnouncements.clear();
    _superAdminEvents.clear();
    _superAdminResources.clear();
    _schedule = const {};
    _adminAnnouncements = const [];
    _events = const [];
    _resources = const [];
    _isScheduleLoading = locationIds.isNotEmpty;
    _isAnnouncementsLoading = locationIds.isNotEmpty;
    _isEventsLoading = locationIds.isNotEmpty;
    _isResourcesLoading = locationIds.isNotEmpty;
    _scheduleErrorMessage = null;
    _announcementsErrorMessage = null;
    _eventsErrorMessage = null;
    _resourcesErrorMessage = null;

    for (final locationId in locationIds) {
      unawaited(
        const LocationTimeService().loadLocation(firestore, locationId),
      );
      _superAdminContentSubscriptions.add(
        firestore
            .collection(FirestoreCollections.classSessions)
            .where('locationId', isEqualTo: locationId)
            .orderBy('weekday')
            .orderBy('startMinutes')
            .snapshots()
            .listen(
              (snapshot) => _handleSuperAdminScheduleSnapshot(
                locationId,
                snapshot,
                generation,
              ),
              onError: (_) => _handleSuperAdminContentError(
                locationId,
                generation,
                _SuperAdminContent.schedule,
              ),
            ),
      );
      _superAdminContentSubscriptions.add(
        firestore
            .collection(FirestoreCollections.announcements)
            .where('locationId', isEqualTo: locationId)
            .snapshots()
            .listen(
              (snapshot) => _handleSuperAdminAnnouncementsSnapshot(
                locationId,
                snapshot,
                generation,
              ),
              onError: (_) => _handleSuperAdminContentError(
                locationId,
                generation,
                _SuperAdminContent.announcements,
              ),
            ),
      );
      _superAdminContentSubscriptions.add(
        firestore
            .collection(FirestoreCollections.events)
            .where('locationId', isEqualTo: locationId)
            .snapshots()
            .listen(
              (snapshot) => _handleSuperAdminEventsSnapshot(
                locationId,
                snapshot,
                generation,
              ),
              onError: (_) => _handleSuperAdminContentError(
                locationId,
                generation,
                _SuperAdminContent.events,
              ),
            ),
      );
      _superAdminContentSubscriptions.add(
        firestore
            .collection(FirestoreCollections.resources)
            .where('locationId', isEqualTo: locationId)
            .snapshots()
            .listen(
              (snapshot) => _handleSuperAdminResourcesSnapshot(
                locationId,
                snapshot,
                generation,
              ),
              onError: (_) => _handleSuperAdminContentError(
                locationId,
                generation,
                _SuperAdminContent.resources,
              ),
            ),
      );
    }
    notifyListeners();
  }

  void _handleSuperAdminScheduleSnapshot(
    String locationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (generation != _superAdminContentGeneration) return;
    _superAdminSchedules[locationId] = _scheduleFromSnapshot(snapshot);
    final merged = <int, List<ClassSession>>{};
    for (final schedule in _superAdminSchedules.values) {
      for (final entry in schedule.entries) {
        merged.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }
    _schedule = {
      for (final entry in merged.entries)
        entry.key: List.unmodifiable(
          entry.value..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)),
        ),
    };
    _isScheduleLoading = false;
    _scheduleErrorMessage = null;
    notifyListeners();
  }

  void _handleSuperAdminAnnouncementsSnapshot(
    String locationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (generation != _superAdminContentGeneration) return;
    _superAdminAnnouncements[locationId] = _adminAnnouncementsFromSnapshot(
      snapshot,
    );
    _adminAnnouncements = mergeActiveLocationRecords(
      _superAdminAnnouncements,
      _adminLocations.activeLocationIds,
      idOf: (item) => item.id,
    )..sort((a, b) => b.displayDate.compareTo(a.displayDate));
    _isAnnouncementsLoading = false;
    _announcementsErrorMessage = null;
    notifyListeners();
  }

  void _handleSuperAdminEventsSnapshot(
    String locationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (generation != _superAdminContentGeneration) return;
    _superAdminEvents[locationId] = _eventsFromSnapshot(snapshot);
    _events = mergeActiveLocationRecords(
      _superAdminEvents,
      _adminLocations.activeLocationIds,
      idOf: (item) => item.id,
    )..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    _isEventsLoading = false;
    _eventsErrorMessage = null;
    notifyListeners();
  }

  void _handleSuperAdminResourcesSnapshot(
    String locationId,
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int generation,
  ) {
    if (generation != _superAdminContentGeneration) return;
    _superAdminResources[locationId] = _resourcesFromSnapshot(snapshot);
    _resources = mergeActiveLocationRecords(
      _superAdminResources,
      _adminLocations.activeLocationIds,
      idOf: (item) => item.id,
    )..sort((a, b) => a.title.compareTo(b.title));
    _isResourcesLoading = false;
    _resourcesErrorMessage = null;
    notifyListeners();
  }

  void _handleSuperAdminContentError(
    String locationId,
    int generation,
    _SuperAdminContent content,
  ) {
    if (generation != _superAdminContentGeneration) return;
    switch (content) {
      case _SuperAdminContent.schedule:
        _superAdminSchedules.remove(locationId);
        _isScheduleLoading = false;
      case _SuperAdminContent.announcements:
        _superAdminAnnouncements.remove(locationId);
        _isAnnouncementsLoading = false;
      case _SuperAdminContent.events:
        _superAdminEvents.remove(locationId);
        _isEventsLoading = false;
      case _SuperAdminContent.resources:
        _superAdminResources.remove(locationId);
        _isResourcesLoading = false;
    }
    notifyListeners();
  }

  void _cancelSuperAdminContentListeners() {
    ++_superAdminContentGeneration;
    final subscriptions = [..._superAdminContentSubscriptions];
    _superAdminContentSubscriptions.clear();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void _handleScheduleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _loadTimeZonesForSnapshot(snapshot);
    _schedule = _scheduleFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    if (_latestAnnouncementsSnapshot != null &&
        firebaseSessionController.stage == SessionStage.approved) {
      _notifications = _announcementsFromSnapshot(
        _latestAnnouncementsSnapshot!,
      );
    }
    _isScheduleLoading = false;
    _scheduleErrorMessage = null;
    notifyListeners();
  }

  void _handleScheduleError(Object error) {
    _schedule = const <int, List<ClassSession>>{};
    _isScheduleLoading = false;
    _scheduleErrorMessage = 'Unable to load schedule from Firestore.';
    notifyListeners();
  }

  void _handleAnnouncementsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _loadTimeZonesForSnapshot(snapshot);
    _latestAnnouncementsSnapshot = snapshot;
    _adminAnnouncements = firebaseSessionController.stage == SessionStage.admin
        ? _adminAnnouncementsFromSnapshot(snapshot)
        : const <AcademyAnnouncement>[];
    _notifications = firebaseSessionController.stage == SessionStage.approved
        ? _announcementsFromSnapshot(snapshot)
        : const <NotificationItem>[];
    _isUsingFallbackData = false;
    _isAnnouncementsLoading = false;
    _announcementsErrorMessage = null;
    notifyListeners();
  }

  void _handleAnnouncementsError(Object error) {
    _notifications = const <NotificationItem>[];
    _adminAnnouncements = const <AcademyAnnouncement>[];
    _isAnnouncementsLoading = false;
    _announcementsErrorMessage = 'Unable to load announcements from Firestore.';
    notifyListeners();
  }

  void _handleEventsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _loadTimeZonesForSnapshot(snapshot);
    _events = _eventsFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    _isEventsLoading = false;
    _eventsErrorMessage = null;
    notifyListeners();
  }

  void _handleEventsError(Object error) {
    _events = const <AcademyEvent>[];
    _isEventsLoading = false;
    _eventsErrorMessage = 'Unable to load events from Firestore.';
    notifyListeners();
  }

  void _handleResourcesSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _loadTimeZonesForSnapshot(snapshot);
    _resources = _resourcesFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    _isResourcesLoading = false;
    _resourcesErrorMessage = null;
    notifyListeners();
  }

  void _handleResourcesError(Object error) {
    _resources = const <AcademyResource>[];
    _isResourcesLoading = false;
    _resourcesErrorMessage = 'Unable to load resources from Firestore.';
    notifyListeners();
  }

  void _handleAdminStudentsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    _adminStudentProfiles = _adminStudentsFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    _isAdminStudentsLoading = false;
    _adminStudentsErrorMessage = null;
    notifyListeners();
  }

  void _handleAdminStudentsError(Object error) {
    _adminStudentProfiles = const <StudentProfile>[];
    _isAdminStudentsLoading = false;
    _adminStudentsErrorMessage =
        'Unable to load student profiles from Firestore.';
    notifyListeners();
  }

  @override
  void dispose() {
    firebaseSessionController.removeListener(_handleSessionChanged);
    _adminLocations.removeListener(_handleAdminLocationsChanged);
    unawaited(_scheduleSubscription?.cancel());
    unawaited(_announcementsSubscription?.cancel());
    unawaited(_eventsSubscription?.cancel());
    unawaited(_resourcesSubscription?.cancel());
    unawaited(_adminStudentsSubscription?.cancel());
    _cancelSuperAdminContentListeners();
    super.dispose();
  }

  @override
  UserAccount get currentUserAccount => firebaseIdentityOrDevelopmentFallback(
    firebaseSessionController.account,
    developmentFallback: _developmentViewMode == DebugViewMode.admin
        ? _debugAdminAccount
        : _fallbackService.currentUserAccount,
    developmentViewActive: _developmentViewActive,
    identityName: 'authenticated account',
  );

  @override
  List<StudentProfile> get linkedStudentProfiles =>
      _developmentViewActive && firebaseSessionController.profiles.isEmpty
      ? _fallbackService.linkedStudentProfiles
      : firebaseSessionController.profiles;

  @override
  List<StudentProfile> get adminStudentProfiles => _adminStudentProfiles;

  @override
  StudentProfile get selectedStudentProfile =>
      firebaseIdentityOrDevelopmentFallback(
        firebaseSessionController.selectedProfile,
        developmentFallback: _fallbackService.selectedStudentProfile,
        developmentViewActive: _developmentViewActive,
        identityName: 'selected student profile',
      );

  @override
  Map<int, List<ClassSession>> get schedule => _schedule;

  @override
  bool get isScheduleLoading => _isScheduleLoading;

  @override
  String? get scheduleErrorMessage => _scheduleErrorMessage;

  @override
  bool get isAnnouncementsLoading => _isAnnouncementsLoading;

  @override
  String? get announcementsErrorMessage => _announcementsErrorMessage;

  @override
  bool get isEventsLoading => _isEventsLoading;

  @override
  String? get eventsErrorMessage => _eventsErrorMessage;

  @override
  bool get isResourcesLoading => _isResourcesLoading;

  @override
  String? get resourcesErrorMessage => _resourcesErrorMessage;

  @override
  bool get isAdminStudentsLoading => _isAdminStudentsLoading;

  @override
  String? get adminStudentsErrorMessage => _adminStudentsErrorMessage;

  @override
  List<ClassSession> scheduleForWeekday(int weekday) {
    return _schedule[weekday] ?? const <ClassSession>[];
  }

  @override
  ClassSession? nextClassForDashboard() {
    if (_isUsingFallbackData) {
      return _fallbackService.nextClassForDashboard();
    }

    final academyNow = const LocationTimeService().toLocationTime(
      DateTime.now(),
      selectedStudentProfile.locationId,
    );
    return nextEligibleClassFromSchedule(
      schedule,
      selectedStudentProfile,
      currentWeekday: academyNow.weekday,
      currentMinutes: academyNow.hour * 60 + academyNow.minute,
    );
  }

  // TODO: Replace mock delegation with Firestore-backed curriculum resources.
  @override
  List<String> get curriculumBeltOrder => _fallbackService.curriculumBeltOrder;

  // TODO: Replace mock delegation with Firestore-backed curriculum resources.
  @override
  Map<String, CurriculumRequirement> get curriculum =>
      _fallbackService.curriculum;

  // TODO: Replace mock delegation with Firestore-backed curriculum resources.
  @override
  CurriculumRequirement curriculumForBelt(String belt) {
    return _fallbackService.curriculumForBelt(belt);
  }

  // TODO: Replace mock delegation with Firestore-backed curriculum resources.
  @override
  String beltDisplayLabel(String belt) {
    return _fallbackService.beltDisplayLabel(belt);
  }

  @override
  List<NotificationItem> get notifications => _notifications;

  @override
  List<AcademyAnnouncement> get adminAnnouncements => _adminAnnouncements;

  @override
  List<AcademyEvent> get events => _events;

  @override
  List<AcademyResource> get resources => _resources;

  Map<int, List<ClassSession>> _scheduleFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <int, List<ClassSession>>{};
    }

    final groupedSchedule = <int, List<ClassSession>>{};

    for (final document in snapshot.docs) {
      final session = _classSessionFromDocument(document);

      if (session == null || !_recordIsInSessionScope(session.locationId)) {
        continue;
      }
      if (firebaseSessionController.stage == SessionStage.approved &&
          !session.isPublished) {
        continue;
      }

      final weekday = _intValue(document.data()['weekday']);
      if (weekday == null) {
        continue;
      }

      groupedSchedule.putIfAbsent(weekday, () => <ClassSession>[]).add(session);
    }

    return {
      for (final entry in groupedSchedule.entries)
        entry.key: List<ClassSession>.unmodifiable(
          [...entry.value]
            ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)),
        ),
    };
  }

  ClassSession? _classSessionFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final className = _stringValue(data['className']);
    final weekday = _intValue(data['weekday']);
    final startMinutes = _intValue(data['startMinutes']);
    final endMinutes = _intValue(data['endMinutes']);

    if (className == null ||
        weekday == null ||
        startMinutes == null ||
        endMinutes == null) {
      return null;
    }

    final startTime =
        _dateTimeValue(data['startTime']) ??
        _dateTimeFromWeekdayAndMinutes(weekday, startMinutes);
    final endTime =
        _dateTimeValue(data['endTime']) ??
        _dateTimeFromWeekdayAndMinutes(weekday, endMinutes);

    return ClassSession(
      id: document.id,
      className: className,
      classTypeId:
          _stringValue(data['classTypeId']) ?? _classTypeIdFor(className),
      bulkGroupId:
          _stringValue(data['bulkGroupId']) ??
          '${_stringValue(data['classTypeId']) ?? _classTypeIdFor(className)}-standard',
      locationId: _stringValue(data['locationId']) ?? '',
      startTime: startTime,
      endTime: endTime,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      eligibleBelts: _stringListValue(data['eligibleBelts']),
      description: _stringValue(data['description']) ?? '',
      eligibilityNote: _stringValue(data['eligibilityNote']),
      isPreferred: _boolValue(data['isPreferred']) ?? false,
      isPublished:
          _boolValue(data['isActive']) ??
          _boolValue(data['isPublished']) ??
          true,
      resumesOn: _dateTimeValue(data['resumesOn']),
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

  List<NotificationItem> _announcementsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <NotificationItem>[];
    }

    final announcements = <NotificationItem>[];

    for (final document in snapshot.docs) {
      final announcement = _notificationFromAnnouncementDocument(document);
      if (announcement != null) {
        announcements.add(announcement);
      }
    }

    announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List<NotificationItem>.unmodifiable(announcements);
  }

  NotificationItem? _notificationFromAnnouncementDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final title = _stringValue(data['title']);
    final summary = _stringValue(data['summary']);
    final body = _stringValue(data['body']);
    final announcementType = _stringValue(data['announcementType']);
    final priority = _stringValue(data['priority']);
    final status = _stringValue(data['status']);
    final audienceType = _stringValue(data['audienceType']);
    final locationId = _stringValue(data['locationId']);
    final publishedAt = _dateTimeValue(data['publishedAt']);
    final createdAt = _dateTimeValue(data['createdAt']);
    final updatedAt = _dateTimeValue(data['updatedAt']);
    final targetBelts = _stringListValue(data['targetBelts']);
    final targetClassTypeIds = _stringListValue(data['targetClassTypeIds']);
    final targetStudentProfileIds = _stringListValue(
      data['targetStudentProfileIds'],
    );
    final targetUserIds = _stringListValue(data['targetUserIds']);

    if (title == null ||
        summary == null ||
        body == null ||
        announcementType == null ||
        priority == null ||
        status == null ||
        audienceType == null ||
        locationId == null ||
        publishedAt == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    if (locationId != selectedStudentProfile.locationId ||
        status != 'published' ||
        !_announcementTargetsSelectedAudience(
          audienceType: audienceType,
          targetBelts: targetBelts,
          targetClassTypeIds: targetClassTypeIds,
          targetStudentProfileIds: targetStudentProfileIds,
          targetUserIds: targetUserIds,
        )) {
      return null;
    }

    return NotificationItem(
      id: document.id,
      locationId: locationId,
      title: title,
      summary: summary,
      body: body,
      timestamp: publishedAt,
      isRead: false,
      category: _categoryForAnnouncementType(announcementType),
      priority: _priorityForAnnouncement(priority),
      requiresAction: _boolValue(data['requiresAction']) ?? false,
    );
  }

  List<AcademyAnnouncement> _adminAnnouncementsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <AcademyAnnouncement>[];
    }

    final announcements = <AcademyAnnouncement>[];

    for (final document in snapshot.docs) {
      final announcement = _academyAnnouncementFromDocument(document);
      if (announcement != null &&
          _recordIsInSessionScope(announcement.locationId)) {
        announcements.add(announcement);
      }
    }

    announcements.sort((a, b) => b.displayDate.compareTo(a.displayDate));
    return List<AcademyAnnouncement>.unmodifiable(announcements);
  }

  AcademyAnnouncement? _academyAnnouncementFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final title = _stringValue(data['title']);
    final summary = _stringValue(data['summary']);
    final body = _stringValue(data['body']);
    final announcementType = _stringValue(data['announcementType']);
    final priority = _stringValue(data['priority']);
    final status = _stringValue(data['status']);
    final audienceType = _stringValue(data['audienceType']);
    final locationId = _stringValue(data['locationId']);
    final createdAt = _dateTimeValue(data['createdAt']);
    final updatedAt = _dateTimeValue(data['updatedAt']);

    if (title == null ||
        summary == null ||
        body == null ||
        announcementType == null ||
        priority == null ||
        status == null ||
        audienceType == null ||
        locationId == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return AcademyAnnouncement(
      id: document.id,
      title: title,
      summary: summary,
      body: body,
      announcementType: announcementType,
      priority: priority,
      status: status,
      audienceType: audienceType,
      locationId: locationId,
      publishedAt: _dateTimeValue(data['publishedAt']),
      createdAt: createdAt,
      updatedAt: updatedAt,
      requiresAction: _boolValue(data['requiresAction']) ?? false,
      targetBelts: _stringListValue(data['targetBelts']),
      targetClassTypeIds: _stringListValue(data['targetClassTypeIds']),
      targetStudentProfileIds: _stringListValue(
        data['targetStudentProfileIds'],
      ),
      targetUserIds: _stringListValue(data['targetUserIds']),
    );
  }

  List<AcademyEvent> _eventsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <AcademyEvent>[];
    }

    final events = <AcademyEvent>[];

    for (final document in snapshot.docs) {
      final event = _eventFromDocument(document);
      if (event != null &&
          _recordIsInSessionScope(event.locationId) &&
          !event.isArchived &&
          event.eventType != 'closure') {
        events.add(event);
      }
    }

    events.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return List<AcademyEvent>.unmodifiable(events);
  }

  AcademyEvent? _eventFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => academyEventFromFirestoreData(document.id, document.data());

  List<AcademyResource> _resourcesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <AcademyResource>[];
    }

    final resources = <AcademyResource>[];

    for (final document in snapshot.docs) {
      final resource = _resourceFromDocument(document);
      if (resource != null && _recordIsInSessionScope(resource.locationId)) {
        resources.add(resource);
      }
    }

    resources.sort((a, b) {
      final category = a.categoryLabel.compareTo(b.categoryLabel);
      if (category != 0) {
        return category;
      }
      return a.title.compareTo(b.title);
    });
    return List<AcademyResource>.unmodifiable(resources);
  }

  AcademyResource? _resourceFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return academyResourceFromFirestoreData(document.id, document.data());
  }

  List<StudentProfile> _adminStudentsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <StudentProfile>[];
    }

    final students = <StudentProfile>[];

    for (final document in snapshot.docs) {
      final student = _studentProfileFromDocument(document);
      if (student != null && _recordIsInSessionScope(student.locationId)) {
        students.add(student);
      }
    }

    students.sort((a, b) => a.name.compareTo(b.name));
    return List<StudentProfile>.unmodifiable(students);
  }

  StudentProfile? _studentProfileFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => studentProfileFromFirestoreData(document.id, document.data());

  bool _announcementTargetsSelectedAudience({
    required String audienceType,
    required List<String> targetBelts,
    required List<String> targetClassTypeIds,
    required List<String> targetStudentProfileIds,
    required List<String> targetUserIds,
  }) {
    return switch (audienceType) {
      'everyone' => true,
      'belt' => targetBelts.contains(selectedStudentProfile.belt),
      'classType' => _selectedProfileClassGroupIds.any(
        _normalizedTargetClassTypeIds(targetClassTypeIds).contains,
      ),
      'students' =>
        targetStudentProfileIds.isEmpty
            ? currentUserAccount.role == UserAccountRole.student
            : targetStudentProfileIds.contains(selectedStudentProfile.id),
      'parents' => currentUserAccount.role == UserAccountRole.parent,
      'specificUsers' => targetUserIds.contains(currentUserAccount.id),
      'mixed' =>
        targetBelts.contains(selectedStudentProfile.belt) ||
            _selectedProfileClassGroupIds.any(
              _normalizedTargetClassTypeIds(targetClassTypeIds).contains,
            ) ||
            targetStudentProfileIds.contains(selectedStudentProfile.id) ||
            targetUserIds.contains(currentUserAccount.id),
      _ => false,
    };
  }

  Set<String> get _selectedProfileClassGroupIds {
    final isTeenOrAdult =
        const LocationTimeService().ageForStudent(selectedStudentProfile) >= 13;
    return {
      ...selectedStudentProfile.preferredClassGroupIds.map(
        _normalizeClassGroupId,
      ),
      ..._inferredClassGroupIdsForBelt(selectedStudentProfile.belt),
      if (isTeenOrAdult) 'teen-adult-sparring',
    };
  }

  bool _recordIsInSessionScope(String locationId) {
    final session = firebaseSessionController;
    return recordIsInDataScope(
      stage: session.stage,
      role: session.account?.role,
      accountLocationId: session.account?.locationId,
      selectedProfileLocationId: session.selectedProfile?.locationId,
      recordLocationId: locationId,
    );
  }

  void _loadTimeZonesForSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final firestore = _firestore;
    if (firestore == null) return;
    final locationIds = snapshot.docs
        .map((document) => _stringValue(document.data()['locationId']))
        .whereType<String>()
        .toSet();
    for (final locationId in locationIds) {
      unawaited(
        const LocationTimeService().loadLocation(firestore, locationId),
      );
    }
  }
}

enum _SuperAdminContent { schedule, announcements, events, resources }

List<T> mergeActiveLocationRecords<T>(
  Map<String, List<T>> recordsByLocation,
  Set<String> activeLocationIds, {
  required String Function(T item) idOf,
}) {
  final byId = <String, T>{};
  for (final locationId in activeLocationIds) {
    for (final item in recordsByLocation[locationId] ?? const []) {
      byId[idOf(item)] = item;
    }
  }
  return byId.values.toList();
}

bool recordIsInDataScope({
  required SessionStage stage,
  required UserAccountRole? role,
  required String? accountLocationId,
  required String? selectedProfileLocationId,
  required String recordLocationId,
}) {
  if (stage == SessionStage.admin) {
    return role == UserAccountRole.superAdmin ||
        accountLocationId == recordLocationId;
  }
  return stage == SessionStage.approved &&
      selectedProfileLocationId == recordLocationId;
}

T firebaseIdentityOrDevelopmentFallback<T>(
  T? firebaseIdentity, {
  required T developmentFallback,
  required bool developmentViewActive,
  required String identityName,
}) {
  if (firebaseIdentity != null) return firebaseIdentity;
  if (kDebugMode && developmentViewActive) return developmentFallback;
  throw StateError('No $identityName is available.');
}

DateTime _dateTimeFromWeekdayAndMinutes(int weekday, int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return DateTime(2026, 6, 21 + weekday, hour, minute);
}

String? _stringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? _intValue(Object? value) {
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    _ => null,
  };
}

AcademyEvent? academyEventFromFirestoreData(
  String id,
  Map<String, dynamic> data,
) {
  final title = _stringValue(data['title']);
  final locationId = _stringValue(data['locationId']);
  final startDateTime =
      (_dateTimeValue(data['startDateTime']) ??
              _dateTimeValue(data['startsAt']))
          ?.toUtc();
  if (title == null || locationId == null || startDateTime == null) return null;

  final endDateTime =
      _dateTimeValue(data['endDateTime'])?.toUtc() ??
      startDateTime.add(const Duration(hours: 1));
  final createdAt = _dateTimeValue(data['createdAt']) ?? startDateTime;
  final updatedAt = _dateTimeValue(data['updatedAt']) ?? createdAt;
  // TODO: Remove this compatibility note after approved event documents have
  // been updated. Legacy registrationUrl and showInResources are ignored.
  return AcademyEvent(
    id: id,
    title: title,
    description: _stringValue(data['description']) ?? '',
    locationId: locationId,
    eventType: _stringValue(data['eventType']) ?? 'specialEvent',
    startDateTime: startDateTime,
    endDateTime: endDateTime,
    registrationDeadline: _dateTimeValue(data['registrationDeadline'])?.toUtc(),
    isPublished: _boolValue(data['isPublished']) ?? false,
    isArchived: _boolValue(data['isArchived']) ?? false,
    linkedResourceIds: _stringListValue(data['linkedResourceIds']),
    primaryRegistrationResourceId: _stringValue(
      data['primaryRegistrationResourceId'],
    ),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

StudentProfile? studentProfileFromFirestoreData(
  String id,
  Map<String, dynamic> data,
) {
  final firstName = _stringValue(data['firstName']);
  final lastName = _stringValue(data['lastName']);
  final name = firstName != null && lastName != null
      ? '$firstName $lastName'
      : _stringValue(data['fullName']) ?? _stringValue(data['name']);
  final locationId = _stringValue(data['locationId']) ?? '';
  final belt = _stringValue(data['beltRank']) ?? _stringValue(data['belt']);
  final dateOfBirth = _dateTimeValue(data['dateOfBirth']);
  // TODO: Remove the legacy age fallback after the approved profiles have
  // been updated with dateOfBirth.
  final legacyAge = dateOfBirth == null ? _intValue(data['age']) : null;
  if (name == null ||
      belt == null ||
      (dateOfBirth == null && legacyAge == null)) {
    return null;
  }

  final stickerProgress = data['stickerProgress'];
  final progress = stickerProgress is Map
      ? stickerProgress
      : const <Object?, Object?>{};
  return Student(
    id: id,
    name: name,
    canonicalFirstName: firstName,
    canonicalLastName: lastName,
    locationId: locationId,
    belt: belt,
    canonicalBeltRank: belt,
    dateOfBirth: dateOfBirth,
    legacyAge: legacyAge,
    stickerCount: _intValue(progress['current']) ?? 0,
    stickersRequired: _intValue(progress['required']) ?? 0,
    nextRank: _stringValue(progress['nextRank']) ?? 'Next rank',
    guardianUserIds: _stringListValue(data['guardianUserIds']),
    guardianEmail: _normalizedOptionalEmail(data['guardianEmail']),
    selfUserId:
        _stringValue(data['linkedUserId']) ?? _stringValue(data['selfUserId']),
    linkedUserId:
        _stringValue(data['linkedUserId']) ?? _stringValue(data['selfUserId']),
    approvalStatus: _studentApprovalStatus(data['approvalStatus']),
    familyApplicationId: _stringValue(data['familyApplicationId']),
    preferredClassGroupIds: _stringListValue(data['preferredClassGroupIds']),
    promotionHistory: _stringListValue(data['promotionHistory']),
    testingNotes: _stringListValue(data['testingNotes']),
    isActive: _boolValue(data['isActive']) ?? true,
    createdAt: _dateTimeValue(data['createdAt']),
    updatedAt: _dateTimeValue(data['updatedAt']),
    reviewedAt: _dateTimeValue(data['reviewedAt']),
    reviewedBy: _stringValue(data['reviewedBy']),
    rejectionReason: _stringValue(data['rejectionReason']),
  );
}

String? _normalizedOptionalEmail(Object? value) {
  final email = _stringValue(value);
  return email?.toLowerCase();
}

StudentApprovalStatus _studentApprovalStatus(Object? value) {
  return switch (value) {
    'incomplete' => StudentApprovalStatus.incomplete,
    'pending' => StudentApprovalStatus.pending,
    'rejected' => StudentApprovalStatus.rejected,
    'disabled' => StudentApprovalStatus.disabled,
    _ => StudentApprovalStatus.approved,
  };
}

bool? _boolValue(Object? value) {
  return value is bool ? value : null;
}

DateTime? _dateTimeValue(Object? value) {
  return switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }

  return value.whereType<String>().toList(growable: false);
}

Set<String> _normalizedTargetClassTypeIds(List<String> targetClassTypeIds) {
  return targetClassTypeIds.map(_normalizeClassGroupId).toSet();
}

String _normalizeClassGroupId(String id) {
  return switch (id) {
    'black-belt' || 'teen-black-belt' || 'adult' => 'teen-adult',
    'sparring-class' => 'level-1-2-sparring',
    _ => id,
  };
}

Set<String> _inferredClassGroupIdsForBelt(String belt) {
  return switch (belt) {
    'White' || 'White-Yellow' || 'Yellow' => {'level-1'},
    'Yellow-Green' || 'Green' || 'Green-Blue' => {'level-2'},
    'Blue' || 'Blue-Red' => {'level-3'},
    'Red' ||
    'Red-Yellow' ||
    'Red-Green' ||
    'Red-Blue' ||
    'Red-Black' => {'level-4'},
    _ => const <String>{},
  };
}

String _classTypeIdFor(String className) {
  return switch (className) {
    'Little Tiger (Age 3-5)' => 'little-tiger',
    'Level 1' => 'level-1',
    'Level 2' => 'level-2',
    'Level 3' => 'level-3',
    'Level 4' => 'level-4',
    'Black Belt' || 'Teen & Black Belt' || 'Adult' => 'teen-adult',
    'Teen/Adult Sparring' => 'teen-adult-sparring',
    'Level 1 / Level 2 Sparring' => 'level-1-2-sparring',
    _ => className.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
  };
}

NotificationCategory _categoryForAnnouncementType(String announcementType) {
  return switch (announcementType) {
    'tournament' => NotificationCategory.tournament,
    'scheduleChange' || 'schedule' => NotificationCategory.scheduleChange,
    'beltTesting' || 'testing' => NotificationCategory.beltTesting,
    'summerCamp' || 'camp' => NotificationCategory.summerCamp,
    'holiday' || 'closure' => NotificationCategory.holiday,
    'reminder' => NotificationCategory.reminder,
    'curriculum' => NotificationCategory.curriculum,
    _ => NotificationCategory.general,
  };
}

NotificationPriority _priorityForAnnouncement(String priority) {
  return switch (priority) {
    'important' => NotificationPriority.important,
    'critical' => NotificationPriority.important,
    _ => NotificationPriority.general,
  };
}
