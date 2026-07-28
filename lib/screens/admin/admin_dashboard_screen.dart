import 'package:flutter/material.dart';

import '../../models/academy_announcement.dart';
import '../../models/academy_event.dart';
import '../../models/class_session.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/location_time_service.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final locationId = _dashboardLocationId();
        final academyNow = locationId.isEmpty
            ? DateTime.now()
            : const LocationTimeService().toLocationTime(
                DateTime.now(),
                locationId,
              );
        final schedule =
            appDataService
                .scheduleForWeekday(academyNow.weekday)
                .where((session) => session.isPublished)
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        final announcements = activeDashboardAnnouncements(
          appDataService.adminAnnouncements,
        );
        final events = upcomingDashboardEvents(
          appDataService.events,
          now: DateTime.now(),
        );

        return AdminPageShell(
          selectedDestination: AdminNavDestination.dashboard,
          title: 'Dashboard',
          subtitle:
              'Manage schedule changes, announcements, events, and student information.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 820;
              final sections = <Widget>[
                _SummarySection(
                  title: "Today's Schedule",
                  icon: Icons.today_outlined,
                  isLoading: appDataService.isScheduleLoading,
                  errorMessage: appDataService.scheduleErrorMessage,
                  emptyMessage: 'No published classes are scheduled today.',
                  rows: [for (final session in schedule) _scheduleRow(session)],
                ),
                _SummarySection(
                  title: 'Active Announcements',
                  icon: Icons.campaign_outlined,
                  isLoading: appDataService.isAnnouncementsLoading,
                  errorMessage: appDataService.announcementsErrorMessage,
                  emptyMessage: 'No published announcements are active.',
                  rows: [
                    for (final announcement in announcements)
                      _announcementRow(announcement),
                  ],
                ),
                _SummarySection(
                  title: 'Upcoming Events',
                  icon: Icons.event_available_outlined,
                  isLoading: appDataService.isEventsLoading,
                  errorMessage: appDataService.eventsErrorMessage,
                  emptyMessage: 'No upcoming events are available.',
                  rows: [for (final event in events) _eventRow(event)],
                ),
              ];

              if (!useTwoColumns) {
                return Column(
                  children: [
                    for (var index = 0; index < sections.length; index++) ...[
                      sections[index],
                      if (index != sections.length - 1)
                        const SizedBox(height: 14),
                    ],
                  ],
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sections.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 198,
                ),
                itemBuilder: (context, index) => sections[index],
              );
            },
          ),
        );
      },
    );
  }

  String _dashboardLocationId() {
    if (adminLocationController.isSuperAdmin) {
      return adminLocationController.selectedLocationId ?? '';
    }
    return adminLocationController.assignedLocation?.id ??
        adminLocationController.writeLocationId;
  }

  _InfoRow _scheduleRow(ClassSession session) =>
      _InfoRow(session.startLabel, session.className);

  _InfoRow _announcementRow(AcademyAnnouncement announcement) => _InfoRow(
    announcement.priority == 'important' ? 'Important' : 'Published',
    announcement.title,
  );

  _InfoRow _eventRow(AcademyEvent event) {
    final locationId = event.locationId;
    final local = const LocationTimeService().toLocationTime(
      event.startDateTime,
      locationId,
    );
    return _InfoRow(
      '${local.month}/${local.day}',
      event.title,
      event.registrationLabel,
    );
  }
}

@visibleForTesting
List<AcademyAnnouncement> activeDashboardAnnouncements(
  List<AcademyAnnouncement> announcements,
) {
  final active =
      announcements.where((announcement) => announcement.isPublished).toList()
        ..sort((a, b) => b.displayDate.compareTo(a.displayDate));
  return active.take(3).toList(growable: false);
}

@visibleForTesting
List<AcademyEvent> upcomingDashboardEvents(
  List<AcademyEvent> events, {
  required DateTime now,
}) {
  final upcoming =
      events
          .where(
            (event) =>
                !event.isArchived &&
                event.isPublished &&
                !event.endDateTime.isBefore(now.toUtc()),
          )
          .toList()
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  return upcoming.take(3).toList(growable: false);
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.rows,
    required this.isLoading,
    required this.errorMessage,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;
  final bool isLoading;
  final String? errorMessage;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: icon,
      child: isLoading
          ? const LinearProgressIndicator()
          : errorMessage != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage!,
                  style: const TextStyle(color: OtaColors.actionRed),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: appDataService.retryLiveData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            )
          : rows.isEmpty
          ? Text(emptyMessage)
          : Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _CompactRow(row: rows[index]),
                  if (index != rows.length - 1)
                    const Divider(height: 14, color: Color(0xFFE1E4EA)),
                ],
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        border: Border.all(color: const Color(0xFFE9D2D7)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x168B1E2D),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: OtaColors.softRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: OtaColors.maroon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9D2D7)),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.row});

  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: OtaColors.maroon,
      fontWeight: FontWeight.w800,
    );
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: OtaColors.ink,
      fontWeight: FontWeight.w700,
    );
    final metaStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: OtaColors.mutedText,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        if (row.meta != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              row.meta!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metaStyle,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.title, [this.meta]);

  final String label;
  final String title;
  final String? meta;
}
