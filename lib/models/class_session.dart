import 'student_profile.dart';

class ClassSession {
  ClassSession({
    required this.id,
    required this.className,
    required this.classTypeId,
    String? bulkGroupId,
    required this.locationId,
    required this.startTime,
    required this.endTime,
    int? startMinutes,
    int? endMinutes,
    required this.eligibleBelts,
    required this.description,
    this.eligibilityNote,
    this.isPreferred = false,
    this.isPublished = true,
    this.resumesOn,
    this.createdAt,
    this.updatedAt,
  }) : bulkGroupId = resolvedPreferredClassGroupId(className, bulkGroupId),
       startMinutes = startMinutes ?? startTime.hour * 60 + startTime.minute,
       endMinutes = endMinutes ?? endTime.hour * 60 + endTime.minute;

  final String id;
  final String className;
  // Used for future bulk actions, such as editing or deleting all sessions of
  // the same class type while keeping each scheduled occurrence separate.
  final String classTypeId;
  final String bulkGroupId;
  final String locationId;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> eligibleBelts;
  final String description;
  final String? eligibilityNote;
  final bool isPreferred;
  final bool isPublished;
  final DateTime? resumesOn;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final int startMinutes;

  final int endMinutes;

  int get durationMinutes => endMinutes - startMinutes;

  String get startLabel => formatMinutesAsTime(startMinutes);

  String get timeRangeLabel =>
      '$startLabel - ${formatMinutesAsTime(endMinutes)}';

  String get eligibilityLabel =>
      eligibilityNote ??
      (eligibleBelts.isEmpty
          ? 'Instructor placement required'
          : eligibleBelts.join(', '));

  DateTime startDateTime(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
  }

  DateTime endDateTime(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
  }

  bool isEligibleFor(StudentProfile student) {
    if (classTypeId == 'teen-adult-sparring') {
      return student.age >= 13;
    }
    return eligibleBelts.contains(student.belt);
  }
}

const legacyAmbiguousTeenAdultGroupId = 'teen-adult-standard';

String preferredClassGroupIdForClassName(String className) {
  final normalized = className.trim();
  return switch (normalized) {
    'Little Tiger' || 'Little Tiger (Age 3-5)' => 'little-tiger-standard',
    'Level 1' => 'level-1-standard',
    'Level 2' => 'level-2-standard',
    'Level 3' => 'level-3-standard',
    'Level 4' => 'level-4-standard',
    'Black Belt' => 'black-belt-standard',
    'Teen & Black Belt' => 'teen-black-belt-standard',
    'Adult' => 'adult-standard',
    'Teen/Adult Sparring' => 'teen-adult-sparring-standard',
    'Level 1 / Level 2 Sparring' => 'level-1-2-sparring-standard',
    _ => '${_preferredClassSlug(normalized)}-standard',
  };
}

String resolvedPreferredClassGroupId(String className, String? storedGroupId) {
  final stored = storedGroupId?.trim() ?? '';
  if (stored.isEmpty || stored == legacyAmbiguousTeenAdultGroupId) {
    return preferredClassGroupIdForClassName(className);
  }
  return stored;
}

bool matchesResolvedPreferredClassGroup(
  Iterable<String> savedGroupIds,
  String classGroupId,
) {
  return savedGroupIds.any(
    (groupId) =>
        groupId != legacyAmbiguousTeenAdultGroupId && groupId == classGroupId,
  );
}

List<String> resolvedSavedPreferredClassGroupIds(Iterable<String> groupIds) {
  return groupIds
      .where(
        (groupId) =>
            groupId.trim().isNotEmpty &&
            groupId != legacyAmbiguousTeenAdultGroupId,
      )
      .toList(growable: false);
}

String _preferredClassSlug(String className) {
  final slug = className
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'class-session' : slug;
}

String formatMinutesAsTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}
