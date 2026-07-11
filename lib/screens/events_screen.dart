import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_event.dart';
import '../models/academy_resource.dart';
import '../services/app_data_service_provider.dart';
import '../services/location_time_service.dart';
import '../theme/ota_colors.dart';
import 'resource_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final now = DateTime.now();
        final locationId = appDataService.selectedStudentProfile.locationId;
        final events =
            appDataService.events
                .where(
                  (event) =>
                      event.isPublished &&
                      !event.isArchived &&
                      event.eventType != 'closure' &&
                      event.locationId == locationId &&
                      !event.endDateTime.isBefore(now),
                )
                .toList()
              ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
        final resourcesById = {
          for (final resource in appDataService.resources)
            if (resource.resourceSection == 'general' &&
                resource.locationId == locationId &&
                resource.isPublished &&
                !resource.isArchived)
              resource.id: resource,
        };
        final groupedEvents = _groupEventsByMonth(events);

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
                            const _EventsHeader(),
                            const SizedBox(height: 16),
                            if (appDataService.isEventsLoading)
                              const _StatusCard(
                                icon: Icons.sync_rounded,
                                title: 'Loading events',
                                detail: 'Checking the latest OTA events.',
                                showProgress: true,
                              )
                            else if (appDataService.eventsErrorMessage != null)
                              _StatusCard(
                                icon: Icons.cloud_off_rounded,
                                title: 'Events unavailable',
                                detail: appDataService.eventsErrorMessage!,
                              )
                            else if (events.isEmpty)
                              const _StatusCard(
                                icon: Icons.event_busy_rounded,
                                title: 'No upcoming events right now.',
                                detail:
                                    'Published academy events will appear here.',
                              )
                            else
                              for (final group in groupedEvents.entries) ...[
                                _EventGroupHeader(label: group.key),
                                const SizedBox(height: 8),
                                for (final event in group.value) ...[
                                  _EventCard(
                                    event: event,
                                    resourcesById: resourcesById,
                                  ),
                                  if (event != group.value.last)
                                    const SizedBox(height: 12),
                                ],
                                if (group.key != groupedEvents.keys.last)
                                  const SizedBox(height: 16),
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
        );
      },
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: OtaColors.softRed,
              foregroundColor: OtaColors.maroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upcoming academy events and registration details.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.resourcesById});

  final AcademyEvent event;
  final Map<String, AcademyResource> resourcesById;

  @override
  Widget build(BuildContext context) {
    final primaryResource = event.primaryRegistrationResourceId == null
        ? null
        : resourcesById[event.primaryRegistrationResourceId];

    return InkWell(
      onTap: () => _showEventDetails(context, event, resourcesById),
      borderRadius: BorderRadius.circular(24),
      child: _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBadge(date: _eventLocalStart(event)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(label: event.eventTypeLabel),
                      _Badge(label: event.registrationLabel, isAccent: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatEventDateTime(event),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.maroon,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              event.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (primaryResource != null || event.registrationUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: OtaColors.maroon,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      primaryResource?.title ?? 'Registration link available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OtaColors.maroon,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showEventDetails(
  BuildContext context,
  AcademyEvent event,
  Map<String, AcademyResource> resourcesById,
) {
  final linkedResources = [
    for (final resourceId in event.linkedResourceIds)
      if (resourceId != event.primaryRegistrationResourceId &&
          resourcesById[resourceId] != null)
        resourcesById[resourceId]!,
  ];
  final primaryResource = event.primaryRegistrationResourceId == null
      ? null
      : resourcesById[event.primaryRegistrationResourceId];
  final eventResource = primaryResource ?? linkedResources.firstOrNull;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: OtaColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatEventDateTime(event),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OtaColors.maroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                event.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (eventResource != null) ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    Navigator.of(context).pop();
                    navigator.push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            ResourceDetailScreen(resource: eventResource),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: OtaColors.maroon,
                    foregroundColor: OtaColors.white,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Go to Resource for Event'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
              if (primaryResource != null) ...[
                const SizedBox(height: 18),
                _DetailSectionTitle(label: 'Registration'),
                _ResourceLinkTile(resource: primaryResource),
              ] else if (event.registrationUrl != null) ...[
                const SizedBox(height: 18),
                _DetailSectionTitle(label: 'Registration'),
                _CopyableLink(url: event.registrationUrl!),
              ],
              if (linkedResources.isNotEmpty) ...[
                const SizedBox(height: 18),
                _DetailSectionTitle(label: 'Linked Resources'),
                for (final resource in linkedResources) ...[
                  _ResourceLinkTile(resource: resource),
                  if (resource != linkedResources.last)
                    const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: OtaColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResourceLinkTile extends StatelessWidget {
  const _ResourceLinkTile({required this.resource});

  final AcademyResource resource;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OtaColors.blush,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resource.title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (resource.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              resource.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (resource.linkUrl != null) ...[
            const SizedBox(height: 8),
            _CopyableLink(url: resource.linkUrl!),
          ],
        ],
      ),
    );
  }
}

class _CopyableLink extends StatelessWidget {
  const _CopyableLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            url,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.maroon,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Link copied.')));
          },
          tooltip: 'Copy link',
          icon: const Icon(Icons.copy_rounded),
          color: OtaColors.maroon,
        ),
      ],
    );
  }
}

class _EventGroupHeader extends StatelessWidget {
  const _EventGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: OtaColors.ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: OtaColors.softRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            _monthNames[date.month - 1].toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OtaColors.maroon,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            date.day.toString(),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
    return _SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress)
            const CircularProgressIndicator()
          else
            Icon(icon, color: OtaColors.maroon, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(24),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.isAccent = false});

  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent ? OtaColors.softRed : const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isAccent ? OtaColors.maroon : OtaColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _formatEventDateTime(AcademyEvent event) {
  final startDateTime = _eventLocalStart(event);
  final endDateTime = const LocationTimeService().toLocationTime(
    event.endDateTime,
    event.locationId,
  );
  final start = _formatDateTime(startDateTime);
  final end = _formatTime(endDateTime);
  return '$start - $end';
}

DateTime _eventLocalStart(AcademyEvent event) {
  return const LocationTimeService().toLocationTime(
    event.startDateTime,
    event.locationId,
  );
}

String _formatDateTime(DateTime dateTime) {
  return '${_monthNames[dateTime.month - 1]} ${dateTime.day}, ${_formatTime(dateTime)}';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

Map<String, List<AcademyEvent>> _groupEventsByMonth(List<AcademyEvent> events) {
  final groupedEvents = <String, List<AcademyEvent>>{};

  for (final event in events) {
    final localStart = _eventLocalStart(event);
    final key =
        '${_fullMonthNames[localStart.month - 1]} '
        '${localStart.year}';
    groupedEvents.putIfAbsent(key, () => <AcademyEvent>[]).add(event);
  }

  return groupedEvents;
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

const _fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
