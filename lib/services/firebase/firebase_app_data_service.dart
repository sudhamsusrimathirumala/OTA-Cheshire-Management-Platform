import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _fallbackService = fallbackService ?? const MockAppDataService() {
    _listenToSchedule();
  }

  final FirebaseFirestore _firestore;
  final AppDataService _fallbackService;
  Map<int, List<ClassSession>> _schedule = const <int, List<ClassSession>>{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _scheduleSubscription;
  bool _isScheduleLoading = true;
  String? _scheduleErrorMessage;

  void _listenToSchedule() {
    _scheduleSubscription = _firestore
        .collection(FirestoreCollections.classSessions)
        .orderBy('weekday')
        .orderBy('startMinutes')
        .snapshots()
        .listen(_handleScheduleSnapshot, onError: _handleScheduleError);
  }

  void _handleScheduleSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _schedule = _scheduleFromSnapshot(snapshot);
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

  @override
  void dispose() {
    unawaited(_scheduleSubscription?.cancel());
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
  List<ClassSession> scheduleForWeekday(int weekday) {
    return _schedule[weekday] ?? const <ClassSession>[];
  }

  @override
  ClassSession? nextClassForDashboard() {
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

  // TODO: Replace mock delegation with Firestore-backed announcements.
  // TODO: Add Firestore-backed events and resources when those features are
  // wired into AppDataService.
  @override
  List<NotificationItem> get notifications => _fallbackService.notifications;

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
