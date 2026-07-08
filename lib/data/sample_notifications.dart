import '../models/notification_item.dart';
import 'sample_constants.dart';

final sampleNotifications = [
  NotificationItem(
    id: 'summer_camp_registration',
    locationId: otaCheshireLocationId,
    title: 'Summer Camp Registration Now Open',
    summary: 'Reserve your spot before summer camp spaces fill up.',
    body:
        'Summer Camp registration is now open for OTA families. Camp sessions will include technique development, games, confidence-building activities, and extra curriculum practice. Please reserve your student’s spot early so we can plan staffing and class groups.',
    timestamp: DateTime(2026, 6, 24, 9),
    isRead: false,
    category: NotificationCategory.summerCamp,
    priority: NotificationPriority.important,
    requiresAction: true,
  ),
  NotificationItem(
    id: 'tournament_registration',
    locationId: otaCheshireLocationId,
    title: 'Tournament Registration Closes Friday',
    summary: 'Submit tournament registration forms by Friday evening.',
    body:
        'Tournament registration closes this Friday. Students planning to compete should submit forms and payment by the deadline. Please speak with an instructor if you are unsure which events are appropriate for your student.',
    timestamp: DateTime(2026, 6, 23, 14, 30),
    isRead: false,
    category: NotificationCategory.tournament,
    priority: NotificationPriority.important,
    requiresAction: true,
  ),
  NotificationItem(
    id: 'wednesday_schedule_change',
    locationId: otaCheshireLocationId,
    title: 'Wednesday Schedule Updated',
    summary:
        'Wednesday evening classes will follow the adjusted summer schedule.',
    body:
        'Please note that Wednesday evening classes will follow the adjusted summer schedule. Families should check the Schedule tab before arriving so students attend the correct class time.',
    timestamp: DateTime(2026, 6, 22, 16),
    isRead: false,
    category: NotificationCategory.scheduleChange,
    priority: NotificationPriority.important,
  ),
  NotificationItem(
    id: 'belt_testing_reminder',
    locationId: otaCheshireLocationId,
    title: 'Reminder: Belt Testing This Saturday',
    summary:
        'Eligible students should arrive 15 minutes early in full uniform.',
    body:
        'Belt testing is scheduled for this Saturday. Eligible students should arrive 15 minutes early in full uniform with belts tied properly. Please bring water and make sure students have practiced their required curriculum.',
    timestamp: DateTime(2026, 6, 21, 18, 15),
    isRead: false,
    category: NotificationCategory.beltTesting,
    priority: NotificationPriority.important,
    requiresAction: true,
  ),
  NotificationItem(
    id: 'independence_day_closure',
    locationId: otaCheshireLocationId,
    title: 'Academy Closed for Independence Day',
    summary: 'OTA will be closed July 4 for Independence Day.',
    body:
        'OTA will be closed July 4. Regular classes resume the following week.',
    timestamp: DateTime(2026, 6, 20, 11, 45),
    isRead: true,
    category: NotificationCategory.holiday,
  ),
  NotificationItem(
    id: 'curriculum_videos_available',
    locationId: otaCheshireLocationId,
    title: 'New Curriculum Videos Available',
    summary: 'New practice video placeholders are ready in Curriculum.',
    body:
        'New practice video placeholders are ready in the curriculum section. These placeholders will later connect students to instructional material for forms, sparring, and testing preparation.',
    timestamp: DateTime(2026, 6, 19, 13),
    isRead: true,
    category: NotificationCategory.curriculum,
  ),
  NotificationItem(
    id: 'recent_belt_promotions',
    locationId: otaCheshireLocationId,
    title: 'Congratulations to Recent Belt Promotions',
    summary: 'Celebrate the students who advanced at the latest OTA testing.',
    body:
        'Congratulations to all students who advanced at the latest OTA testing. Your hard work, consistency, and focus showed on the mat. Keep training and supporting your classmates.',
    timestamp: DateTime(2026, 6, 17, 19, 30),
    isRead: true,
    category: NotificationCategory.general,
  ),
  NotificationItem(
    id: 'parent_meeting',
    locationId: otaCheshireLocationId,
    title: 'Parent Meeting Next Thursday',
    summary: 'Join us for summer programming and event updates.',
    body:
        'Join us for updates on summer programming, events, and expectations.',
    timestamp: DateTime(2026, 6, 16, 17),
    isRead: false,
    category: NotificationCategory.reminder,
    requiresAction: true,
  ),
];
