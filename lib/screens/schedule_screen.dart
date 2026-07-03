import 'package:flutter/material.dart';

import '../models/class_session.dart';
import '../models/student_profile.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({this.initialDate, super.key});

  final DateTime? initialDate;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const double _hourHeight = 76;
  static const double _timelineGutterWidth = 66;
  static const double _eventGap = 8;

  final ScrollController _scrollController = ScrollController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isViewingToday =>
      DateUtils.isSameDay(_selectedDate, DateTime.now());

  StudentProfile get _student => appDataService.selectedStudentProfile;

  List<ClassSession> get _selectedDayClasses =>
      appDataService.scheduleForWeekday(_selectedDate.weekday);

  ClassSession? get _nextEligibleClass {
    final classes = _selectedDayClasses.where((session) {
      if (!session.isEligibleFor(_student)) {
        return false;
      }

      if (!_isViewingToday) {
        return true;
      }

      return session.startDateTime(_selectedDate).isAfter(DateTime.now());
    }).toList();

    if (classes.isEmpty) {
      return null;
    }

    classes.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return classes.first;
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = DateUtils.dateOnly(
        _selectedDate.subtract(const Duration(days: 1)),
      );
    });
    _scrollAfterDateChange();
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = DateUtils.dateOnly(
        _selectedDate.add(const Duration(days: 1)),
      );
    });
    _scrollAfterDateChange();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: OtaColors.maroon,
              onPrimary: OtaColors.white,
              surface: OtaColors.white,
              onSurface: OtaColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() => _selectedDate = DateUtils.dateOnly(pickedDate));
    _scrollAfterDateChange();
  }

  void _scrollAfterDateChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isViewingToday) {
        _scrollToCurrentTime();
      } else if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _firstClassOffset,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _scrollToCurrentTime() {
    if (!_isViewingToday || !_scrollController.hasClients) {
      return;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final targetOffset = ((currentMinutes / 60) * _hourHeight) - 180;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.jumpTo(clampedOffset);
  }

  double get _firstClassOffset {
    if (_selectedDayClasses.isEmpty) {
      return 0;
    }

    final firstStart = _selectedDayClasses
        .map((session) => session.startMinutes)
        .reduce((a, b) => a < b ? a : b);

    return ((firstStart / 60) * _hourHeight - 120).clamp(0.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final selectedClasses = _selectedDayClasses;

    return Scaffold(
      backgroundColor: OtaColors.blush,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      _DateNavigationHeader(
                        selectedDate: _selectedDate,
                        onPrevious: _goToPreviousDay,
                        onNext: _goToNextDay,
                        onDateTap: _pickDate,
                      ),
                      const SizedBox(height: 12),
                      _NextEligibleBanner(nextClass: _nextEligibleClass),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: selectedClasses.isEmpty
                      ? const _EmptyScheduleState()
                      : _ScheduleTimeline(
                          classes: selectedClasses,
                          selectedDate: _selectedDate,
                          isViewingToday: _isViewingToday,
                          scrollController: _scrollController,
                          hourHeight: _hourHeight,
                          timelineGutterWidth: _timelineGutterWidth,
                          eventGap: _eventGap,
                          student: _student,
                          nextEligibleSession: _nextEligibleClass,
                          onClassTap: _showClassDetails,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const OtaBottomNavBar(
        selectedDestination: OtaBottomNavDestination.schedule,
      ),
    );
  }

  void _showClassDetails(ClassSession session) {
    final isEligible = session.isEligibleFor(_student);
    final timeLabel = session.timeRangeLabel;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isEligible ? OtaColors.softRed : OtaColors.blush,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isEligible
                            ? Icons.star_rounded
                            : Icons.info_outline_rounded,
                        color: isEligible
                            ? const Color(0xFFD9A441)
                            : OtaColors.mutedText,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.className,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: OtaColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: OtaColors.mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _DetailRow(
                  icon: Icons.verified_user_rounded,
                  label: 'Belt Eligibility',
                  value: session.eligibilityLabel,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.description_rounded,
                  label: 'Description',
                  value: session.description,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.favorite_rounded,
                  label: 'Preferred Class',
                  value: session.isPreferred ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateNavigationHeader extends StatelessWidget {
  const _DateNavigationHeader({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onDateTap,
  });

  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: Colors.grey.shade800,
          tooltip: 'Previous day',
        ),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onDateTap,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(_formatFullDate(selectedDate)),
            style: FilledButton.styleFrom(
              foregroundColor: OtaColors.ink,
              backgroundColor: OtaColors.white,
              elevation: 2,
              shadowColor: OtaColors.navy.withValues(alpha: 0.08),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: Colors.grey.shade800,
          tooltip: 'Next day',
        ),
      ],
    );
  }
}

class _NextEligibleBanner extends StatelessWidget {
  const _NextEligibleBanner({required this.nextClass});

  final ClassSession? nextClass;

  @override
  Widget build(BuildContext context) {
    if (nextClass == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: OtaColors.navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFD9A441)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Next eligible class: ${nextClass!.className} • ${nextClass!.startLabel}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTimeline extends StatelessWidget {
  const _ScheduleTimeline({
    required this.classes,
    required this.selectedDate,
    required this.isViewingToday,
    required this.scrollController,
    required this.hourHeight,
    required this.timelineGutterWidth,
    required this.eventGap,
    required this.student,
    required this.nextEligibleSession,
    required this.onClassTap,
  });

  final List<ClassSession> classes;
  final DateTime selectedDate;
  final bool isViewingToday;
  final ScrollController scrollController;
  final double hourHeight;
  final double timelineGutterWidth;
  final double eventGap;
  final StudentProfile student;
  final ClassSession? nextEligibleSession;
  final ValueChanged<ClassSession> onClassTap;

  @override
  Widget build(BuildContext context) {
    final timelineHeight = 24 * hourHeight;
    final positionedEvents = _positionEvents(classes);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: scrollController,
        child: SizedBox(
          height: timelineHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final eventAreaWidth =
                  constraints.maxWidth - timelineGutterWidth - 16;

              return Stack(
                children: [
                  for (var hour = 0; hour <= 24; hour++)
                    _HourGuide(
                      hour: hour,
                      top: hour * hourHeight,
                      timelineGutterWidth: timelineGutterWidth,
                    ),
                  for (final positionedEvent in positionedEvents)
                    _PositionedClassBlock(
                      positionedEvent: positionedEvent,
                      selectedDate: selectedDate,
                      eventAreaWidth: eventAreaWidth,
                      timelineGutterWidth: timelineGutterWidth,
                      hourHeight: hourHeight,
                      eventGap: eventGap,
                      student: student,
                      nextEligibleSession: nextEligibleSession,
                      onTap: () => onClassTap(positionedEvent.session),
                    ),
                  if (isViewingToday)
                    _CurrentTimeIndicator(
                      top: _currentTimeTop(hourHeight),
                      timelineGutterWidth: timelineGutterWidth,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HourGuide extends StatelessWidget {
  const _HourGuide({
    required this.hour,
    required this.top,
    required this.timelineGutterWidth,
  });

  final int hour;
  final double top;
  final double timelineGutterWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timelineGutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                _formatHour(hour),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: OtaColors.navy.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionedClassBlock extends StatelessWidget {
  const _PositionedClassBlock({
    required this.positionedEvent,
    required this.selectedDate,
    required this.eventAreaWidth,
    required this.timelineGutterWidth,
    required this.hourHeight,
    required this.eventGap,
    required this.student,
    required this.nextEligibleSession,
    required this.onTap,
  });

  final _PositionedClassEvent positionedEvent;
  final DateTime selectedDate;
  final double eventAreaWidth;
  final double timelineGutterWidth;
  final double hourHeight;
  final double eventGap;
  final StudentProfile student;
  final ClassSession? nextEligibleSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = positionedEvent.session;
    final columnWidth =
        (eventAreaWidth - ((positionedEvent.columnCount - 1) * eventGap)) /
        positionedEvent.columnCount;
    final left =
        timelineGutterWidth +
        8 +
        (positionedEvent.column * (columnWidth + eventGap));
    final top = (session.startMinutes / 60) * hourHeight;
    final height = (session.durationMinutes / 60) * hourHeight;
    final isEligible = session.isEligibleFor(student);
    final isPast = session.endDateTime(selectedDate).isBefore(DateTime.now());
    final isNext = session == nextEligibleSession;

    return Positioned(
      top: top + 4,
      left: left,
      width: columnWidth,
      height: height - 8,
      child: _ClassBlock(
        session: session,
        isEligible: isEligible,
        isPast: isPast,
        isNext: isNext,
        onTap: onTap,
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  const _ClassBlock({
    required this.session,
    required this.isEligible,
    required this.isPast,
    required this.isNext,
    required this.onTap,
  });

  final ClassSession session;
  final bool isEligible;
  final bool isPast;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isEligible
        ? OtaColors.softRed
        : const Color(0xFFF4F5F7);
    final borderColor = isEligible
        ? OtaColors.actionRed
        : const Color(0xFFD0D5DD);
    final textColor = isEligible ? OtaColors.maroon : OtaColors.mutedText;
    final opacity = isPast ? 0.48 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        elevation: isEligible && !isPast ? 3 : 0,
        shadowColor: OtaColors.navy.withValues(alpha: 0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 54;

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: isCompact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: borderColor.withValues(
                      alpha: isEligible ? 0.7 : 0.9,
                    ),
                    width: isEligible ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isEligible) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: Color(0xFFD9A441),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            session.className,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (!isCompact) ...[
                      const SizedBox(height: 5),
                      Text(
                        session.timeRangeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                    if (isNext && !isCompact) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Next eligible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: OtaColors.navy,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({
    required this.top,
    required this.timelineGutterWidth,
  });

  final double top;
  final double timelineGutterWidth;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: timelineGutterWidth - 6,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: OtaColors.actionRed,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 2, color: OtaColors.actionRed)),
        ],
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: OtaColors.softRed,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: OtaColors.maroon,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No classes scheduled today.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Next Available Class:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Monday • 4:00 PM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: OtaColors.maroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Little Tiger',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: OtaColors.maroon, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionedClassEvent {
  const _PositionedClassEvent({
    required this.session,
    required this.column,
    required this.columnCount,
  });

  final ClassSession session;
  final int column;
  final int columnCount;
}

List<_PositionedClassEvent> _positionEvents(List<ClassSession> sessions) {
  final sortedSessions = [...sessions]
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  return [
    for (final session in sortedSessions)
      _PositionedClassEvent(
        session: session,
        column: _overlapColumn(session, sortedSessions),
        columnCount: _overlapCount(session, sortedSessions),
      ),
  ];
}

int _overlapCount(ClassSession session, List<ClassSession> sessions) {
  final overlaps = sessions.where((other) => _sessionsOverlap(session, other));
  return overlaps.length.clamp(1, 2);
}

int _overlapColumn(ClassSession session, List<ClassSession> sessions) {
  final overlaps =
      sessions.where((other) => _sessionsOverlap(session, other)).toList()
        ..sort((a, b) {
          final timeComparison = a.startMinutes.compareTo(b.startMinutes);
          if (timeComparison != 0) {
            return timeComparison;
          }
          return a.className.compareTo(b.className);
        });

  final index = overlaps.indexOf(session);
  return index < 0 ? 0 : index.clamp(0, 1);
}

bool _sessionsOverlap(ClassSession a, ClassSession b) {
  return a.startMinutes < b.endMinutes && b.startMinutes < a.endMinutes;
}

double _currentTimeTop(double hourHeight) {
  final now = DateTime.now();
  return ((now.hour * 60 + now.minute) / 60) * hourHeight;
}

String _formatFullDate(DateTime date) {
  return '${_weekdayLabel(date.weekday)}, ${_monthNames[date.month - 1]} ${date.day}';
}

String _formatHour(int hour) {
  final normalizedHour = hour % 24;
  if (normalizedHour == 0) {
    return '12 AM';
  }
  if (normalizedHour < 12) {
    return '$normalizedHour AM';
  }
  if (normalizedHour == 12) {
    return '12 PM';
  }
  return '${normalizedHour - 12} PM';
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.sunday => 'Sunday',
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    _ => 'Sunday',
  };
}

const _monthNames = [
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
