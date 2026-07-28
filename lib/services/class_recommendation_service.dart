import '../models/class_session.dart';
import '../models/student_profile.dart';

const int otaOlderStudentAge = 13;

bool isNumberedLevelClass(ClassSession session) =>
    RegExp(r'^level-[1-4](?:-|$)').hasMatch(session.classTypeId) ||
    RegExp(r'^Level [1-4](?:\s|$)').hasMatch(session.className);

bool isTeenOrAdultClass(ClassSession session) {
  final value = '${session.classTypeId} ${session.className}'.toLowerCase();
  return value.contains('teen') || value.contains('adult');
}

bool isTypicallyRecommendedFor(ClassSession session, StudentProfile student) {
  if (student.age >= otaOlderStudentAge) return isTeenOrAdultClass(session);
  return isNumberedLevelClass(session) &&
      (session.eligibleBelts.isEmpty ||
          session.eligibleBelts.contains(student.belt));
}

String classGuidanceFor(ClassSession session, StudentProfile student) {
  if (isTeenOrAdultClass(session)) {
    if (student.age < otaOlderStudentAge) {
      return 'This class is usually attended by teens and adults. Check with an instructor if you are unsure whether it is the best fit.';
    }
    return 'Usually attended by teens and adults.';
  }
  if (isNumberedLevelClass(session)) {
    final level = RegExp(
      r'Level [1-4]',
    ).firstMatch(session.className)?.group(0);
    if (student.age >= otaOlderStudentAge) {
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
}) {
  final candidates = <ClassSession>[];
  for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
    final weekday = ((currentWeekday + offset - 1) % DateTime.daysPerWeek) + 1;
    final sessions = [...schedule[weekday] ?? const <ClassSession>[]]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    for (final session in sessions) {
      if (!session.isPublished ||
          session.locationId != student.locationId ||
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

  if (student.age >= otaOlderStudentAge) {
    for (final session in candidates) {
      if (isTeenOrAdultClass(session)) return session;
    }
    for (final session in candidates) {
      if (isNumberedLevelClass(session)) return session;
    }
  } else {
    for (final session in candidates) {
      if (isNumberedLevelClass(session) &&
          session.eligibleBelts.contains(student.belt)) {
        return session;
      }
    }
    for (final session in candidates) {
      if (isNumberedLevelClass(session)) return session;
    }
  }
  return candidates.first;
}
