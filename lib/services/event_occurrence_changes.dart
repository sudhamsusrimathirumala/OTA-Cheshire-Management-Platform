import 'package:timezone/timezone.dart' as tz;
import '../models/event_schedule.dart';
import 'location_time_service.dart';

List<EventOccurrence> changeEventOccurrences(
  List<EventOccurrence> occurrences,
  String selectedId, {
  required DateTime start,
  required DateTime end,
  required bool following,
  required bool cancel,
  required String locationId,
  DateTime? now,
}) {
  final instant = now ?? DateTime.now();
  final selected = occurrences.firstWhere((o) => o.id == selectedId);
  if (!selected.start.isAfter(instant)) {
    throw ArgumentError('Started sessions cannot be rewritten.');
  }
  if (!cancel && (!start.isAfter(instant) || !end.isAfter(start))) {
    throw ArgumentError('Select valid future session times.');
  }
  final service = const LocationTimeService();
  final original = service.toLocationTime(selected.start, locationId);
  final localStart = service.toLocationTime(start, locationId);
  final localEnd = service.toLocationTime(end, locationId);
  final dateShift =
      DateTime.utc(localStart.year, localStart.month, localStart.day)
          .difference(DateTime.utc(original.year, original.month, original.day))
          .inDays;
  final endShift = DateTime.utc(localEnd.year, localEnd.month, localEnd.day)
      .difference(
        DateTime.utc(localStart.year, localStart.month, localStart.day),
      )
      .inDays;
  return List.unmodifiable(
    occurrences.map((o) {
      if (o.id != selectedId &&
          !(following &&
              !o.start.isBefore(selected.start) &&
              o.start.isAfter(instant))) {
        return o;
      }
      if (cancel) return o.copyWith(canceled: true);
      if (o.id == selectedId) return o.copyWith(start: start, end: end);
      final date = service.toLocationTime(o.start, locationId);
      final zone = service.locationFor(locationId);
      final a = tz.TZDateTime(
        zone,
        date.year,
        date.month,
        date.day + dateShift,
        localStart.hour,
        localStart.minute,
      );
      final b = tz.TZDateTime(
        zone,
        date.year,
        date.month,
        date.day + dateShift + endShift,
        localEnd.hour,
        localEnd.minute,
      );
      if (a.hour != localStart.hour ||
          a.minute != localStart.minute ||
          b.hour != localEnd.hour ||
          b.minute != localEnd.minute ||
          !b.isAfter(a) ||
          !a.isAfter(instant)) {
        throw ArgumentError(
          'A future session has an invalid daylight saving time. Edit it individually.',
        );
      }
      return o.copyWith(start: a.toUtc(), end: b.toUtc());
    }),
  );
}
