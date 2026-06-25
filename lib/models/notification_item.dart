class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
}
