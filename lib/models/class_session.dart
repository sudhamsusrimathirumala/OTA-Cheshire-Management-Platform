import 'student_profile.dart';

class ClassSession {
  ClassSession({
    required this.id,
    required this.className,
    required this.locationId,
    required this.startTime,
    required this.endTime,
    required this.eligibleBelts,
    required this.description,
    this.eligibilityNote,
    this.isPreferred = false,
  });

  final String id;
  final String className;
  final String locationId;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> eligibleBelts;
  final String description;
  final String? eligibilityNote;
  final bool isPreferred;

  int get startMinutes => startTime.hour * 60 + startTime.minute;

  int get endMinutes => endTime.hour * 60 + endTime.minute;

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  String get startLabel => _formatTimeOfDay(startTime);

  String get timeRangeLabel => '$startLabel - ${_formatTimeOfDay(endTime)}';

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
      startTime.hour,
      startTime.minute,
    );
  }

  DateTime endDateTime(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
  }

  bool isEligibleFor(StudentProfile student) {
    return eligibleBelts.contains(student.belt);
  }
}

String _formatTimeOfDay(DateTime time) {
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final displayHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final displayMinute = time.minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}
