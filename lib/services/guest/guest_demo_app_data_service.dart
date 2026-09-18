import 'package:flutter/foundation.dart';

import '../../data/sample_curriculum.dart' as curriculum_data;
import '../../data/sample_schedule.dart';
import '../../models/academy_announcement.dart';
import '../../models/academy_event.dart';
import '../../models/academy_resource.dart';
import '../../models/class_session.dart';
import '../../models/curriculum_requirement.dart';
import '../../models/notification_item.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../app_data_service.dart';
import '../firebase/firebase_admin_write_service.dart';
import '../firebase/profile_service.dart';
import '../location_time_service.dart';
import 'guest_experience_controller.dart';

const guestDemoLocationId = 'review-demo-academy';
const guestDemoLocationName = 'Northstar Martial Arts Demo';

class GuestDemoAppDataService extends ChangeNotifier
    implements AppDataService, AdminWriteService {
  GuestDemoAppDataService({GuestExperienceController? controller})
    : _controller = controller ?? guestExperienceController {
    LocationTimeService.initialize();
    const LocationTimeService().cacheTimeZone(
      guestDemoLocationId,
      LocationTimeService.otaCheshireTimeZoneId,
    );
    _controller.addListener(_handleViewChanged);
    reset();
  }

  final GuestExperienceController _controller;
  final Map<String, bool> _notificationReadOverrides = {};
  late UserAccount _parentAccount;
  late UserAccount _studentAccount;
  late UserAccount _adminAccount;
  late List<StudentProfile> _profiles;
  late Map<int, List<ClassSession>> _schedule;
  late List<AcademyAnnouncement> _announcements;
  late List<AcademyEvent> _events;
  late List<AcademyResource> _resources;
  int _nextId = 1;

  void _handleViewChanged() => notifyListeners();

  void reset() {
    const parentId = 'demo-parent-account';
    const studentId = 'demo-student-account';
    _parentAccount = const UserAccount(
      id: parentId,
      firstName: 'Alex',
      lastName: 'Rowan',
      email: 'alex.rowan@example.invalid',
      role: UserAccountRole.parent,
      locationId: guestDemoLocationId,
      linkedStudentProfileIds: ['demo-casey', 'demo-riley'],
      selectedStudentProfileId: 'demo-casey',
    );
    _studentAccount = const UserAccount(
      id: studentId,
      firstName: 'Casey',
      lastName: 'Rowan',
      email: 'casey.rowan@example.invalid',
      role: UserAccountRole.student,
      locationId: guestDemoLocationId,
      linkedStudentProfileIds: ['demo-casey'],
      selectedStudentProfileId: 'demo-casey',
    );
    _adminAccount = const UserAccount(
      id: 'demo-admin-account',
      firstName: 'Jordan',
      lastName: 'Lee',
      email: 'jordan.lee@example.invalid',
      role: UserAccountRole.admin,
      locationId: guestDemoLocationId,
      linkedStudentProfileIds: [],
    );
    _profiles = [
      StudentProfile(
        id: 'demo-casey',
        name: 'Casey Rowan',
        canonicalFirstName: 'Casey',
        canonicalLastName: 'Rowan',
        locationId: guestDemoLocationId,
        belt: 'Blue',
        canonicalBeltRank: 'Blue',
        dateOfBirth: DateTime.utc(2012, 4, 18),
        stickerCount: 3,
        stickersRequired: 4,
        nextRank: 'Blue-Red',
        guardianUserIds: const [parentId],
        guardianEmail: 'alex.rowan@example.invalid',
        preferredClassGroupIds: const ['level-3-standard'],
      ),
      StudentProfile(
        id: 'demo-riley',
        name: 'Riley Rowan',
        canonicalFirstName: 'Riley',
        canonicalLastName: 'Rowan',
        locationId: guestDemoLocationId,
        belt: 'Yellow-Green',
        canonicalBeltRank: 'Yellow-Green',
        dateOfBirth: DateTime.utc(2016, 9, 7),
        stickerCount: 2,
        stickersRequired: 4,
        nextRank: 'Green',
        guardianUserIds: const [parentId],
        guardianEmail: 'alex.rowan@example.invalid',
        preferredClassGroupIds: const ['level-2-standard'],
      ),
      StudentProfile(
        id: 'demo-morgan',
        name: 'Morgan Chen',
        canonicalFirstName: 'Morgan',
        canonicalLastName: 'Chen',
        locationId: guestDemoLocationId,
        belt: 'White-Yellow',
        canonicalBeltRank: 'White-Yellow',
        dateOfBirth: DateTime.utc(2018, 2, 11),
        stickerCount: 1,
        stickersRequired: 3,
        nextRank: 'Yellow',
        guardianUserIds: const ['demo-chen-parent'],
        guardianEmail: 'guardian.chen@example.invalid',
        preferredClassGroupIds: const ['level-1-standard'],
      ),
    ];
    _schedule = {
      for (final entry in sampleSummerSchedule.entries)
        entry.key: [for (final item in entry.value) _demoSession(item)],
    };
    final now = DateTime.now().toUtc();
    _resources = [
      AcademyResource(
        id: 'demo-testing-checklist',
        title: 'Demo Belt Testing Checklist',
        description:
            'Fictional preparation checklist for the demonstration family.',
        category: 'testing',
        locationId: guestDemoLocationId,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      AcademyResource(
        id: 'demo-event-registration',
        title: 'Demo Family Workshop Registration',
        description:
            'Fictional registration resource; no external form is opened.',
        category: 'registration',
        locationId: guestDemoLocationId,
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    _events = [
      AcademyEvent(
        id: 'demo-family-workshop',
        title: 'Demo Family Workshop',
        description: 'A fictional workshop shared across reviewer views.',
        locationId: guestDemoLocationId,
        eventType: 'seminar',
        startDateTime: now.add(const Duration(days: 12)),
        endDateTime: now.add(const Duration(days: 12, hours: 2)),
        registrationDeadline: now.add(const Duration(days: 9)),
        linkedResourceIds: const ['demo-event-registration'],
        primaryRegistrationResourceId: 'demo-event-registration',
        isPublished: true,
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      AcademyEvent(
        id: 'demo-testing-day',
        title: 'Demo Belt Testing Day',
        description: 'Fictional testing event for demonstration students.',
        locationId: guestDemoLocationId,
        eventType: 'beltTesting',
        startDateTime: now.add(const Duration(days: 28)),
        endDateTime: now.add(const Duration(days: 28, hours: 3)),
        isPublished: false,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    _announcements = [
      AcademyAnnouncement(
        id: 'demo-workshop-announcement',
        title: 'Demo Family Workshop Registration',
        summary: 'Registration is open for the fictional family workshop.',
        body:
            'This demonstration announcement refers to the Demo Family Workshop and its matching resource.',
        announcementType: 'reminder',
        priority: 'important',
        status: 'published',
        audienceType: 'everyone',
        locationId: guestDemoLocationId,
        requiresAction: true,
        publishedAt: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      AcademyAnnouncement(
        id: 'demo-blue-class-note',
        title: 'Demo Level 3 Curriculum Reminder',
        summary: 'Blue belts should review the testing checklist.',
        body:
            'Casey and other fictional Blue belt students should review the linked demonstration materials.',
        announcementType: 'curriculum',
        priority: 'general',
        status: 'published',
        audienceType: 'belt',
        targetBelts: const ['Blue'],
        locationId: guestDemoLocationId,
        publishedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    _notificationReadOverrides.clear();
    _nextId = 1;
    notifyListeners();
  }

  @override
  UserAccount get currentUserAccount => switch (_controller.mode) {
    GuestViewMode.admin => _adminAccount,
    GuestViewMode.student => _studentAccount,
    GuestViewMode.parent => _parentAccount,
  };

  @override
  List<StudentProfile> get linkedStudentProfiles {
    final ids = currentUserAccount.linkedStudentProfileIds;
    return _profiles.where((profile) => ids.contains(profile.id)).toList();
  }

  @override
  List<StudentProfile> get adminStudentProfiles => List.unmodifiable(_profiles);

  @override
  List<UserAccount> get adminUserAccounts => [_parentAccount, _studentAccount];

  @override
  StudentProfile get selectedStudentProfile {
    final id = currentUserAccount.selectedStudentProfileId ?? 'demo-casey';
    return _profiles.firstWhere((profile) => profile.id == id);
  }

  @override
  Map<int, List<ClassSession>> get schedule => Map.unmodifiable(_schedule);
  @override
  bool get isScheduleLoading => false;
  @override
  String? get scheduleErrorMessage => null;
  @override
  bool get isAnnouncementsLoading => false;
  @override
  String? get announcementsErrorMessage => null;
  @override
  bool get isEventsLoading => false;
  @override
  String? get eventsErrorMessage => null;
  @override
  bool get isAdminStudentsLoading => false;
  @override
  String? get adminStudentsErrorMessage => null;
  @override
  bool get isResourcesLoading => false;
  @override
  String? get resourcesErrorMessage => null;
  @override
  void retryLiveData() {}

  @override
  List<ClassSession> scheduleForWeekday(int weekday) =>
      List.unmodifiable(_schedule[weekday] ?? const []);

  @override
  ClassSession? nextClassForDashboard() => nextEligibleClassFromSchedule(
    _schedule,
    selectedStudentProfile,
    currentWeekday: DateTime.now().weekday,
    currentMinutes: DateTime.now().hour * 60 + DateTime.now().minute,
  );

  @override
  List<String> get curriculumBeltOrder => curriculum_data.curriculumBeltOrder;
  @override
  Map<String, CurriculumRequirement> get curriculum =>
      Map.unmodifiable(curriculum_data.sampleCurriculum);
  @override
  CurriculumRequirement curriculumForBelt(String belt) =>
      curriculum[belt] ?? curriculum.values.first;
  @override
  String beltDisplayLabel(String belt) =>
      curriculum_data.beltDisplayLabel(belt);

  @override
  List<NotificationItem> get notifications {
    final profile = selectedStudentProfile;
    return _announcements
        .where(
          (item) => item.isPublished && _visibleToCurrentView(item, profile),
        )
        .map(
          (item) => NotificationItem(
            id: item.id,
            locationId: guestDemoLocationId,
            title: item.title,
            summary: item.summary,
            body: item.body,
            timestamp: item.publishedAt ?? item.updatedAt,
            isRead: _notificationReadOverrides[item.id] ?? false,
            category: item.category,
            priority: item.notificationPriority,
            requiresAction: item.requiresAction,
          ),
        )
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  bool _visibleToCurrentView(AcademyAnnouncement item, StudentProfile profile) {
    return switch (item.audienceType) {
      'everyone' => true,
      'parents' => _controller.mode == GuestViewMode.parent,
      'students' => _controller.mode == GuestViewMode.student,
      'belt' => item.targetBelts.contains(profile.belt),
      'classType' => profile.preferredClassGroupIds.any(
        item.targetClassTypeIds.contains,
      ),
      'specificUsers' => item.targetUserIds.contains(currentUserAccount.id),
      _ => item.targetStudentProfileIds.contains(profile.id),
    };
  }

  @override
  Future<void> markNotificationRead(String id) async => _markRead(id, true);
  @override
  Future<void> markNotificationUnread(String id) async => _markRead(id, false);
  void _markRead(String id, bool value) {
    _notificationReadOverrides[id] = value;
    notifyListeners();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (final item in notifications) {
      _notificationReadOverrides[item.id] = true;
    }
    notifyListeners();
  }

  @override
  List<AcademyAnnouncement> get adminAnnouncements =>
      List.unmodifiable(_announcements);
  @override
  List<AcademyEvent> get events => List.unmodifiable(_events);
  @override
  List<AcademyResource> get resources => List.unmodifiable(_resources);

  @override
  Future<void> saveAnnouncement(AnnouncementWriteData data) async {
    final now = DateTime.now().toUtc();
    final value = AcademyAnnouncement(
      id: data.id ?? _id('announcement'),
      title: data.title,
      summary: data.summary,
      body: data.body,
      announcementType: data.announcementType,
      priority: data.priority == 'critical' ? 'important' : data.priority,
      status: data.status,
      audienceType: data.audienceType,
      targetBelts: List.unmodifiable(data.targetBelts),
      targetClassTypeIds: List.unmodifiable(data.targetClassTypeIds),
      targetStudentProfileIds: List.unmodifiable(data.targetStudentProfileIds),
      targetUserIds: List.unmodifiable(data.targetUserIds),
      locationId: guestDemoLocationId,
      requiresAction: data.requiresAction,
      publishedAt: data.status == 'published' ? data.publishedAt ?? now : null,
      createdAt: data.createdAt ?? now,
      updatedAt: now,
    );
    _replaceById(_announcements, value, (item) => item.id);
  }

  @override
  Future<void> archiveAnnouncement(String id) async {
    final old = _announcements.firstWhere((item) => item.id == id);
    await saveAnnouncement(
      AnnouncementWriteData.fromAnnouncement(
        old,
        title: old.title,
        summary: old.summary,
        body: old.body,
        announcementType: old.announcementType,
        priority: old.priority,
        status: 'archived',
        locationId: guestDemoLocationId,
      ),
    );
  }

  @override
  Future<void> deleteAnnouncement(String id) async =>
      _removeById(_announcements, id, (item) => item.id);

  @override
  Future<void> saveEvent(EventWriteData data) async {
    final now = DateTime.now().toUtc();
    _replaceById(
      _events,
      AcademyEvent(
        id: data.id ?? _id('event'),
        title: data.title,
        description: data.description,
        locationId: guestDemoLocationId,
        eventType: data.eventType,
        startDateTime: data.startDateTime,
        endDateTime: data.endDateTime,
        registrationDeadline: data.registrationDeadline,
        linkedResourceIds: List.unmodifiable(data.linkedResourceIds),
        primaryRegistrationResourceId: data.primaryRegistrationResourceId,
        isPublished: data.isPublished,
        isArchived: data.isArchived,
        createdAt: data.createdAt ?? now,
        updatedAt: now,
      ),
      (item) => item.id,
    );
  }

  @override
  Future<void> archiveEvent(String id) async {
    final old = _events.firstWhere((item) => item.id == id);
    await saveEvent(
      EventWriteData(
        id: old.id,
        title: old.title,
        description: old.description,
        locationId: guestDemoLocationId,
        eventType: old.eventType,
        startDateTime: old.startDateTime,
        endDateTime: old.endDateTime,
        registrationDeadline: old.registrationDeadline,
        linkedResourceIds: old.linkedResourceIds,
        primaryRegistrationResourceId: old.primaryRegistrationResourceId,
        isPublished: old.isPublished,
        isArchived: true,
        createdAt: old.createdAt,
      ),
    );
  }

  @override
  Future<void> deleteEvent(String id) async =>
      _removeById(_events, id, (item) => item.id);

  @override
  Future<void> saveResource(ResourceWriteData data) async {
    final now = DateTime.now().toUtc();
    _replaceById(
      _resources,
      AcademyResource(
        id: data.id ?? _id('resource'),
        title: data.title,
        description: data.description,
        resourceSection: data.resourceSection,
        category: data.category,
        linkUrl: data.linkUrl,
        locationId: guestDemoLocationId,
        isPublished: data.isPublished,
        isArchived: data.isArchived,
        createdAt: data.createdAt ?? now,
        updatedAt: now,
      ),
      (item) => item.id,
    );
  }

  @override
  Future<void> archiveResource(String id) async {
    final old = _resources.firstWhere((item) => item.id == id);
    await saveResource(
      ResourceWriteData.fromResource(
        old,
        title: old.title,
        description: old.description,
        category: old.category,
        locationId: guestDemoLocationId,
        isPublished: old.isPublished,
        linkUrl: old.linkUrl,
        isArchived: true,
      ),
    );
  }

  @override
  Future<void> deleteResource(String id) async =>
      _removeById(_resources, id, (item) => item.id);

  @override
  Future<void> saveClassSession(ClassSessionWriteData data) async {
    final session = ClassSession(
      id: data.id ?? _id('class'),
      className: data.className,
      classTypeId: data.classTypeId,
      bulkGroupId: data.bulkGroupId,
      locationId: guestDemoLocationId,
      startTime: data.startTime,
      endTime: data.endTime,
      startMinutes: data.startMinutes,
      endMinutes: data.endMinutes,
      eligibleBelts: List.unmodifiable(data.eligibleBelts),
      description: data.description,
      eligibilityNote: data.eligibilityNote,
      isPublished: data.isActive,
      resumesOn: data.resumesOn,
      createdAt: data.createdAt ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    for (final list in _schedule.values) {
      list.removeWhere((item) => item.id == session.id);
    }
    (_schedule[data.weekday] ??= []).add(session);
    _schedule[data.weekday]!.sort(
      (a, b) => a.startMinutes.compareTo(b.startMinutes),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteClassSession(String id) async {
    for (final list in _schedule.values) {
      list.removeWhere((item) => item.id == id);
    }
    notifyListeners();
  }

  @override
  Future<void> updateStudentProgress(AdminStudentProgressWriteData data) async {
    adminStudentProgressWriteFields(data);
    final old = _profile(data.profileId);
    _replaceProfile(
      _copyProfile(
        old,
        belt: data.beltRank,
        stickerCount: data.stickerCurrent,
        stickersRequired: data.stickerRequired,
        nextRank: _nextBelt(data.beltRank),
      ),
    );
  }

  Future<void> selectProfile(String id) async {
    if (!_parentAccount.linkedStudentProfileIds.contains(id)) return;
    _parentAccount = _copyAccount(_parentAccount, selectedProfileId: id);
    notifyListeners();
  }

  Future<void> updateAccountContact(AccountContactInput input) async {
    final firstName = input.firstName.trim();
    final lastName = input.lastName.trim();
    switch (_controller.mode) {
      case GuestViewMode.admin:
        _adminAccount = _copyAccount(
          _adminAccount,
          firstName: firstName,
          lastName: lastName,
        );
      case GuestViewMode.student:
        _studentAccount = _copyAccount(
          _studentAccount,
          firstName: firstName,
          lastName: lastName,
        );
      case GuestViewMode.parent:
        _parentAccount = _copyAccount(
          _parentAccount,
          firstName: firstName,
          lastName: lastName,
        );
    }
    notifyListeners();
  }

  Future<void> updateManagedProfile(StudentProfileEditInput input) async {
    final old = _profile(input.profileId);
    _replaceProfile(
      _copyProfile(
        old,
        firstName: input.firstName.trim(),
        lastName: input.lastName.trim(),
        dateOfBirth: input.dateOfBirth,
        belt: input.beltRank,
        stickerCount: input.stickerCurrent,
        stickersRequired: input.stickerRequired,
        nextRank: _nextBelt(input.beltRank),
        guardianEmail: input.guardianEmail,
      ),
    );
  }

  Future<void> updatePreferredClass(
    StudentProfile profile,
    ClassSession? session,
  ) async {
    _replaceProfile(
      _copyProfile(
        _profile(profile.id),
        preferredClassGroupIds: session == null ? [] : [session.bulkGroupId],
      ),
    );
  }

  Future<String> createChild(StudentProfileInput input) async {
    final id = _id('student');
    _profiles.add(
      StudentProfile(
        id: id,
        name: '${input.firstName.trim()} ${input.lastName.trim()}'.trim(),
        canonicalFirstName: input.firstName.trim(),
        canonicalLastName: input.lastName.trim(),
        locationId: guestDemoLocationId,
        belt: input.beltRank,
        canonicalBeltRank: input.beltRank,
        dateOfBirth: input.dateOfBirth,
        stickerCount: 0,
        stickersRequired: 4,
        nextRank: _nextBelt(input.beltRank),
        guardianUserIds: const ['demo-parent-account'],
        guardianEmail: input.guardianEmail,
      ),
    );
    _parentAccount = _copyAccount(
      _parentAccount,
      linkedIds: [..._parentAccount.linkedStudentProfileIds, id],
    );
    notifyListeners();
    return id;
  }

  Future<String> createParentSelfProfile(ParentSelfProfileInput input) async {
    final id = _id('student');
    _profiles.add(
      StudentProfile(
        id: id,
        name: _parentAccount.displayName,
        canonicalFirstName: _parentAccount.firstName,
        canonicalLastName: _parentAccount.lastName,
        locationId: guestDemoLocationId,
        belt: input.beltRank,
        canonicalBeltRank: input.beltRank,
        dateOfBirth: input.dateOfBirth,
        stickerCount: input.stickerCurrent,
        stickersRequired: input.stickerRequired,
        nextRank: _nextBelt(input.beltRank),
        linkedUserId: _parentAccount.id,
        guardianEmail: input.guardianEmail,
      ),
    );
    _parentAccount = _copyAccount(
      _parentAccount,
      linkedIds: [..._parentAccount.linkedStudentProfileIds, id],
    );
    notifyListeners();
    return id;
  }

  Future<void> removeLinkedProfile(String id) async {
    final ids = _parentAccount.linkedStudentProfileIds
        .where((value) => value != id)
        .toList();
    if (ids.isEmpty) return;
    final old = _profile(id);
    _replaceProfile(_copyProfile(old, isActive: false));
    _parentAccount = _copyAccount(
      _parentAccount,
      linkedIds: ids,
      selectedProfileId: _parentAccount.selectedStudentProfileId == id
          ? ids.first
          : _parentAccount.selectedStudentProfileId,
    );
    notifyListeners();
  }

  String _id(String prefix) => 'demo-$prefix-${_nextId++}';

  void _replaceById<T>(List<T> items, T value, String Function(T) id) {
    final index = items.indexWhere((item) => id(item) == id(value));
    if (index < 0) {
      items.add(value);
    } else {
      items[index] = value;
    }
    notifyListeners();
  }

  void _removeById<T>(List<T> items, String value, String Function(T) id) {
    items.removeWhere((item) => id(item) == value);
    notifyListeners();
  }

  StudentProfile _profile(String id) =>
      _profiles.firstWhere((profile) => profile.id == id);
  void _replaceProfile(StudentProfile value) {
    _profiles[_profiles.indexWhere((profile) => profile.id == value.id)] =
        value;
    notifyListeners();
  }

  String _nextBelt(String belt) {
    final index = curriculumBeltOrder.indexOf(belt);
    return index >= 0 && index < curriculumBeltOrder.length - 1
        ? curriculumBeltOrder[index + 1]
        : 'Black';
  }

  @override
  void dispose() {
    _controller.removeListener(_handleViewChanged);
    super.dispose();
  }
}

ClassSession _demoSession(ClassSession source) => ClassSession(
  id: 'demo-${source.id}',
  className: source.className,
  classTypeId: source.classTypeId,
  bulkGroupId: source.bulkGroupId,
  locationId: guestDemoLocationId,
  startTime: source.startTime,
  endTime: source.endTime,
  startMinutes: source.startMinutes,
  endMinutes: source.endMinutes,
  eligibleBelts: List.unmodifiable(source.eligibleBelts),
  description: source.description,
  eligibilityNote: source.eligibilityNote,
  isPublished: source.isPublished,
);

UserAccount _copyAccount(
  UserAccount source, {
  String? firstName,
  String? lastName,
  List<String>? linkedIds,
  String? selectedProfileId,
}) => UserAccount(
  id: source.id,
  firstName: firstName ?? source.firstName,
  lastName: lastName ?? source.lastName,
  email: source.email,
  role: source.role,
  isActive: source.isActive,
  linkedStudentProfileIds: linkedIds ?? source.linkedStudentProfileIds,
  locationId: source.locationId,
  selectedStudentProfileId:
      selectedProfileId ?? source.selectedStudentProfileId,
);

StudentProfile _copyProfile(
  StudentProfile source, {
  String? firstName,
  String? lastName,
  DateTime? dateOfBirth,
  String? belt,
  int? stickerCount,
  int? stickersRequired,
  String? nextRank,
  String? guardianEmail,
  List<String>? preferredClassGroupIds,
  bool? isActive,
}) {
  final resolvedFirstName = firstName ?? source.firstName;
  final resolvedLastName = lastName ?? source.lastName;
  return StudentProfile(
    id: source.id,
    name: '$resolvedFirstName $resolvedLastName'.trim(),
    canonicalFirstName: resolvedFirstName,
    canonicalLastName: resolvedLastName,
    locationId: source.locationId,
    belt: belt ?? source.belt,
    canonicalBeltRank: belt ?? source.beltRank,
    dateOfBirth: dateOfBirth ?? source.dateOfBirth,
    stickerCount: stickerCount ?? source.stickerCount,
    stickersRequired: stickersRequired ?? source.stickersRequired,
    nextRank: nextRank ?? source.nextRank,
    guardianUserIds: source.guardianUserIds,
    guardianEmail: guardianEmail ?? source.guardianEmail,
    linkedUserId: source.linkedUserId,
    preferredClassGroupIds:
        preferredClassGroupIds ?? source.preferredClassGroupIds,
    promotionHistory: source.promotionHistory,
    testingNotes: source.testingNotes,
    isActive: isActive ?? source.isActive,
    createdAt: source.createdAt,
    updatedAt: DateTime.now().toUtc(),
  );
}
