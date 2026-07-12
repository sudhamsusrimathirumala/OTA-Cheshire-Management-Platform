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
  }) : bulkGroupId = bulkGroupId ?? '$classTypeId-standard',
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

String formatMinutesAsTime(int minutes) {
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}
