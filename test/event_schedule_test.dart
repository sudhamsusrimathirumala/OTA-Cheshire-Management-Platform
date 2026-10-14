import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_event.dart';
import 'package:ota_cheshire_management_platform/models/event_schedule.dart';
import 'package:ota_cheshire_management_platform/screens/events_screen.dart';
import 'package:ota_cheshire_management_platform/services/event_occurrence_changes.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/push_notification_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';

void main() {
  test(
    'cold/authenticated navigation retains occurrence and distinguishes reminder offsets',
    () {
      final pending = PendingPushDestination();
      PushDestination destination(String occurrence, String reminder) =>
          PushDestination(
            type: PushContentType.event,
            contentId: 'series',
            locationId: 'north',
            occurrenceId: occurrence,
            reminderId: reminder,
          );
      final first = destination('a', 'day-before');
      pending.queue(first);
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.signedOut,
          memberLocationId: null,
          navigatorReady: true,
        ),
        isNull,
      );
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'other',
          navigatorReady: true,
        ),
        isNull,
      );
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'north',
          navigatorReady: true,
        ),
        same(first),
      );
      final later = destination('a', 'hour-before');
      pending.queue(later);
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'north',
          navigatorReady: true,
        ),
        same(later),
      );
      final next = destination('b', 'next-hour');
      pending.queue(next);
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'north',
          navigatorReady: true,
        ),
        same(next),
      );
      expect(PushDestination.tryDecode(next.encode())!.reminderId, 'next-hour');
    },
  );
  const zone = 'America/New_York';
  const location = 'north';
  final now = DateTime.utc(2026, 1, 1);
  setUp(() => const LocationTimeService().cacheTimeZone(location, zone));
  EventRecurrence rule({
    String frequency = 'daily',
    String start = '2027-01-04',
    String end = '2027-01-15',
    List<int> weekdays = const [],
    int interval = 1,
    List<String> custom = const [],
    int startMinutes = 540,
    int endMinutes = 900,
    int endDay = 0,
    Map<int, List<int>> times = const {},
    int count = 180,
  }) => EventRecurrence(
    frequency: frequency,
    startDate: start,
    endDate: end,
    weekdays: weekdays,
    intervalWeeks: interval,
    customDates: custom,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    endDayOffset: endDay,
    weekdayTimes: times,
    maxOccurrences: count,
  );
  AcademyEvent event(EventSchedule? schedule) => AcademyEvent(
    id: 'series',
    title: 'Camp',
    description: 'Training',
    locationId: location,
    eventType: 'summerCamp',
    startDateTime: schedule?.occurrences.first.start ?? DateTime.utc(2027),
    endDateTime: schedule?.occurrences.last.end ?? DateTime.utc(2027, 1, 1, 1),
    isPublished: true,
    createdAt: now,
    updatedAt: now,
    schedule: schedule,
  );

  test(
    'daily, multiweek selected weekdays, every N weeks and count are bounded',
    () {
      expect(rule().expand(zone), hasLength(12));
      expect(
        rule(frequency: 'weekly', weekdays: [1, 2, 3, 4, 5]).expand(zone),
        hasLength(10),
      );
      expect(
        rule(
          frequency: 'weekly',
          weekdays: [2, 4],
          end: '2027-02-14',
        ).expand(zone),
        hasLength(12),
      );
      expect(
        rule(
          frequency: 'weekly',
          weekdays: [2, 4],
          interval: 2,
          end: '2027-02-14',
        ).expand(zone),
        hasLength(6),
      );
      expect(rule(count: 3).expand(zone), hasLength(3));
      expect(rule(end: '2027-12-31').expand(zone), hasLength(180));
      expect(() => rule(end: '2028-01-05').expand(zone), throwsArgumentError);
      expect(() => rule(frequency: 'weekly').expand(zone), throwsArgumentError);
    },
  );
  test('custom dates deduplicate, validate and apply weekday time ranges', () {
    final result = rule(
      frequency: 'custom',
      custom: ['2027-01-04', '2027-01-08', '2027-01-04'],
      times: {
        5: [1020, 1140, 0],
      },
    ).expand(zone);
    expect(result, hasLength(2));
    expect(
      const LocationTimeService()
          .toLocationTime(result.last.start, location)
          .hour,
      17,
    );
    expect(
      () => rule(frequency: 'custom', custom: ['2027-02-01']).expand(zone),
      throwsArgumentError,
    );
    expect(() => parseEventDate('2027-02-30'), throwsArgumentError);
  });
  test(
    'wall clocks stay constant across DST and overnight sessions remain separate',
    () {
      final spring = rule(start: '2027-03-13', end: '2027-03-15').expand(zone);
      expect(spring[1].start.difference(spring[0].start).inHours, 23);
      final fall = rule(start: '2027-11-06', end: '2027-11-08').expand(zone);
      expect(fall[1].start.difference(fall[0].start).inHours, 25);
      final overnight = rule(
        start: '2027-01-04',
        end: '2027-01-05',
        startMinutes: 1320,
        endMinutes: 60,
        endDay: 1,
      ).expand(zone);
      expect(overnight.first.end.difference(overnight.first.start).inHours, 3);
      expect(
        () => rule(
          start: '2027-03-14',
          end: '2027-03-14',
          startMinutes: 150,
        ).expand(zone),
        throwsArgumentError,
      );
      expect(
        rule(
          start: '2027-11-07',
          end: '2027-11-07',
          startMinutes: 90,
        ).expand(zone).first.start,
        rule(
          start: '2027-11-07',
          end: '2027-11-07',
          startMinutes: 90,
        ).expand(zone).first.start,
      );
      expect(
        rule()
            .expand('America/Chicago')
            .first
            .start
            .difference(rule().expand(zone).first.start)
            .inHours,
        1,
      );
    },
  );
  test(
    'stable anchor, one/following scope, history and entire-series regeneration',
    () {
      final schedule = EventSchedule.generate(rule(), zone, now: now);
      final first = schedule.occurrences.first;
      final canceled = schedule.replaceOccurrences(
        changeEventOccurrences(
          schedule.occurrences,
          first.id,
          start: first.start,
          end: first.end,
          following: false,
          cancel: true,
          locationId: location,
          now: now,
        ),
      );
      expect(canceled.occurrences.where((o) => o.canceled), hasLength(1));
      final regenerated = EventSchedule.generate(
        rule(startMinutes: 600),
        zone,
        previous: canceled,
        now: now,
      );
      expect(regenerated.firstOccurrenceId, first.id);
      expect(regenerated.occurrences.first.canceled, isTrue);
      expect(
        regenerated.occurrences[1].start.hour,
        schedule.occurrences[1].start.hour + 1,
      );
      final moved = changeEventOccurrences(
        schedule.occurrences,
        schedule.occurrences[1].id,
        start: schedule.occurrences[1].start.add(const Duration(hours: 1)),
        end: schedule.occurrences[1].end.add(const Duration(hours: 1)),
        following: true,
        cancel: false,
        locationId: location,
        now: now,
      );
      expect(moved.first.start, first.start);
      expect(
        moved.last.start,
        schedule.occurrences.last.start.add(const Duration(hours: 1)),
      );
      final history = EventSchedule.generate(
        rule(startMinutes: 600),
        zone,
        previous: schedule,
        now: first.end.add(const Duration(minutes: 1)),
      );
      expect(history.occurrences.first.start, first.start);
      expect(
        () => changeEventOccurrences(
          schedule.occurrences,
          first.id,
          start: first.start,
          end: first.end,
          following: false,
          cancel: true,
          locationId: location,
          now: first.end,
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'series roundtrip, member calendar, canceled navigation and legacy compatibility',
    () {
      final schedule = EventSchedule.generate(
        rule(frequency: 'weekly', weekdays: [1, 3, 5]),
        zone,
        now: now,
      );
      expect(
        EventSchedule.tryParse(schedule.toMap())!.toMap(),
        schedule.toMap(),
      );
      final series = event(schedule);
      expect(
        eventsForAcademyDate([
          series,
        ], date: DateTime(2027, 1, 4)).single.endDateTime,
        schedule.occurrences.first.end,
      );
      expect(eventOccursOnAcademyDate(series, DateTime(2027, 1, 5)), isFalse);
      expect(
        visibleStudentEventById(
          [series],
          eventId: 'series',
          locationId: 'other',
        ),
        isNull,
      );
      final canceled = event(
        schedule.replaceOccurrences(
          schedule.occurrences.map((o) => o.copyWith(canceled: true)).toList(),
        ),
      );
      expect(
        eventsForAcademyDate([canceled], date: DateTime(2027, 1, 4)),
        isEmpty,
      );
      expect(
        visibleStudentEventById(
          [canceled],
          eventId: 'series',
          locationId: location,
          occurrenceId: schedule.firstOccurrenceId,
        ),
        isNull,
      );
      final legacy = academyEventFromFirestoreData('legacy', {
        'title': 'Old',
        'locationId': location,
        'startDateTime': DateTime.utc(2027),
        'isPublished': true,
      });
      expect(legacy!.occurrences, hasLength(1));
      expect(legacy.reminders.mode, 'none');
      final payload = PushDestination(
        type: PushContentType.event,
        contentId: 'series',
        locationId: location,
        occurrenceId: schedule.firstOccurrenceId,
      );
      expect(
        PushDestination.tryDecode(payload.encode())!.occurrenceId,
        schedule.firstOccurrenceId,
      );
    },
  );
  test(
    'reminder settings and event writes preserve registration at series scope',
    () {
      final schedule = EventSchedule.generate(rule(), zone, now: now);
      final data = EventWriteData(
        title: 'Camp',
        description: 'Details',
        locationId: location,
        eventType: 'summerCamp',
        startDateTime: schedule.occurrences.first.start,
        endDateTime: schedule.occurrences.last.end,
        isPublished: false,
        schedule: schedule,
        reminders: const EventReminders(),
        linkedResourceIds: ['form'],
        primaryRegistrationResourceId: 'form',
        registrationDeadline: DateTime.utc(2026, 12, 1),
      );
      final fields = eventWriteFields(data, now: now);
      expect(fields['reminders'], {
        'mode': 'first',
        'offsetsMinutes': [60, 1440],
      });
      expect(fields['linkedResourceIds'], ['form']);
      expect((fields['eventSchedule'] as Map)['occurrences'], hasLength(12));
      expect(
        () => const EventReminders(offsetsMinutes: [-1]).toMap(),
        throwsArgumentError,
      );
    },
  );
}
