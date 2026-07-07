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
    required this.showInResources,
    required this.createdAt,
    required this.updatedAt,
    this.registrationUrl,
    this.registrationDeadline,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String description;
  final String locationId;
  final String eventType;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? registrationUrl;
  final DateTime? registrationDeadline;
  final bool isPublished;
  final bool showInResources;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  bool get isRegistrationOpen {
    if (registrationUrl == null) {
      return false;
    }

    return registrationDeadline == null ||
        registrationDeadline!.isAfter(DateTime.now());
  }

  String get dateRangeLabel => _formatDateTime(startDateTime);

  String get registrationLabel {
    if (registrationUrl == null) {
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
      'closure' => 'Closure',
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
