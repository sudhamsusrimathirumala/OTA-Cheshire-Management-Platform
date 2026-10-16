import 'package:flutter/material.dart' show TimeOfDay;
import '../models/class_session.dart';
import '../models/student_profile.dart';
import 'location_time_service.dart';

const int otaOlderStudentAge = 13;

bool isNumberedLevelClass(ClassSession session) =>
    RegExp(r'^level-[1-4](?:-|$)').hasMatch(session.classTypeId) ||
    RegExp(r'^Level [1-4](?:\s|$)').hasMatch(session.className);

bool isTeenOrAdultClass(ClassSession session) {
  final value = '${session.classTypeId} ${session.className}'.toLowerCase();
  return value.contains('teen') || value.contains('adult');
}

bool isTypicallyRecommendedFor(ClassSession session, StudentProfile student) {
  if (!session.isPublished ||
      session.locationId != student.locationId ||
      !acceptsStudentBelt(session, student)) {
    return false;
  }
  final age = const LocationTimeService().ageForStudent(student);
  return age >= otaOlderStudentAge
      ? isTeenOrAdultClass(session)
      : isNumberedLevelClass(session) || session.className == 'Black Belt';
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
  if (session.className == 'Black Belt' &&
      age < otaOlderStudentAge &&
      acceptsStudentBelt(session, student)) {
    return 'Black Belt training matches this student\'s rank. Check with an '
        'instructor if you are unsure about their age group.';
  }
  if (isTeenOrAdultClass(session)) {
    if (age < otaOlderStudentAge) {
      return 'This class is usually attended by teens and adults. Check with an instructor if you are unsure whether it is the best fit.';
    }
    return 'Usually attended by teens and adults.';
  }
  if (isNumberedLevelClass(session)) {
    final level = RegExp(
      r'Level [1-4]',
    ).firstMatch(session.className)?.group(0);
    if (age >= otaOlderStudentAge) {
      return 'Older students may still choose this class when it better fits their comfort or schedule.';
    }
    return level == null
        ? 'Typically attended by younger students.'
        : 'Younger students in $level. Students may choose another class when it better fits their comfort or schedule.';
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
  for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
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
          (offset == 0 && session.endMinutes <= currentMinutes)) {
        continue;
      }
      candidates.add(session);
    }
  }
  if (candidates.isEmpty) return null;

  final preferred = student.preferredClassGroupIds.firstOrNull;
  if (preferred != null) {
    for (final session in candidates) {
      if (matchesResolvedPreferredClassGroup(
        student.preferredClassGroupIds,
        session.bulkGroupId,
      )) {
        return session;
      }
    }
  }

  if (const LocationTimeService().ageForStudent(student) >= otaOlderStudentAge) {
    for (final session in candidates) {
      if (isTeenOrAdultClass(session) &&
          acceptsStudentBelt(session, student)) {
        return session;
      }
    }
    for (final session in candidates) {
      if (isNumberedLevelClass(session) &&
          acceptsStudentBelt(session, student)) {
        return session;
      }
    }
  } else {
    for (final session in candidates) {
      if (isNumberedLevelClass(session) &&
          acceptsStudentBelt(session, student)) {
        return session;
      }
    }
    // Black Belt is not a numbered class, but it can still be appropriate
    // for a younger black belt whose rank is explicitly listed.
    for (final session in candidates) {
      if (session.className == 'Black Belt' &&
          acceptsStudentBelt(session, student)) {
        return session;
      }
    }
    // Do not recommend a different numbered level, a teen/adult class, or an
    // unconfigured class just because no appropriate class was found.
    return null;
  }
  // Empty eligibleBelts means instructor placement, not blanket permission.
  // Older students may also be eligible for non-numbered classes.
  return candidates
      .where((session) => acceptsStudentBelt(session, student))
      .firstOrNull;
}
