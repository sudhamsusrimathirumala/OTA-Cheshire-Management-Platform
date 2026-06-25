import 'package:flutter/material.dart';

import '../../models/notification_item.dart';
import '../../theme/ota_colors.dart';
import '../../utils/notification_formatters.dart';

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
