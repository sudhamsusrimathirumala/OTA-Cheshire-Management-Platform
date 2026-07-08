import 'package:flutter/material.dart';

import '../models/academy_event.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final locationId = appDataService.selectedStudentProfile.locationId;
        final events =
            appDataService.events
                .where(
                  (event) =>
                      event.isPublished &&
                      !event.isArchived &&
                      event.locationId == locationId,
                )
                .toList()
              ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

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
                                title: 'No events right now',
                                detail:
                                    'Published academy events will appear here.',
                              )
                            else
                              for (final event in events) ...[
                                _EventCard(event: event),
                                if (event != events.last)
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
  const _EventCard({required this.event});

  final AcademyEvent event;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: event.eventTypeLabel),
              _Badge(label: event.registrationLabel, isAccent: true),
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
          if (event.registrationUrl != null) ...[
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
                    'Registration link available',
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
  final start = _formatDateTime(event.startDateTime);
  final end = _formatTime(event.endDateTime);
  return '$start - $end';
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
