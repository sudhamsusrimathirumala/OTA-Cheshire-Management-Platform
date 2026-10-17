import 'package:flutter/material.dart' show TimeOfDay;
import '../models/class_session.dart';
import '../models/student_profile.dart';
import 'location_time_service.dart';

const int otaTeenStartAge = 12;
const int otaAdultOnlyAge = 19;

bool isNumberedLevelClass(ClassSession session) =>
    RegExp(r'^level-[1-4](?:-|$)').hasMatch(session.classTypeId) ||
    RegExp(r'^Level [1-4](?:\s|$)').hasMatch(session.className);

// Accept existing schedule labels with an optional "Class" suffix.
// Match specific names rather than all 'teen-adult' types, since the separate
// Black Belt and sparring sessions must never enter the age-only group.
String _normalizedRecommendationClassName(String name) {
  final normalized = name.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), ' ');
  return normalized.endsWith(' class')
      ? normalized.substring(0, normalized.length - ' class'.length)
      : normalized;
}

bool isTeenClass(ClassSession session) {
  final name = _normalizedRecommendationClassName(session.className);
  return name == 'teen' ||
      name == 'teen & black belt' ||
      name == 'teen and black belt';
}

bool isAdultClass(ClassSession session) =>
    _normalizedRecommendationClassName(session.className) == 'adult';

bool isTypicallyRecommendedFor(ClassSession session, StudentProfile student) {
  if (!session.isPublished || session.locationId != student.locationId) {
    return false;
  }
  final age = const LocationTimeService().ageForStudent(student);
  if (isLittleTigersAge(age)) return isLittleTigersClass(session);
  if (age >= otaAdultOnlyAge) return isAdultClass(session);
  if (age >= otaTeenStartAge) {
    return isTeenClass(session) || isAdultClass(session);
  }
  if (age < 6) return false;
  return (isNumberedLevelClass(session) ||
          session.className.trim() == 'Black Belt') &&
      acceptsStudentBelt(session, student);
}

// Normalize spelling only; unknown ranks do not become beginner ranks.
String _beltKey(String belt) => belt
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-/]+'), '-')
    .replaceAll(RegExp(r'-belt$'), '');

bool acceptsStudentBelt(ClassSession session, StudentProfile student) =>
    session.eligibleBelts.isNotEmpty &&
    session.eligibleBelts.any(
      (belt) => _beltKey(belt) == _beltKey(student.beltRank),
    );

String classGuidanceFor(ClassSession session, StudentProfile student) {
  final age = const LocationTimeService().ageForStudent(student);
  if (isLittleTigersClass(session)) {
    return 'Recommended for children ages 3-5, regardless of belt rank.';
  }
  if (isAdultClass(session)) {
    return 'Recommended for students ages 12 and older, regardless of belt rank.';
  }
  if (isTeenClass(session)) {
    return 'Recommended for ages 12-18, regardless of belt rank.';
  }
  if (session.className.trim() == 'Black Belt') {
    return 'Belt-based recommendation for younger Black Belt students. '
        'Older students are directed to teen or adult classes.';
  }
  if (isNumberedLevelClass(session)) {
    final level = RegExp(r'Level [1-4]').firstMatch(session.className)?.group(0);
    if (age >= otaTeenStartAge) {
      return 'Students ages 12 and older are generally recommended a teen '
          'or adult class. Check with an instructor for alternate placement.';
    }
    return level == null
        ? "For ages 6-11 when the student's belt matches this class."
        : '$level is recommended for ages 6-11 when the belt matches. '
          'Ask an instructor about alternative placement.';
  }
  return session.eligibilityNote?.trim().isNotEmpty == true
      ? session.eligibilityNote!.trim()
      : 'Ask an instructor if you are unsure which class is the best fit.';
}

ClassSession? nextRecommendedClassFromSchedule(
  Map<int, List<ClassSession>> schedule,
  StudentProfile student, {
  required int currentWeekday,
  required int currentMinutes,
  DateTime? currentDate,
}) {
  final candidates = <ClassSession>[];
  final academyDate =
      currentDate ??
      const LocationTimeService().toLocationTime(
        DateTime.now(),
        student.locationId,
      );
  // Include the same weekday next week when every class today has started.
  for (var offset = 0; offset <= DateTime.daysPerWeek; offset++) {
    final weekday = ((currentWeekday + offset - 1) % DateTime.daysPerWeek) + 1;
    final sessions = [...schedule[weekday] ?? const <ClassSession>[]]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    for (final session in sessions) {
      if (!session.isPublished ||
          session.locationId != student.locationId ||
          (session.resumesOn != null &&
              session.resumesOn!.isAfter(
                const LocationTimeService().combineDateAndTime(
                  locationId: student.locationId,
                  date: DateTime(
                    academyDate.year,
                    academyDate.month,
                    academyDate.day + offset,
                  ),
                  time: TimeOfDay(
                    hour: session.startMinutes ~/ 60,
                    minute: session.startMinutes % 60,
                  ),
                ),
              )) ||
          (offset == 0 && session.startMinutes < currentMinutes)) {
        continue;
      }
      candidates.add(session);
    }
  }
  if (candidates.isEmpty) return null;
  final age = const LocationTimeService().ageForStudent(student);

  // Candidates already follow the upcoming weekly schedule chronologically.
  // Ages 3-5: Little Tigers. Ages 12-18: whichever Teen & Black Belt or Adult
  // class starts next. Ages 19+: Adult only. No belt restriction for those
  // age groups; younger ages 6-11 require explicit belt eligibility.
  final eligible = candidates
      .where((session) => isTypicallyRecommendedFor(session, student))
      .toList(growable: false);
  if (eligible.isEmpty) return null;

  // Preserve manually saved preferences ONLY within the belt-eligible
  // 6-11 group. All age-only groups must always show the earliest session.
  if (age >= 6 && age < otaTeenStartAge &&
      student.preferredClassGroupIds.isNotEmpty) {
    for (final session in eligible) {
      if (matchesResolvedPreferredClassGroup(
        student.preferredClassGroupIds,
        session.bulkGroupId,
      )) {
        return session;
      }
    }
  }

  return eligible.first;
}
