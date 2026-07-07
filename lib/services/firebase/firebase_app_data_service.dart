import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../models/class_session.dart';
import '../../models/curriculum_requirement.dart';
import '../../models/notification_item.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../app_data_service.dart';
import '../firestore/firestore_collections.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _scheduleSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _announcementsSubscription;
  QuerySnapshot<Map<String, dynamic>>? _latestAnnouncementsSnapshot;
  bool _isScheduleLoading = true;
  String? _scheduleErrorMessage;
  bool _isAnnouncementsLoading = true;
  String? _announcementsErrorMessage;
  bool _isUsingFallbackData = false;

  void _listenToFirestore() {
    try {
      if (_firestore == null && Firebase.apps.isEmpty) {
        _useFallbackDataForUnavailableFirebase();
        return;
      }

      final firestore = _firestore ?? FirebaseFirestore.instance;
      _firestore = firestore;
      _listenToSchedule(firestore);
      _listenToAnnouncements(firestore);
    } catch (_) {
      _useFallbackDataForUnavailableFirebase();
    }
  }

  void _useFallbackDataForUnavailableFirebase() {
    _schedule = _fallbackService.schedule;
    _notifications = _fallbackService.notifications;
    _isUsingFallbackData = true;
    _isScheduleLoading = false;
    _isAnnouncementsLoading = false;
    _scheduleErrorMessage = null;
    _announcementsErrorMessage = null;
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
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .listen(
          _handleAnnouncementsSnapshot,
          onError: _handleAnnouncementsError,
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
    _notifications = _announcementsFromSnapshot(snapshot);
    _isUsingFallbackData = false;
    _isAnnouncementsLoading = false;
    _announcementsErrorMessage = null;
    notifyListeners();
  }

  void _handleAnnouncementsError(Object error) {
    _notifications = const <NotificationItem>[];
    _isAnnouncementsLoading = false;
    _announcementsErrorMessage = 'Unable to load announcements from Firestore.';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_scheduleSubscription?.cancel());
    unawaited(_announcementsSubscription?.cancel());
    super.dispose();
  }

  // TODO: Replace mock delegation with Firebase Auth and Firestore-backed users.
  @override
  UserAccount get currentUserAccount => _fallbackService.currentUserAccount;

  // TODO: Replace mock delegation with Firestore-backed student profiles.
  @override
  List<StudentProfile> get linkedStudentProfiles =>
      _fallbackService.linkedStudentProfiles;

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

  // TODO: Add Firestore-backed events and resources when those features are
  // wired into AppDataService.
  @override
  List<NotificationItem> get notifications => _notifications;

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
      locationId:
          _stringValue(data['locationId']) ?? selectedStudentProfile.locationId,
      startTime: startTime,
      endTime: endTime,
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
      'classType' => _selectedProfileClassTypeIds.any(
        targetClassTypeIds.contains,
      ),
      'students' =>
        targetStudentProfileIds.isEmpty
            ? currentUserAccount.role == UserAccountRole.student
            : targetStudentProfileIds.contains(selectedStudentProfile.id),
      'parents' => currentUserAccount.role == UserAccountRole.parent,
      'specificUsers' => targetUserIds.contains(currentUserAccount.id),
      'mixed' =>
        targetBelts.contains(selectedStudentProfile.belt) ||
            _selectedProfileClassTypeIds.any(targetClassTypeIds.contains) ||
            targetStudentProfileIds.contains(selectedStudentProfile.id) ||
            targetUserIds.contains(currentUserAccount.id),
      _ => false,
    };
  }

  Set<String> get _selectedProfileClassTypeIds {
    return {
      for (final sessions in _schedule.values)
        for (final session in sessions)
          if (session.isEligibleFor(selectedStudentProfile))
            session.classTypeId,
    };
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

String _classTypeIdFor(String className) {
  return switch (className) {
    'Little Tiger (Age 3-5)' => 'little-tiger',
    'Level 1' => 'level-1',
    'Level 2' => 'level-2',
    'Level 3' => 'level-3',
    'Level 4' => 'level-4',
    'Black Belt' => 'black-belt',
    'Teen & Black Belt' => 'teen-black-belt',
    'Adult' => 'adult',
    'Level 1 / Level 2 Sparring' || 'Teen/Adult Sparring' => 'sparring-class',
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
    'critical' => NotificationPriority.critical,
    _ => NotificationPriority.general,
  };
}
