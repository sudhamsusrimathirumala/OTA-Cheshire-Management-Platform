import 'package:flutter/material.dart';

import '../models/notification_item.dart';

extension NotificationPriorityVisuals on NotificationPriority {
  String get label {
    return switch (this) {
      NotificationPriority.general => 'General',
      NotificationPriority.important => 'Important',
      NotificationPriority.critical => 'Important',
    };
  }
}

extension NotificationCategoryVisuals on NotificationCategory {
  IconData get icon {
    return switch (this) {
      NotificationCategory.general => Icons.campaign_rounded,
      NotificationCategory.tournament => Icons.emoji_events_rounded,
      NotificationCategory.scheduleChange => Icons.event_repeat_rounded,
      NotificationCategory.beltTesting => Icons.workspace_premium_rounded,
      NotificationCategory.summerCamp => Icons.wb_sunny_rounded,
      NotificationCategory.holiday => Icons.event_busy_rounded,
      NotificationCategory.reminder => Icons.alarm_rounded,
      NotificationCategory.curriculum => Icons.menu_book_rounded,
    };
  }

  String get label {
    return switch (this) {
      NotificationCategory.general => 'General',
      NotificationCategory.tournament => 'Tournament',
      NotificationCategory.scheduleChange => 'Schedule',
      NotificationCategory.beltTesting => 'Belt Testing',
      NotificationCategory.summerCamp => 'Summer Camp',
      NotificationCategory.holiday => 'Holiday',
      NotificationCategory.reminder => 'Reminder',
      NotificationCategory.curriculum => 'Curriculum',
    };
  }
}

extension NotificationDateLabel on DateTime {
  String get displayLabel {
    final hour = this.hour % 12 == 0 ? 12 : this.hour % 12;
    final minute = this.minute.toString().padLeft(2, '0');
    final period = this.hour >= 12 ? 'PM' : 'AM';

    return '${_monthNames[month - 1]} $day • $hour:$minute $period';
  }
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
