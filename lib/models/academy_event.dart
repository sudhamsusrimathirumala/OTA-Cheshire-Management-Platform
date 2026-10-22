import 'event_schedule.dart';

class AcademyEvent {
  const AcademyEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.locationId,
    required this.eventType,
    required this.startDateTime,
    required this.endDateTime,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.registrationDeadline,
    this.isArchived = false,
    this.linkedResourceIds = const <String>[],
    this.primaryRegistrationResourceId,
    this.schedule,
    this.reminders = const EventReminders.disabled(),
    this.occurrenceId,
  });

  final String id;
  final String title;
  final String description;
  final String locationId;
  final String eventType;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final DateTime? registrationDeadline;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final List<String> linkedResourceIds;
  final String? primaryRegistrationResourceId;
  final EventSchedule? schedule;
  final EventReminders reminders;
  final String? occurrenceId;

  List<EventOccurrence> get occurrences =>
      schedule?.occurrences ??
      [EventOccurrence(id: 'once', start: startDateTime, end: endDateTime)];
  DateTime get lastOccurrenceEnd =>
      occurrences.map((o) => o.end).reduce((a, b) => a.isAfter(b) ? a : b);
  String get recurrenceLabel => schedule == null
      ? 'Does not repeat'
      : '${schedule!.rule.frequency[0].toUpperCase()}${schedule!.rule.frequency.substring(1)} • ${occurrences.length} sessions';

  AcademyEvent forOccurrence(EventOccurrence occurrence) => AcademyEvent(
    id: id,
    title: title,
    description: description,
    locationId: locationId,
    eventType: eventType,
    startDateTime: occurrence.start,
    endDateTime: occurrence.end,
    isPublished: isPublished,
    isArchived: isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt,
    registrationDeadline: registrationDeadline,
    linkedResourceIds: linkedResourceIds,
    primaryRegistrationResourceId: primaryRegistrationResourceId,
    schedule: schedule,
    reminders: reminders,
    occurrenceId: occurrence.id,
  );

  bool get isRegistrationOpen => registrationOpenAt(DateTime.now());

  bool registrationOpenAt(DateTime now) {
    final end = occurrenceId == null ? lastOccurrenceEnd : endDateTime;
    if (primaryRegistrationResourceId == null || !isPublished ||
        isArchived || !end.isAfter(now)) {
      return false;
    }

    return registrationDeadline == null ||
        registrationDeadline!.isAfter(now);
  }

  String get dateRangeLabel => _formatDateTime(startDateTime);

  String get registrationLabel {
    if (primaryRegistrationResourceId == null) {
      return 'No registration';
    }

    if (!isRegistrationOpen) {
      return 'Registration closed';
    }

    return 'Registration open';
  }

  String get statusLabel => isPublished ? 'Published' : 'Draft';

  String get eventTypeLabel {
    return switch (eventType) {
      'parentNightOut' || 'parent-night-out' => 'Parent Night Out',
      'tournament' => 'Tournament',
      'summerCamp' || 'summer-camp' => 'Summer Camp',
      'beltTesting' || 'belt-testing' => 'Belt Testing',
      'seminar' => 'Seminar',
      _ => 'Special Event',
    };
  }
}

String _formatDateTime(DateTime dateTime) {
  final month = _monthNames[dateTime.month - 1];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$month ${dateTime.day}, $hour:$minute $period';
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
