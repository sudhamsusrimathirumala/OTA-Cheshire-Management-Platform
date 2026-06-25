import '../models/notification_item.dart';

final sampleNotifications = [
  NotificationItem(
    id: 'summer_camp_registration',
    title: 'Summer Camp Registration Open',
    body: 'Reserve your spot for OTA summer camp before spaces fill up.',
    timestamp: DateTime(2026, 6, 20, 9),
    isRead: false,
  ),
  NotificationItem(
    id: 'tournament_registration',
    title: 'Tournament Registration Due Friday',
    body: 'Please submit tournament registration forms by Friday evening.',
    timestamp: DateTime(2026, 6, 19, 14, 30),
    isRead: false,
  ),
  NotificationItem(
    id: 'wednesday_schedule_change',
    title: 'Schedule Change for Wednesday',
    body: 'Wednesday evening classes will follow the adjusted summer schedule.',
    timestamp: DateTime(2026, 6, 18, 16),
    isRead: false,
  ),
];
