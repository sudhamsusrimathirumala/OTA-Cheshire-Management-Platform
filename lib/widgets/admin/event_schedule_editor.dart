import 'package:flutter/material.dart';

import '../../models/event_schedule.dart';
import '../../services/location_time_service.dart';

class EventScheduleEditor extends StatefulWidget {
  const EventScheduleEditor({
    required this.locationId,
    required this.start,
    required this.end,
    required this.onChanged,
    this.initial,
    this.duplicate = false,
    super.key,
  });
  final String locationId;
  final DateTime? start;
  final DateTime? end;
  final EventSchedule? initial;
  final bool duplicate;
  final ValueChanged<String> onChanged;
  @override
  State<EventScheduleEditor> createState() => EventScheduleEditorState();
}

class EventScheduleEditorState extends State<EventScheduleEditor> {
  String _frequency = 'none';
  DateTime? _until;
  int _interval = 1;
  int _count = maxEventOccurrences;
  final _weekdays = <int>{};
  final _custom = <String>{};
  final _times = <int, List<int>>{};
  EventSchedule? _preview;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.initial?.rule;
    if (rule != null) {
      _frequency = rule.frequency;
      _until = parseEventDate(rule.endDate);
      _interval = rule.intervalWeeks;
      _count = rule.maxOccurrences;
      _weekdays.addAll(rule.weekdays);
      _custom.addAll(rule.customDates);
      _times.addAll(rule.weekdayTimes);
    }
    _refresh();
  }

  @override
  void didUpdateWidget(EventScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _refresh();
    }
  }

  EventSchedule? buildSchedule() {
    if (_frequency == 'none') return null;
    if (widget.start == null || widget.end == null || _until == null) {
      throw ArgumentError(
        'Select the first session times and a repeat end date.',
      );
    }
    final service = const LocationTimeService();
    final start = service.toLocationTime(widget.start!, widget.locationId);
    final end = service.toLocationTime(widget.end!, widget.locationId);
    final endDay = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return EventSchedule.generate(
      EventRecurrence(
        frequency: _frequency,
        startDate: eventDateKey(start),
        endDate: eventDateKey(_until!),
        startMinutes: start.hour * 60 + start.minute,
        endMinutes: end.hour * 60 + end.minute,
        endDayOffset: endDay,
        intervalWeeks: _interval,
        weekdays: _weekdays.toList()..sort(),
        customDates: _custom.toList()..sort(),
        weekdayTimes: Map.of(_times),
        maxOccurrences: _count,
      ),
      service.timeZoneIdFor(widget.locationId),
      previous: widget.duplicate ? null : widget.initial,
    );
  }

  void _refresh() {
    try {
      _preview = buildSchedule();
      _error = null;
    } catch (e) {
      _preview = null;
      _error = e is ArgumentError
          ? '${e.message}'
          : 'Check the repeat settings.';
    }
  }

  void _change(VoidCallback action) {
    setState(() {
      action();
      _refresh();
    });
    widget.onChanged(
      '$_frequency|$_until|$_interval|$_count|$_weekdays|$_custom|$_times',
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _frequency,
        decoration: const InputDecoration(labelText: 'Schedule'),
        items: const [
          DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
          DropdownMenuItem(value: 'daily', child: Text('Daily')),
          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
          DropdownMenuItem(value: 'custom', child: Text('Custom dates')),
        ],
        onChanged: (v) => _change(() => _frequency = v ?? 'none'),
      ),
      if (_frequency != 'none') ...[
        const Text(
          'Start/end above are the first session times. Registration applies to the whole series.',
        ),
        TextButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            _until == null
                ? 'Select repeat end date'
                : 'Repeat through ${eventDateKey(_until!)}',
          ),
          onPressed: () async {
            final date = await _pickDate(_until);
            if (date != null) _change(() => _until = date);
          },
        ),
        TextFormField(
          initialValue: '$_count',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum sessions (1–180)',
          ),
          onChanged: (v) => _change(() => _count = int.tryParse(v) ?? 0),
        ),
        if (_frequency == 'weekly') ...[
          TextFormField(
            initialValue: '$_interval',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Repeat every N weeks (1–52)',
            ),
            onChanged: (v) => _change(() => _interval = int.tryParse(v) ?? 0),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(_days[day - 1]),
                  selected: _weekdays.contains(day),
                  onSelected: (v) => _change(
                    () => v ? _weekdays.add(day) : _weekdays.remove(day),
                  ),
                ),
            ],
          ),
        ],
        if (_frequency == 'custom') ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add session date'),
            onPressed: () async {
              final date = await _pickDate(null);
              if (date != null) _change(() => _custom.add(eventDateKey(date)));
            },
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final date in _custom.toList()..sort())
                InputChip(
                  label: Text(date),
                  onDeleted: () => _change(() => _custom.remove(date)),
                ),
            ],
          ),
        ],
        ExpansionTile(
          title: const Text('Different times by weekday'),
          children: [
            for (var day = 1; day <= 7; day++)
              if (_frequency != 'weekly' || _weekdays.contains(day))
                ListTile(
                  title: Text(_days[day - 1]),
                  subtitle: Text(
                    _times[day] == null
                        ? 'Use session times above'
                        : '${_clock(_times[day]![0])} – ${_clock(_times[day]![1])}${_times[day]![2] == 1 ? ' (next day)' : ''}',
                  ),
                  trailing: _times[day] == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _change(() => _times.remove(day)),
                        ),
                  onTap: () async {
                    final start = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (start == null || !context.mounted) return;
                    final end = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 15, minute: 0),
                    );
                    if (end == null) return;
                    final a = start.hour * 60 + start.minute;
                    final b = end.hour * 60 + end.minute;
                    _change(() => _times[day] = [a, b, b <= a ? 1 : 0]);
                  },
                ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_preview != null)
          ExpansionTile(
            title: Text(
              '${_preview!.occurrences.length} sessions • view dates',
            ),
            children: [
              for (final o in _preview!.occurrences)
                ListTile(
                  dense: true,
                  title: Text(
                    const LocationTimeService().formatDateTime(
                      o.start,
                      widget.locationId,
                    ),
                  ),
                  subtitle: Text(
                    '${const LocationTimeService().formatDateTime(o.end, widget.locationId)}${o.canceled ? ' • Canceled' : ''}',
                  ),
                ),
            ],
          ),
      ],
    ],
  );
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _clock(int v) =>
    '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';

class EventRemindersEditor extends StatelessWidget {
  const EventRemindersEditor({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final EventReminders value;
  final ValueChanged<EventReminders> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Automatic Reminders',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Automatic reminders'),
        value: value.mode != 'none',
        onChanged: (enabled) => onChanged(
          EventReminders(
            mode: enabled ? 'first' : 'none',
            offsetsMinutes: value.offsetsMinutes.isEmpty
                ? [1440, 60]
                : value.offsetsMinutes,
          ),
        ),
      ),
      if (value.mode != 'none') ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey(value.mode),
          initialValue: value.mode,
          decoration: const InputDecoration(labelText: 'Reminder mode'),
          items: const [
            DropdownMenuItem(
              value: 'first',
              child: Text('First occurrence only (default)'),
            ),
            DropdownMenuItem(value: 'every', child: Text('Every occurrence')),
          ],
          onChanged: (mode) => onChanged(
            EventReminders(mode: mode!, offsetsMinutes: value.offsetsMinutes),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final e in const {
              10080: '7 days before',
              4320: '3 days before',
              1440: '1 day before',
              120: '2 hours before',
              60: '1 hour before',
            }.entries)
              FilterChip(
                label: Text(e.value),
                selected: value.offsetsMinutes.contains(e.key),
                onSelected: (v) => onChanged(
                  EventReminders(
                    mode: value.mode,
                    offsetsMinutes: v
                        ? [...value.offsetsMinutes, e.key]
                        : value.offsetsMinutes
                              .where((n) => n != e.key)
                              .toList(),
                  ),
                ),
              ),
          ],
        ),
        const Text('Past reminder times are skipped.'),
      ],
    ],
  );
}
