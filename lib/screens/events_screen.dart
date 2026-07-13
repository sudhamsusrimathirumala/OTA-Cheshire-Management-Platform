import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_event.dart';
import '../models/academy_resource.dart';
import '../routes.dart';
import '../services/app_data_service.dart';
import '../services/app_data_service_provider.dart';
import '../services/location_time_service.dart';
import '../theme/ota_colors.dart';
import 'resource_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({this.dataService, this.now, super.key});

  final AppDataService? dataService;
  final DateTime? now;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  String? _locationId;

  AppDataService get _service => widget.dataService ?? appDataService;

  void _initializeDates(String locationId) {
    final today = academyLocalDate(widget.now ?? DateTime.now(), locationId);
    _locationId = locationId;
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = today;
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month);
    });
  }

  Future<void> _goBack(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
    } else if (context.mounted) {
      await navigator.pushReplacementNamed(OtaRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, child) {
        final locationId = _service.selectedStudentProfile.locationId;
        if (_locationId != locationId) _initializeDates(locationId);
        final events = visibleStudentCalendarEvents(
          _service.events,
          locationId: locationId,
        );
        final selectedEvents = eventsForAcademyDate(
          events,
          date: _selectedDate,
        );
        final canPop = Navigator.of(context).canPop();

        return PopScope<void>(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _goBack(context);
          },
          child: Scaffold(
            backgroundColor: OtaColors.blush,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _EventsHeader(onBack: () => _goBack(context)),
                        const SizedBox(height: 16),
                        _MonthCalendar(
                          visibleMonth: _visibleMonth,
                          selectedDate: _selectedDate,
                          today: academyLocalDate(
                            widget.now ?? DateTime.now(),
                            locationId,
                          ),
                          events: events,
                          onPreviousMonth: () => _changeMonth(-1),
                          onNextMonth: () => _changeMonth(1),
                          onSelectDate: (date) {
                            setState(() => _selectedDate = date);
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _formatSelectedDate(_selectedDate),
                          key: const Key('selected-date-heading'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: OtaColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        if (_service.isEventsLoading)
                          const _StatusCard(
                            icon: Icons.sync_rounded,
                            title: 'Loading events',
                            detail: 'Checking the latest OTA events.',
                            showProgress: true,
                          )
                        else if (_service.eventsErrorMessage != null)
                          _StatusCard(
                            icon: Icons.cloud_off_rounded,
                            title: 'Events unavailable',
                            detail: _service.eventsErrorMessage!,
                          )
                        else if (events.isEmpty)
                          const _StatusCard(
                            icon: Icons.event_busy_rounded,
                            title: 'No published events right now.',
                            detail:
                                'Published academy events will appear here.',
                          )
                        else if (selectedEvents.isEmpty)
                          const _EmptyDateMessage()
                        else
                          for (
                            var index = 0;
                            index < selectedEvents.length;
                            index++
                          ) ...[
                            _EventCard(
                              event: selectedEvents[index],
                              onTap: () => _showEventDetails(
                                context,
                                selectedEvents[index],
                                _service,
                              ),
                            ),
                            if (index != selectedEvents.length - 1)
                              const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
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
                  'Browse academy events and registration details by date.',
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
  const _EventCard({required this.event, required this.onTap});

  final AcademyEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: _SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: OtaColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatEventDateTime(event),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OtaColors.maroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(label: event.eventTypeLabel),
                      _Badge(label: event.registrationLabel, isAccent: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded, color: OtaColors.maroon),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.today,
    required this.events,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime today;
  final List<AcademyEvent> events;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final dates = monthGridDates(visibleMonth);
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('previous-month'),
                onPressed: onPreviousMonth,
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_fullMonthNames[visibleMonth.month - 1]} ${visibleMonth.year}',
                  key: const Key('calendar-month-heading'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                key: const Key('next-month'),
                onPressed: onNextMonth,
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final weekday in _weekdayHeaders)
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: OtaColors.mutedText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            key: const Key('month-calendar-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dates.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.88,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final date = dates[index];
              if (date == null) return const SizedBox.shrink();
              final count = events
                  .where((event) => eventOccursOnAcademyDate(event, date))
                  .length;
              return _CalendarDay(
                date: date,
                eventCount: count,
                isToday: DateUtils.isSameDay(date, today),
                isSelected: DateUtils.isSameDay(date, selectedDate),
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.eventCount,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final int eventCount;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${_fullMonthNames[date.month - 1]} ${date.day}, ${date.year}',
      selected: isSelected,
      button: true,
      child: InkWell(
        key: Key('calendar-day-${date.year}-${date.month}-${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected ? OtaColors.maroon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday ? OtaColors.maroon : Colors.transparent,
              width: isToday ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? OtaColors.white : OtaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              if (eventCount > 0)
                Container(
                  key: Key(
                    'event-marker-${date.year}-${date.month}-${date.day}',
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? OtaColors.white : OtaColors.softRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$eventCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: OtaColors.maroon,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDateMessage extends StatelessWidget {
  const _EmptyDateMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'No events on this date.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OtaColors.mutedText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

void _showEventDetails(
  BuildContext context,
  AcademyEvent event,
  AppDataService dataService,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: OtaColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return AnimatedBuilder(
        animation: dataService,
        builder: (context, child) {
          final locationId = dataService.selectedStudentProfile.locationId;
          final liveEvent = visibleStudentEventById(
            dataService.events,
            eventId: event.id,
            locationId: locationId,
          );
          if (liveEvent == null) {
            return _UnavailableEventDetails(
              onClose: () => Navigator.of(context).pop(),
            );
          }
          final displayedEvent = liveEvent;
          final resourcesById = {
            for (final resource in dataService.resources)
              if (resource.resourceSection == 'general' &&
                  resource.locationId == displayedEvent.locationId &&
                  resource.isPublished &&
                  !resource.isArchived)
                resource.id: resource,
          };
          final linkedResources = [
            for (final resourceId in displayedEvent.linkedResourceIds)
              if (resourceId != displayedEvent.primaryRegistrationResourceId &&
                  resourcesById[resourceId] != null)
                resourcesById[resourceId]!,
          ];
          final primaryResource =
              displayedEvent.primaryRegistrationResourceId == null
              ? null
              : resourcesById[displayedEvent.primaryRegistrationResourceId];

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayedEvent.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: OtaColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatEventDateTime(displayedEvent),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: OtaColors.maroon,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayedEvent.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OtaColors.mutedText,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (primaryResource != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        Navigator.of(context).pop();
                        navigator.push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                ResourceDetailScreen(resource: primaryResource),
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
    },
  );
}

class _UnavailableEventDetails extends StatelessWidget {
  const _UnavailableEventDetails({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              color: OtaColors.maroon,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              'This event is no longer available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.maroon,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
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
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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

DateTime academyLocalDate(DateTime instant, String locationId) {
  final local = const LocationTimeService().toLocationTime(instant, locationId);
  return DateTime(local.year, local.month, local.day);
}

DateTime eventAcademyLocalStartDate(AcademyEvent event) {
  return academyLocalDate(event.startDateTime, event.locationId);
}

DateTime eventAcademyLocalEndDate(AcademyEvent event) {
  return academyLocalDate(event.endDateTime, event.locationId);
}

bool eventOccursOnAcademyDate(AcademyEvent event, DateTime date) {
  final calendarDate = DateTime(date.year, date.month, date.day);
  final startDate = eventAcademyLocalStartDate(event);
  final endDate = eventAcademyLocalEndDate(event);
  return !calendarDate.isBefore(startDate) && !calendarDate.isAfter(endDate);
}

List<AcademyEvent> visibleStudentCalendarEvents(
  Iterable<AcademyEvent> events, {
  required String locationId,
}) {
  return events
      .where(
        (event) =>
            event.isPublished &&
            !event.isArchived &&
            event.eventType != 'closure' &&
            event.locationId == locationId,
      )
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
}

AcademyEvent? visibleStudentEventById(
  Iterable<AcademyEvent> events, {
  required String eventId,
  required String locationId,
}) {
  return visibleStudentCalendarEvents(
    events,
    locationId: locationId,
  ).where((event) => event.id == eventId).firstOrNull;
}

List<AcademyEvent> eventsForAcademyDate(
  Iterable<AcademyEvent> events, {
  required DateTime date,
}) {
  return events.where((event) => eventOccursOnAcademyDate(event, date)).toList()
    ..sort((a, b) {
      final aLocal = const LocationTimeService().toLocationTime(
        a.startDateTime,
        a.locationId,
      );
      final bLocal = const LocationTimeService().toLocationTime(
        b.startDateTime,
        b.locationId,
      );
      return aLocal.compareTo(bLocal);
    });
}

List<DateTime?> monthGridDates(DateTime month) {
  final firstDay = DateTime(month.year, month.month);
  final leadingBlanks = firstDay.weekday % DateTime.daysPerWeek;
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final cellCount = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
  return List<DateTime?>.generate(cellCount, (index) {
    final day = index - leadingBlanks + 1;
    if (day < 1 || day > daysInMonth) return null;
    return DateTime(month.year, month.month, day);
  });
}

String _formatSelectedDate(DateTime date) {
  return '${_weekdayNames[date.weekday % 7]}, '
      '${_fullMonthNames[date.month - 1]} ${date.day}, ${date.year}';
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

const _weekdayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const _weekdayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
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
