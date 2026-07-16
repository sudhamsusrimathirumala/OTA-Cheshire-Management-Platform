import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/notifications/notification_card.dart';
import '../widgets/ota_bottom_nav_bar.dart';
import 'notification_detail_screen.dart';

enum _NotificationFilter { all, unread, important }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;
  bool _markingAll = false;

  List<NotificationItem> get _filteredNotifications {
    return switch (_selectedFilter) {
      _NotificationFilter.all => appDataService.notifications,
      _NotificationFilter.unread =>
        appDataService.notifications
            .where((notification) => !notification.isRead)
            .toList(),
      _NotificationFilter.important =>
        appDataService.notifications
            .where((notification) => notification.isImportant)
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final notifications = _filteredNotifications;
        final announcementsErrorMessage =
            appDataService.announcementsErrorMessage;

        return Scaffold(
          backgroundColor: OtaColors.blush,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NotificationsHeader(
                              unreadCount: appDataService.notifications
                                  .where((notification) => !notification.isRead)
                                  .length,
                              isMarkingAll: _markingAll,
                              onMarkAll: _markAllRead,
                            ),
                            const SizedBox(height: 16),
                            _NotificationFilters(
                              selectedFilter: _selectedFilter,
                              onSelected: (filter) {
                                setState(() => _selectedFilter = filter);
                              },
                            ),
                            const SizedBox(height: 16),
                            if (appDataService.isAnnouncementsLoading)
                              const _NotificationsStatusState(
                                icon: Icons.sync_rounded,
                                title: 'Loading announcements',
                                detail: 'Checking the latest OTA updates.',
                                showProgress: true,
                              )
                            else if (announcementsErrorMessage != null)
                              _NotificationsStatusState(
                                icon: Icons.cloud_off_rounded,
                                title: 'Announcements unavailable',
                                detail: announcementsErrorMessage,
                              )
                            else if (notifications.isEmpty)
                              const _NotificationsEmptyState()
                            else
                              for (final notification in notifications) ...[
                                NotificationCard(
                                  notification: notification,
                                  onTap: () => _openNotification(notification),
                                ),
                                if (notification != notifications.last)
                                  const SizedBox(height: 12),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const OtaBottomNavBar(
            selectedDestination: OtaBottomNavDestination.notifications,
          ),
        );
      },
    );
  }

  Future<void> _openNotification(NotificationItem notification) async {
    if (!notification.isRead) {
      try {
        await appDataService.markNotificationRead(notification.id);
      } catch (_) {
        if (mounted) _showReadError();
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await appDataService.markAllNotificationsRead();
    } catch (_) {
      if (mounted) _showReadError();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _showReadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to update notification read state. Try again.'),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.isMarkingAll,
    required this.onMarkAll,
  });

  final int unreadCount;
  final bool isMarkingAll;
  final VoidCallback onMarkAll;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: OtaColors.softRed,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: OtaColors.maroon,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stay up to date with academy news and announcements.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$unreadCount unread announcements',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: OtaColors.maroon,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: unreadCount == 0 || isMarkingAll ? null : onMarkAll,
            tooltip: 'Mark all read',
            icon: isMarkingAll
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
            style: IconButton.styleFrom(
              backgroundColor: OtaColors.softRed,
              foregroundColor: OtaColors.maroon,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
    required this.selectedFilter,
    required this.onSelected,
  });

  final _NotificationFilter selectedFilter;
  final ValueChanged<_NotificationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChipButton(
          label: 'All',
          selected: selectedFilter == _NotificationFilter.all,
          onSelected: () => onSelected(_NotificationFilter.all),
        ),
        _FilterChipButton(
          label: 'Unread',
          selected: selectedFilter == _NotificationFilter.unread,
          onSelected: () => onSelected(_NotificationFilter.unread),
        ),
        _FilterChipButton(
          label: 'Important',
          selected: selectedFilter == _NotificationFilter.important,
          onSelected: () => onSelected(_NotificationFilter.important),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: OtaColors.maroon,
      backgroundColor: OtaColors.white,
      side: BorderSide(
        color: selected
            ? OtaColors.maroon
            : OtaColors.navy.withValues(alpha: 0.08),
      ),
      labelStyle: TextStyle(
        color: selected ? OtaColors.white : OtaColors.ink,
        fontWeight: FontWeight.w900,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: OtaColors.softRed,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: OtaColors.maroon,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No notifications.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsStatusState extends StatelessWidget {
  const _NotificationsStatusState({
    required this.icon,
    required this.title,
    required this.detail,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress)
            const CircularProgressIndicator()
          else
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: OtaColors.softRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: OtaColors.maroon, size: 34),
            ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: OtaColors.mutedText),
          ),
        ],
      ),
    );
  }
}
