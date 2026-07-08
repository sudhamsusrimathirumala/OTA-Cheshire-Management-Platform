import 'notification_item.dart';

class AcademyAnnouncement {
  const AcademyAnnouncement({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.announcementType,
    required this.priority,
    required this.status,
    required this.audienceType,
    required this.locationId,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.requiresAction = false,
    this.targetBelts = const <String>[],
    this.targetClassTypeIds = const <String>[],
    this.targetStudentProfileIds = const <String>[],
    this.targetUserIds = const <String>[],
  });

  final String id;
  final String title;
  final String summary;
  final String body;
  final String announcementType;
  final String priority;
  final String status;
  final String audienceType;
  final String locationId;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool requiresAction;
  final List<String> targetBelts;
  final List<String> targetClassTypeIds;
  final List<String> targetStudentProfileIds;
  final List<String> targetUserIds;

  bool get isPublished => status == 'published';

  bool get isDraft => status == 'draft';

  bool get isArchived => status == 'archived';

  DateTime get displayDate => publishedAt ?? updatedAt;

  NotificationCategory get category {
    return switch (announcementType) {
      'tournament' => NotificationCategory.tournament,
      'scheduleChange' || 'schedule' => NotificationCategory.scheduleChange,
      'beltTesting' || 'testing' => NotificationCategory.beltTesting,
      'summerCamp' || 'camp' => NotificationCategory.summerCamp,
      'holiday' || 'closure' => NotificationCategory.holiday,
      'reminder' => NotificationCategory.reminder,
      'curriculum' => NotificationCategory.curriculum,
      _ => NotificationCategory.general,
    };
  }

  NotificationPriority get notificationPriority {
    return switch (priority) {
      'important' => NotificationPriority.important,
      'critical' => NotificationPriority.critical,
      _ => NotificationPriority.general,
    };
  }
}
