enum NotificationCategory {
  general,
  tournament,
  scheduleChange,
  beltTesting,
  summerCamp,
  holiday,
  reminder,
  curriculum,
}

enum NotificationPriority { general, important, critical }

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.locationId,
    required this.title,
    required this.summary,
    required this.body,
    required this.timestamp,
    required this.isRead,
    required this.category,
    this.priority = NotificationPriority.general,
    this.requiresAction = false,
  });

  final String id;
  final String locationId;
  final String title;
  final String summary;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final NotificationCategory category;
  final NotificationPriority priority;
  final bool requiresAction;

  bool get isImportant =>
      priority == NotificationPriority.important ||
      priority == NotificationPriority.critical;
}
