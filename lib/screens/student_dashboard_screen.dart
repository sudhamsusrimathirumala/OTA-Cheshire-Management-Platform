import 'package:flutter/material.dart';

import '../models/class_session.dart';
import '../models/notification_item.dart';
import '../models/student_profile.dart';
import '../routes.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final student = appDataService.selectedStudentProfile;
        final notifications = appDataService.notifications;
        final nextClass = appDataService.nextClassForDashboard();
        final nextClassWeekday = nextClass == null
            ? null
            : appDataService.schedule.entries
                  .where(
                    (entry) => entry.value.any(
                      (session) => session.id == nextClass.id,
                    ),
                  )
                  .map((entry) => entry.key)
                  .firstOrNull;

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
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DashboardHeader(student: student),
                            const SizedBox(height: 22),
                            _NextClassCard(
                              nextClass: nextClass,
                              weekday: nextClassWeekday,
                            ),
                            const SizedBox(height: 16),
                            _BeltProgressCard(student: student),
                            const SizedBox(height: 16),
                            Text(
                              'Quick Actions',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: OtaColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const _QuickActionsGrid(),
                            const SizedBox(height: 24),
                            _NotificationsCard(
                              notifications: notifications,
                              isLoading: appDataService.isAnnouncementsLoading,
                              errorMessage:
                                  appDataService.announcementsErrorMessage,
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
          bottomNavigationBar: const OtaBottomNavBar(
            selectedDestination: OtaBottomNavDestination.dashboard,
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good Evening, ${student.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${student.belt} Student',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: OtaColors.navy,
            shape: BoxShape.circle,
            border: Border.all(color: OtaColors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: OtaColors.navy.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            student.initials,
            style: TextStyle(
              color: OtaColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.nextClass, required this.weekday});

  final ClassSession? nextClass;
  final int? weekday;

  @override
  Widget build(BuildContext context) {
    final weekdayLabel = nextClass == null
        ? 'No upcoming class'
        : _weekdayLabel(weekday ?? DateTime.now().weekday);
    final timeLabel = nextClass?.timeRangeLabel ?? '--';

    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [OtaColors.maroon, OtaColors.actionRed],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -18,
              child: Icon(
                Icons.sports_martial_arts_rounded,
                size: 142,
                color: OtaColors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _IconBadge(
                        icon: Icons.schedule_rounded,
                        backgroundColor: OtaColors.white,
                        iconColor: OtaColors.maroon,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'NEXT CLASS',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: OtaColors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    nextClass == null
                        ? 'No Class Scheduled'
                        : '${nextClass!.className} Class',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: OtaColors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          weekdayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: OtaColors.white.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: OtaColors.white.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            timeLabel,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: OtaColors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nextClass?.eligibilityLabel ??
                        'Check the schedule for updates.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: OtaColors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeltProgressCard extends StatelessWidget {
  const _BeltProgressCard({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.workspace_premium_rounded,
                backgroundColor: OtaColors.softRed,
                iconColor: OtaColors.maroon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belt Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _RankStat(label: 'Current Belt', value: student.belt),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _RankStat(label: 'Next Rank', value: student.nextRank),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Sticker Progress',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${student.stickerCount} / ${student.stickersRequired} Stickers',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OtaColors.maroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: student.stickerCount / student.stickersRequired,
              minHeight: 12,
              backgroundColor: OtaColors.softRed,
              color: OtaColors.actionRed,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${student.stickersRequired - student.stickerCount} more stickers until your next rank review.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: OtaColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.notifications,
    required this.isLoading,
    required this.errorMessage,
  });

  final List<NotificationItem> notifications;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).pushNamed(OtaRoutes.notifications),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _IconBadge(
                      icon: Icons.notifications_active_rounded,
                      backgroundColor: OtaColors.navy,
                      iconColor: OtaColors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'OTA Updates',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OtaColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: OtaColors.actionRed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${notifications.where((item) => !item.isRead).length} new',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: OtaColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (isLoading)
                  const _NotificationStatusRow(
                    icon: Icons.sync_rounded,
                    message: 'Loading OTA updates...',
                    showProgress: true,
                  )
                else if (errorMessage != null)
                  _NotificationStatusRow(
                    icon: Icons.cloud_off_rounded,
                    message: errorMessage!,
                  )
                else if (notifications.isEmpty)
                  const _NotificationStatusRow(
                    icon: Icons.notifications_none_rounded,
                    message: 'No updates right now.',
                  )
                else
                  for (final notification in notifications) ...[
                    _NotificationRow(title: notification.title),
                    if (notification != notifications.last)
                      const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const _actions = [
    _QuickActionData(
      Icons.calendar_month_rounded,
      'View Schedule',
      OtaRoutes.schedule,
    ),
    _QuickActionData(
      Icons.folder_copy_rounded,
      'Resources',
      OtaRoutes.resources,
    ),
    _QuickActionData(Icons.emoji_events_rounded, 'Events', OtaRoutes.events),
    _QuickActionData(Icons.chat_bubble_rounded, 'Message OTA'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 560 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth >= 560 ? 1.04 : 0.96,
          ),
          itemBuilder: (context, index) {
            final action = _actions[index];
            return _QuickActionTile(action: action);
          },
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickActionData action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OtaColors.white,
      borderRadius: BorderRadius.circular(22),
      shadowColor: OtaColors.navy.withValues(alpha: 0.08),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: action.route == null
            ? null
            : () => Navigator.of(context).pushNamed(action.route!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconBadge(
                icon: action.icon,
                backgroundColor: OtaColors.softRed,
                iconColor: OtaColors.maroon,
              ),
              const SizedBox(height: 12),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
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
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}

class _RankStat extends StatelessWidget {
  const _RankStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OtaColors.blush,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OtaColors.softRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationStatusRow extends StatelessWidget {
  const _NotificationStatusRow({
    required this.icon,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showProgress)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: OtaColors.maroon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: OtaColors.actionRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionData {
  const _QuickActionData(this.icon, this.label, [this.route]);

  final IconData icon;
  final String label;
  final String? route;
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Next class',
  };
}
