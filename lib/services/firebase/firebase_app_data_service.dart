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
import '../app_data_service.dart';
import '../firestore/firestore_collections.dart';
import '../location_time_service.dart';
import '../mock_app_data_service.dart';

class FirebaseAppDataService extends ChangeNotifier implements AppDataService {
  FirebaseAppDataService({
    FirebaseFirestore? firestore,
    AppDataService? fallbackService,
  }) : _fallbackService = fallbackService ?? const MockAppDataService() {
    _firestore = firestore;
    _listenToFirestore();
  }

  FirebaseFirestore? _firestore;
  final AppDataService _fallbackService;
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

  void _listenToFirestore() {
    try {
      if (_firestore == null && Firebase.apps.isEmpty) {
        _useFallbackDataForUnavailableFirebase();
        return;
      }

      final firestore = _firestore ?? FirebaseFirestore.instance;
      _firestore = firestore;
      unawaited(
        const LocationTimeService().loadLocation(
          firestore,
          LocationTimeService.otaCheshireLocationId,
        ),
      );
      _listenToSchedule(firestore);
      _listenToAnnouncements(firestore);
      _listenToEvents(firestore);
      _listenToResources(firestore);
      _listenToAdminStudents(firestore);
    } catch (_) {
      _useFallbackDataForUnavailableFirebase();
    }
  }

  void _useFallbackDataForUnavailableFirebase() {
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

  void _listenToSchedule(FirebaseFirestore firestore) {
    _scheduleSubscription = firestore
        .collection(FirestoreCollections.classSessions)
        .orderBy('weekday')
        .orderBy('startMinutes')
        .snapshots()
        .listen(_handleScheduleSnapshot, onError: _handleScheduleError);
  }

  void _listenToAnnouncements(FirebaseFirestore firestore) {
    _announcementsSubscription = firestore
        .collection(FirestoreCollections.announcements)
        .snapshots()
        .listen(
          _handleAnnouncementsSnapshot,
          onError: _handleAnnouncementsError,
        );
  }

  void _listenToEvents(FirebaseFirestore firestore) {
    _eventsSubscription = firestore
        .collection(FirestoreCollections.events)
        .snapshots()
        .listen(_handleEventsSnapshot, onError: _handleEventsError);
  }

  void _listenToResources(FirebaseFirestore firestore) {
    _resourcesSubscription = firestore
        .collection(FirestoreCollections.resources)
        .snapshots()
        .listen(_handleResourcesSnapshot, onError: _handleResourcesError);
  }

  void _listenToAdminStudents(FirebaseFirestore firestore) {
    _adminStudentsSubscription = firestore
        .collection(FirestoreCollections.studentProfiles)
        .snapshots()
        .listen(
          _handleAdminStudentsSnapshot,
          onError: _handleAdminStudentsError,
        );
  }

  void _handleScheduleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _schedule = _scheduleFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    if (_latestAnnouncementsSnapshot != null) {
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
    _latestAnnouncementsSnapshot = snapshot;
    _adminAnnouncements = _adminAnnouncementsFromSnapshot(snapshot);
    _notifications = _announcementsFromSnapshot(snapshot);
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
    unawaited(_scheduleSubscription?.cancel());
    unawaited(_announcementsSubscription?.cancel());
    unawaited(_eventsSubscription?.cancel());
    unawaited(_resourcesSubscription?.cancel());
    unawaited(_adminStudentsSubscription?.cancel());
    super.dispose();
  }

  // TODO: Replace mock delegation with Firebase Auth and Firestore-backed users.
  @override
  UserAccount get currentUserAccount => _fallbackService.currentUserAccount;

  // TODO: Replace mock delegation with Firestore-backed student profiles.
  @override
  List<StudentProfile> get linkedStudentProfiles =>
      _fallbackService.linkedStudentProfiles;

  @override
  List<StudentProfile> get adminStudentProfiles => _adminStudentProfiles;

  // TODO: Replace mock delegation with Firestore-backed selected profiles.
  @override
  StudentProfile get selectedStudentProfile =>
      _fallbackService.selectedStudentProfile;

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

    final weekdays = _weekdaysStartingWith(DateTime.now().weekday);

    for (final weekday in weekdays) {
      for (final session in scheduleForWeekday(weekday)) {
        if (session.isEligibleFor(selectedStudentProfile)) {
          return session;
        }
      }
    }

    for (final weekday in weekdays) {
      final sessions = scheduleForWeekday(weekday);
      if (sessions.isNotEmpty) {
        return sessions.first;
      }
    }

    return null;
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

      if (session == null ||
          session.locationId != selectedStudentProfile.locationId ||
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
      locationId:
          _stringValue(data['locationId']) ?? selectedStudentProfile.locationId,
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
      if (announcement != null && announcement.locationId == _adminLocationId) {
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
          event.locationId == _adminLocationId &&
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
  ) {
    final data = document.data();
    final title = _stringValue(data['title']);
    final locationId = _stringValue(data['locationId']);
    final startDateTime =
        (_dateTimeValue(data['startDateTime']) ??
                _dateTimeValue(data['startsAt']))
            ?.toUtc();

    if (title == null || locationId == null || startDateTime == null) {
      return null;
    }

    final endDateTime =
        _dateTimeValue(data['endDateTime'])?.toUtc() ??
        startDateTime.add(const Duration(hours: 1));
    final createdAt = _dateTimeValue(data['createdAt']) ?? startDateTime;
    final updatedAt = _dateTimeValue(data['updatedAt']) ?? createdAt;

    return AcademyEvent(
      id: document.id,
      title: title,
      description: _stringValue(data['description']) ?? '',
      locationId: locationId,
      eventType: _stringValue(data['eventType']) ?? 'specialEvent',
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      registrationUrl: _stringValue(data['registrationUrl']),
      registrationDeadline: _dateTimeValue(
        data['registrationDeadline'],
      )?.toUtc(),
      isPublished: _boolValue(data['isPublished']) ?? false,
      showInResources: _boolValue(data['showInResources']) ?? false,
      isArchived: _boolValue(data['isArchived']) ?? false,
      linkedResourceIds: _stringListValue(data['linkedResourceIds']),
      primaryRegistrationResourceId: _stringValue(
        data['primaryRegistrationResourceId'],
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<AcademyResource> _resourcesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (snapshot.docs.isEmpty) {
      return const <AcademyResource>[];
    }

    final resources = <AcademyResource>[];

    for (final document in snapshot.docs) {
      final resource = _resourceFromDocument(document);
      if (resource != null && resource.locationId == _adminLocationId) {
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
    final data = document.data();
    final title = _stringValue(data['title']);
    final locationId = _stringValue(data['locationId']);
    final createdAt = _dateTimeValue(data['createdAt']);
    final updatedAt = _dateTimeValue(data['updatedAt']);

    if (title == null ||
        locationId == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return AcademyResource(
      id: document.id,
      title: title,
      description: _stringValue(data['description']) ?? '',
      resourceSection: _stringValue(data['resourceSection']) ?? 'general',
      resourceType: _stringValue(data['resourceType']) ?? 'general',
      category: _stringValue(data['category']) ?? 'general',
      linkUrl: _stringValue(data['linkUrl']) ?? _stringValue(data['url']),
      locationId: locationId,
      isPublished: _boolValue(data['isPublished']) ?? false,
      isArchived: _boolValue(data['isArchived']) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
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
      if (student != null && student.locationId == _adminLocationId) {
        students.add(student);
      }
    }

    students.sort((a, b) => a.name.compareTo(b.name));
    return List<StudentProfile>.unmodifiable(students);
  }

  StudentProfile? _studentProfileFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final name = _stringValue(data['fullName']) ?? _stringValue(data['name']);
    final locationId = _stringValue(data['locationId']);
    final belt = _stringValue(data['beltRank']) ?? _stringValue(data['belt']);
    final age = _intValue(data['age']);

    if (name == null || locationId == null || belt == null || age == null) {
      return null;
    }

    final stickerProgress = data['stickerProgress'];
    final stickerProgressMap = stickerProgress is Map
        ? stickerProgress
        : const <Object?, Object?>{};

    return Student(
      id: document.id,
      name: name,
      locationId: locationId,
      belt: belt,
      age: age,
      stickerCount: _intValue(stickerProgressMap['current']) ?? 0,
      stickersRequired: _intValue(stickerProgressMap['required']) ?? 0,
      nextRank: _stringValue(stickerProgressMap['nextRank']) ?? 'Next rank',
      guardianUserIds: _stringListValue(data['guardianUserIds']),
      selfUserId: _stringValue(data['selfUserId']),
      preferredClassGroupIds: _stringListValue(data['preferredClassGroupIds']),
      promotionHistory: _stringListValue(data['promotionHistory']),
      testingNotes: _stringListValue(data['testingNotes']),
      isActive: _boolValue(data['isActive']) ?? true,
      createdAt: _dateTimeValue(data['createdAt']),
      updatedAt: _dateTimeValue(data['updatedAt']),
    );
  }

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
    return {
      ...selectedStudentProfile.preferredClassGroupIds.map(
        _normalizeClassGroupId,
      ),
      ..._inferredClassGroupIdsForBelt(selectedStudentProfile.belt),
    };
  }

  String get _adminLocationId {
    final userLocationId = currentUserAccount.locationId;
    if (userLocationId.isNotEmpty) {
      return userLocationId;
    }

    return selectedStudentProfile.locationId;
  }
}

List<int> _weekdaysStartingWith(int weekday) {
  return [
    for (var offset = 0; offset < DateTime.daysPerWeek; offset++)
      ((weekday + offset - 1) % DateTime.daysPerWeek) + 1,
  ];
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
    'Black Belt' ||
    'Teen & Black Belt' ||
    'Adult' ||
    'Teen/Adult Sparring' => 'teen-adult',
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
