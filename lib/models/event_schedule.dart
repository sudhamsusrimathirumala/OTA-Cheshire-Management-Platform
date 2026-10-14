import 'package:timezone/timezone.dart' as tz;

import '../services/location_time_service.dart';

const maxEventOccurrences = 180;
const maxEventScheduleDays = 366;

class EventOccurrence {
  const EventOccurrence({
    required this.id,
    required this.start,
    required this.end,
    this.canceled = false,
    this.overridden = false,
  });
  final String id;
  final DateTime start;
  final DateTime end;
  final bool canceled;
  final bool overridden;

  EventOccurrence copyWith({DateTime? start, DateTime? end, bool? canceled}) =>
      EventOccurrence(
        id: id,
        start: start ?? this.start,
        end: end ?? this.end,
        canceled: canceled ?? this.canceled,
        overridden: true,
      );
  Map<String, Object> toMap() => {
    'id': id,
    'startMillis': start.millisecondsSinceEpoch,
    'endMillis': end.millisecondsSinceEpoch,
    'canceled': canceled,
    'overridden': overridden,
  };
  factory EventOccurrence.fromMap(Map<String, dynamic> map) => EventOccurrence(
    id: map['id'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(
      map['startMillis'] as int,
      isUtc: true,
    ),
    end: DateTime.fromMillisecondsSinceEpoch(
      map['endMillis'] as int,
      isUtc: true,
    ),
    canceled: map['canceled'] == true,
    overridden: map['overridden'] == true,
  );
}

class EventRecurrence {
  const EventRecurrence({
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.startMinutes,
    required this.endMinutes,
    this.endDayOffset = 0,
    this.intervalWeeks = 1,
    this.weekdays = const [],
    this.customDates = const [],
    this.weekdayTimes = const {},
    this.maxOccurrences = maxEventOccurrences,
  });
  final String frequency; // daily, weekly, custom
  final String startDate;
  final String endDate;
  final int startMinutes;
  final int endMinutes;
  final int endDayOffset;
  final int intervalWeeks;
  final List<int> weekdays;
  final List<String> customDates;
  // Each weekday maps to [start minute, end minute, end day offset].
  final Map<int, List<int>> weekdayTimes;
  final int maxOccurrences;

  Map<String, Object> toMap() => {
    'frequency': frequency,
    'startDate': startDate,
    'endDate': endDate,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'endDayOffset': endDayOffset,
    'intervalWeeks': intervalWeeks,
    'weekdays': weekdays,
    'customDates': customDates,
    'weekdayTimes': {for (final e in weekdayTimes.entries) '${e.key}': e.value},
    'maxOccurrences': maxOccurrences,
  };
  factory EventRecurrence.fromMap(Map<String, dynamic> m) => EventRecurrence(
    frequency: m['frequency'] as String,
    startDate: m['startDate'] as String,
    endDate: m['endDate'] as String,
    startMinutes: m['startMinutes'] as int,
    endMinutes: m['endMinutes'] as int,
    endDayOffset: m['endDayOffset'] as int? ?? 0,
    intervalWeeks: m['intervalWeeks'] as int? ?? 1,
    weekdays: List<int>.from(m['weekdays'] as List? ?? []),
    customDates: List<String>.from(m['customDates'] as List? ?? []),
    weekdayTimes: {
      for (final e in (m['weekdayTimes'] as Map? ?? {}).entries)
        int.parse(e.key as String): List<int>.from(e.value as List),
    },
    maxOccurrences: m['maxOccurrences'] as int? ?? maxEventOccurrences,
  );

  List<EventOccurrence> expand(String timeZoneId) {
    LocationTimeService.initialize();
    final zone = timeZoneId == 'UTC' ? tz.UTC : tz.getLocation(timeZoneId);
    final first = parseEventDate(startDate);
    final last = parseEventDate(endDate);
    final days = last.difference(first).inDays;
    if (!['daily', 'weekly', 'custom'].contains(frequency) ||
        days < 0 ||
        days >= maxEventScheduleDays ||
        intervalWeeks < 1 ||
        intervalWeeks > 52 ||
        maxOccurrences < 1 ||
        maxOccurrences > maxEventOccurrences ||
        customDates.length > maxEventOccurrences ||
        weekdays.any((d) => d < 1 || d > 7) ||
        (frequency == 'weekly' && weekdays.isEmpty)) {
      throw ArgumentError(
        'Choose a valid repeat schedule within one year and 180 occurrences.',
      );
    }
    final custom = customDates.map(parseEventDate).toSet();
    if (frequency == 'custom' &&
        (custom.isEmpty ||
            custom.any((d) => d.isBefore(first) || d.isAfter(last)))) {
      throw ArgumentError('Custom dates must be within the repeat date range.');
    }
    final anchorMonday = first.subtract(Duration(days: first.weekday - 1));
    final result = <EventOccurrence>[];
    for (var day = 0; day <= days; day++) {
      final date = DateTime.utc(first.year, first.month, first.day + day);
      final week = date.difference(anchorMonday).inDays ~/ 7;
      final included = switch (frequency) {
        'daily' => true,
        'weekly' =>
          weekdays.contains(date.weekday) && week % intervalWeeks == 0,
        'custom' => custom.contains(date),
        _ => false,
      };
      if (!included) continue;
      final times =
          weekdayTimes[date.weekday] ??
          [startMinutes, endMinutes, endDayOffset];
      if (times.length != 3 ||
          times[0] < 0 ||
          times[0] >= 1440 ||
          times[1] < 0 ||
          times[1] >= 1440 ||
          times[2] < 0 ||
          times[2] > 1 ||
          times[1] + times[2] * 1440 <= times[0]) {
        throw ArgumentError(
          'Each session needs a valid start and end time (at most overnight).',
        );
      }
      final endDate = DateTime.utc(date.year, date.month, date.day + times[2]);
      final start = _wallTime(zone, date, times[0]);
      final end = _wallTime(zone, endDate, times[1]);
      if (!end.isAfter(start)) throw ArgumentError('End must follow start.');
      result.add(
        EventOccurrence(
          id: 'd${eventDateKey(date).replaceAll('-', '')}',
          start: start,
          end: end,
        ),
      );
      if (result.length == maxOccurrences) break;
    }
    if (result.isEmpty) throw ArgumentError('The schedule has no occurrences.');
    return List.unmodifiable(result);
  }
}

DateTime _wallTime(tz.Location zone, DateTime day, int minutes) {
  final local = tz.TZDateTime(
    zone,
    day.year,
    day.month,
    day.day,
    minutes ~/ 60,
    minutes % 60,
  );
  if (local.year != day.year ||
      local.month != day.month ||
      local.day != day.day ||
      local.hour != minutes ~/ 60 ||
      local.minute != minutes % 60) {
    throw ArgumentError(
      'A selected time does not exist during the daylight saving change. Choose another time.',
    );
  }
  return local.toUtc();
}

String eventDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime parseEventDate(String value) {
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || eventDateKey(date) != value) {
    throw ArgumentError('Invalid date: $value');
  }
  return date;
}

class EventSchedule {
  const EventSchedule({
    required this.timeZoneId,
    required this.rule,
    required this.occurrences,
    required this.firstOccurrenceId,
  });
  final String timeZoneId;
  final EventRecurrence rule;
  final List<EventOccurrence> occurrences;
  // Anchored when the series is created. Cancellation/removal never advances it.
  final String firstOccurrenceId;

  factory EventSchedule.generate(
    EventRecurrence rule,
    String zone, {
    EventSchedule? previous,
    DateTime? now,
  }) {
    final generated = rule.expand(zone);
    final instant = now ?? DateTime.now();
    final old = {
      for (final o in previous?.occurrences ?? <EventOccurrence>[]) o.id: o,
    };
    final history = old.values.where((o) => !o.start.isAfter(instant)).toList();
    final result = <EventOccurrence>[
      ...history,
      for (final o in generated)
        if (!history.any((h) => h.id == o.id))
          // Preserve explicit occurrence overrides until deliberately edited.
          old[o.id]?.overridden == true || old[o.id]?.canceled == true
              ? old[o.id]!
              : o,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (result.length > maxEventOccurrences) {
      throw ArgumentError(
        'History plus schedule exceeds 180 occurrences. Create a new series.',
      );
    }
    return EventSchedule(
      timeZoneId: zone,
      rule: rule,
      occurrences: List.unmodifiable(result),
      firstOccurrenceId: previous?.firstOccurrenceId ?? result.first.id,
    );
  }

  EventSchedule replaceOccurrences(List<EventOccurrence> value) =>
      EventSchedule(
        timeZoneId: timeZoneId,
        rule: rule,
        firstOccurrenceId: firstOccurrenceId,
        occurrences: List.unmodifiable(value),
      );

  Map<String, Object> toMap() => {
    'version': 1,
    'timeZoneId': timeZoneId,
    'rule': rule.toMap(),
    'firstOccurrenceId': firstOccurrenceId,
    'occurrences': occurrences.map((o) => o.toMap()).toList(),
  };
  static EventSchedule? tryParse(Object? value) {
    if (value == null) return null;
    try {
      final map = Map<String, dynamic>.from(value as Map);
      if (map['version'] != 1) {
        return null;
      }
      final items = (map['occurrences'] as List)
          .map(
            (o) => EventOccurrence.fromMap(Map<String, dynamic>.from(o as Map)),
          )
          .toList();
      if (items.isEmpty ||
          items.length > maxEventOccurrences ||
          items.map((o) => o.id).toSet().length != items.length ||
          items.any((o) => !o.end.isAfter(o.start))) {
        return null;
      }
      final rule = EventRecurrence.fromMap(
        Map<String, dynamic>.from(map['rule'] as Map),
      );
      if (!['daily', 'weekly', 'custom'].contains(rule.frequency)) {
        return null;
      }
      return EventSchedule(
        timeZoneId: map['timeZoneId'] as String,
        rule: rule,
        firstOccurrenceId: map['firstOccurrenceId'] as String,
        occurrences: List.unmodifiable(items),
      );
    } catch (_) {
      return null;
    }
  }
}

class EventReminders {
  const EventReminders({
    this.mode = 'first',
    this.offsetsMinutes = const [1440, 60],
  });
  const EventReminders.disabled() : mode = 'none', offsetsMinutes = const [];
  final String mode; // first, every, none
  final List<int> offsetsMinutes;
  Map<String, Object> toMap() {
    if (!['first', 'every', 'none'].contains(mode) ||
        offsetsMinutes.length > 5 ||
        offsetsMinutes.any((v) => ![10080, 4320, 1440, 120, 60].contains(v))) {
      throw ArgumentError('Invalid reminder settings.');
    }
    return {
      'mode': mode,
      'offsetsMinutes': offsetsMinutes.toSet().toList()..sort(),
    };
  }

  static EventReminders fromMap(Object? value) {
    try {
      if (value is! Map) return const EventReminders.disabled();
      final result = EventReminders(
        mode: value['mode'] as String,
        offsetsMinutes: List<int>.from(value['offsetsMinutes'] as List),
      );
      result.toMap();
      return result;
    } catch (_) {
      return const EventReminders.disabled();
    }
  }
}
