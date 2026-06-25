import 'package:flutter/material.dart';

import '../../models/notification_item.dart';
import '../../theme/ota_colors.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({required this.notification, this.onTap, super.key});

  final NotificationItem notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isUnread ? OtaColors.softRed : OtaColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: notification.isImportant
                  ? OtaColors.actionRed.withValues(alpha: 0.28)
                  : OtaColors.navy.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: OtaColors.navy.withValues(alpha: isUnread ? 0.11 : 0.07),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: notification.isImportant
                          ? OtaColors.maroon
                          : OtaColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      notification.category.icon,
                      color: OtaColors.white,
                      size: 25,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: OtaColors.actionRed,
                          shape: BoxShape.circle,
                          border: Border.all(color: OtaColors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _CategoryPill(label: notification.category.label),
                        _CategoryPill(
                          label: notification.priority.label,
                          isImportant: notification.isImportant,
                        ),
                        if (notification.requiresAction)
                          const _CategoryPill(label: 'Action Needed'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isUnread
                            ? OtaColors.ink
                            : OtaColors.ink.withValues(alpha: 0.72),
                        fontWeight: isUnread
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: OtaColors.mutedText.withValues(alpha: 0.86),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            notification.timestamp.displayLabel,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: OtaColors.mutedText,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Text(
                          isUnread ? 'Unread' : 'Read',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: isUnread
                                    ? OtaColors.maroon
                                    : OtaColors.mutedText,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension NotificationPriorityVisuals on NotificationPriority {
  String get label {
    return switch (this) {
      NotificationPriority.general => 'General',
      NotificationPriority.important => 'Important',
      NotificationPriority.critical => 'Critical',
    };
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, this.isImportant = false});

  final String label;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isImportant ? OtaColors.actionRed : OtaColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isImportant
              ? OtaColors.actionRed
              : OtaColors.navy.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isImportant ? OtaColors.white : OtaColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
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
