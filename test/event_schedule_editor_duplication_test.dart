import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/event_schedule.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/widgets/admin/event_schedule_editor.dart';

void main() {
  const locationId = 'ota-cheshire';
  final location = const LocationTimeService();

  setUp(() => LocationTimeService.initialize());

  EventSchedule sourceSchedule({
    String frequency = 'daily',
    List<String> customDates = const [],
  }) {
    final source = EventSchedule.generate(
      EventRecurrence(
        frequency: frequency,
        startDate: '2027-01-04',
        endDate: '2027-01-06',
        startMinutes: 540,
        endMinutes: 900,
        customDates: customDates,
      ),
      location.timeZoneIdFor(locationId),
      now: DateTime.utc(2026),
    );
    // A copied series must not inherit cancellation and occurrence history.
    return source.replaceOccurrences([
      for (final occurrence in source.occurrences)
        occurrence.copyWith(canceled: true),
    ]);
  }

  testWidgets('duplicating a past daily series rebases its repeat-through date', (
    tester,
  ) async {
    final key = GlobalKey<EventScheduleEditorState>();
    final source = sourceSchedule();

    Widget editor({DateTime? start, DateTime? end}) => MaterialApp(
      home: Scaffold(
        body: EventScheduleEditor(
          key: key,
          locationId: locationId,
          initial: source,
          duplicate: true,
          start: start,
          end: end,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(editor());
    expect(() => key.currentState!.buildSchedule(), throwsArgumentError);

    await tester.pumpWidget(
      editor(
        start: DateTime.utc(2028, 1, 4, 14),
        end: DateTime.utc(2028, 1, 4, 20),
      ),
    );
    await tester.pumpAndSettle();

    final copy = key.currentState!.buildSchedule()!;
    expect(copy.rule.startDate, '2028-01-04');
    expect(copy.rule.endDate, '2028-01-06');
    expect(copy.occurrences, hasLength(3));
    expect(copy.occurrences.every((o) => !o.canceled && !o.overridden), isTrue);
    expect(copy.occurrences.first.start.year, 2028);

    // Changing only the time must not drift the duplicated date range.
    await tester.pumpWidget(
      editor(
        start: DateTime.utc(2028, 1, 4, 15),
        end: DateTime.utc(2028, 1, 4, 21),
      ),
    );
    expect(key.currentState!.buildSchedule()!.rule.endDate, '2028-01-06');
  });

  testWidgets('copied custom dates shift with the new start date', (tester) async {
    final key = GlobalKey<EventScheduleEditorState>();
    final source = sourceSchedule(
      frequency: 'custom',
      customDates: const ['2027-01-04', '2027-01-06'],
    );

    Widget editor({DateTime? start, DateTime? end}) => MaterialApp(
      home: Scaffold(
        body: EventScheduleEditor(
          key: key,
          locationId: locationId,
          initial: source,
          duplicate: true,
          start: start,
          end: end,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(editor());
    await tester.pumpWidget(
      editor(
        start: DateTime.utc(2028, 2, 7, 14),
        end: DateTime.utc(2028, 2, 7, 20),
      ),
    );
    await tester.pumpAndSettle();

    final copy = key.currentState!.buildSchedule()!;
    expect(copy.rule.startDate, '2028-02-07');
    expect(copy.rule.endDate, '2028-02-09');
    expect(copy.rule.customDates, ['2028-02-07', '2028-02-09']);
    expect(copy.occurrences, hasLength(2));
    expect(copy.occurrences.every((o) => !o.canceled && !o.overridden), isTrue);
  });
}
