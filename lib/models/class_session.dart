import 'student.dart';

class ClassSession {
  ClassSession({
    required this.id,
    required this.className,
    required this.startTime,
    required this.endTime,
    required this.eligibleBelts,
    required this.description,
    this.isPreferred = false,
  });

  final String id;
  final String className;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> eligibleBelts;
  final String description;
  final bool isPreferred;

  int get startMinutes => startTime.hour * 60 + startTime.minute;

  int get endMinutes => endTime.hour * 60 + endTime.minute;

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  String get startLabel => _formatTimeOfDay(startTime);

  String get timeRangeLabel => '$startLabel - ${_formatTimeOfDay(endTime)}';

  String get eligibilityLabel => eligibleBelts.join(', ');

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

  bool isEligibleFor(Student student) {
    return eligibleBelts.contains(student.belt);
  }
}

String _formatTimeOfDay(DateTime time) {
  final period = time.hour >= 12 ? 'PM' : 'AM';
  final displayHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final displayMinute = time.minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $period';
}
