import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/app_data_service_provider.dart';
import '../services/firebase/notification_read_exception.dart';
import '../theme/ota_colors.dart';
import '../utils/notification_formatters.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({required this.notification, super.key});

  final NotificationItem notification;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final notification = appDataService.notifications
            .where((item) => item.id == widget.notification.id)
            .firstOrNull;
        final current = notification ?? widget.notification;
        return Scaffold(
          backgroundColor: OtaColors.blush,
          appBar: AppBar(
            backgroundColor: OtaColors.blush,
            foregroundColor: OtaColors.ink,
            elevation: 0,
            title: const Text('Notification Detail'),
          ),
          body: SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NotificationHeroCard(notification: current),
                            const SizedBox(height: 16),
                            _NotificationMessageCard(notification: current),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _updating
                                  ? null
                                  : () => _setReadState(current),
                              icon: Icon(
                                current.isRead
                                    ? Icons.mark_email_unread_rounded
                                    : Icons.mark_email_read_rounded,
                              ),
                              label: Text(
                                current.isRead
                                    ? 'Mark as unread'
                                    : 'Mark as read',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setReadState(NotificationItem notification) async {
    setState(() => _updating = true);
    try {
      if (notification.isRead) {
        await appDataService.markNotificationUnread(notification.id);
      } else {
        await appDataService.markNotificationRead(notification.id);
      }
    } on NotificationReadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update notification state.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}

class _NotificationHeroCard extends StatelessWidget {
  const _NotificationHeroCard({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: notification.isImportant
                      ? OtaColors.maroon
                      : OtaColors.navy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  notification.category.icon,
                  color: OtaColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailBadge(label: notification.category.label),
                        _DetailBadge(
                          label: notification.priority.label,
                          priority: notification.priority,
                        ),
                        if (notification.requiresAction)
                          const _DetailBadge(label: 'Action Needed'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: OtaColors.ink,
                            fontWeight: FontWeight.w900,
                            height: 1.14,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: OtaColors.mutedText,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                notification.timestamp.displayLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationMessageCard extends StatelessWidget {
  const _NotificationMessageCard({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notification.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w600,
              height: 1.48,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label, this.priority});

  final String label;
  final NotificationPriority? priority;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (priority) {
      NotificationPriority.critical => OtaColors.maroon,
      NotificationPriority.important => OtaColors.maroon,
      _ => OtaColors.softRed,
    };
    final foregroundColor =
        priority == null || priority == NotificationPriority.general
        ? OtaColors.ink
        : OtaColors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: OtaColors.navy.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
