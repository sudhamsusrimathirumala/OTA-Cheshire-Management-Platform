import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_resources_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/guest/guest_demo_app_data_service.dart';
import 'package:ota_cheshire_management_platform/widgets/location_date_time_field.dart';
import 'package:ota_cheshire_management_platform/models/event_schedule.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_service.dart';

void main() {
  setUp(initializeGuestDemoAppDataServiceForTests);
  testWidgets('duplicated announcement removes selected students by ID, not name', (
    tester,
  ) async {
    final first = await guestDemoAppDataService.createChild(
      StudentProfileInput(
        firstName: 'Same',
        lastName: 'Name',
        dateOfBirth: DateTime.utc(2017, 3, 1),
        beltRank: 'White',
      ),
    );
    final second = await guestDemoAppDataService.createChild(
      StudentProfileInput(
        firstName: 'Same',
        lastName: 'Name',
        dateOfBirth: DateTime.utc(2017, 3, 1),
        beltRank: 'White',
      ),
    );
    await guestDemoAppDataService.saveAnnouncement(
      AnnouncementWriteData(
        title: 'Identical names targeted',
        summary: 'Original',
        body: 'Only selected profiles should be notified.',
        announcementType: 'general',
        priority: 'general',
        status: 'draft',
        audienceType: 'students',
        targetStudentProfileIds: [first, second],
        locationId: guestDemoLocationId,
        requiresAction: false,
      ),
    );
    final source = guestDemoAppDataService.adminAnnouncements.firstWhere(
      (a) => a.title == 'Identical names targeted',
    );
    await tester.pumpWidget(
      const MaterialApp(home: AdminAnnouncementsScreen()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duplicate').first);
    await tester.tap(find.text('Duplicate').first);
    await tester.pumpAndSettle();

    final removeButtons = find.byTooltip('Remove');
    expect(removeButtons, findsNWidgets(2));
    await tester.ensureVisible(removeButtons.last);
    await tester.tap(removeButtons.last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Draft'));
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();

    final copy = guestDemoAppDataService.adminAnnouncements.firstWhere(
      (a) => a.id != source.id && a.title == source.title,
    );
    expect(copy.targetStudentProfileIds, contains(first));
    expect(copy.targetStudentProfileIds, isNot(contains(second)));
    expect(source.targetStudentProfileIds, containsAll([first, second]));
  });

  for (final status in ['draft', 'published', 'archived']) {
    testWidgets('announcement $status duplicates as independent draft', (
      tester,
    ) async {
      await guestDemoAppDataService.saveAnnouncement(
        AnnouncementWriteData(
          title: 'Copy announcement',
          summary: 'Summary',
          body: 'Body',
          announcementType: 'general',
          priority: 'important',
          status: status,
          locationId: guestDemoLocationId,
          requiresAction: false,
        ),
      );
      final original = guestDemoAppDataService.adminAnnouncements.firstWhere(
        (a) => a.title == 'Copy announcement',
      );
      await tester.pumpWidget(
        const MaterialApp(home: AdminAnnouncementsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Duplicate').first);
      await tester.tap(find.text('Duplicate').first);
      await tester.pumpAndSettle();
      expect(find.text('Publish Announcement'), findsNothing);
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      final copies = guestDemoAppDataService.adminAnnouncements
          .where((a) => a.title == original.title)
          .toList();
      expect(copies, hasLength(2));
      final copy = copies.firstWhere((a) => a.id != original.id);
      expect(copy.isDraft, isTrue);
      expect(copy.publishedAt, isNull);
      expect(copy.body, original.body);
      expect(
        guestDemoAppDataService.adminAnnouncements
            .firstWhere((a) => a.id == original.id)
            .status,
        original.status,
      );
    });
  }
  testWidgets(
    'duplicate recurring event copies rule/settings but regenerates sessions after date review',
    (tester) async {
      for (final event in guestDemoAppDataService.events) {
        await guestDemoAppDataService.deleteEvent(event.id);
      }
      const rule = EventRecurrence(
        frequency: 'daily',
        startDate: '2027-01-04',
        endDate: '2027-01-06',
        startMinutes: 540,
        endMinutes: 900,
      );
      final zone = const LocationTimeService().timeZoneIdFor(
        guestDemoLocationId,
      );
      final originalSchedule = EventSchedule.generate(rule, zone)
          .replaceOccurrences(
            rule.expand(zone).map((o) => o.copyWith(canceled: true)).toList(),
          );
      await guestDemoAppDataService.saveEvent(
        EventWriteData(
          title: 'Recurring source',
          description: 'Details',
          locationId: guestDemoLocationId,
          eventType: 'summerCamp',
          startDateTime: originalSchedule.occurrences.first.start,
          endDateTime: originalSchedule.occurrences.last.end,
          isPublished: true,
          schedule: originalSchedule,
          reminders: const EventReminders(
            mode: 'every',
            offsetsMinutes: [1440, 60],
          ),
        ),
      );
      final source = guestDemoAppDataService.events.single;
      await tester.pumpWidget(const MaterialApp(home: AdminEventsScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Duplicate'));
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<LocationDateTimeField>(find.byType(LocationDateTimeField))
          .toList();
      fields[0].onChanged(DateTime.utc(2027, 1, 5, 14));
      fields[1].onChanged(DateTime.utc(2027, 1, 5, 20));
      await tester.pump();
      expect(find.text('Every occurrence'), findsWidgets);
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      final copy = guestDemoAppDataService.events.firstWhere(
        (e) => e.id != source.id,
      );
      expect(copy.isPublished, isFalse);
      expect(copy.schedule!.rule.frequency, 'daily');
      // Copying the first session one day later shifts the whole series,
      // rather than truncating the final day from the original date range.
      expect(copy.schedule!.rule.startDate, '2027-01-05');
      expect(copy.schedule!.rule.endDate, '2027-01-07');
      expect(copy.schedule!.occurrences, hasLength(3));
      expect(
        copy.schedule!.occurrences.every((o) => !o.canceled && !o.overridden),
        isTrue,
      );
      expect(
        copy.schedule!.firstOccurrenceId,
        isNot(source.schedule!.firstOccurrenceId),
      );
      expect(copy.reminders.mode, 'every');
      expect(copy.reminders.offsetsMinutes, [1440, 60]);
      expect(
        guestDemoAppDataService.events.firstWhere((e) => e.id == source.id),
        same(source),
      );
    },
  );
  for (final status in ['draft', 'archived']) {
    testWidgets('duplicate $status resource resets lifecycle', (tester) async {
      for (final resource in guestDemoAppDataService.resources) {
        await guestDemoAppDataService.deleteResource(resource.id);
      }
      await guestDemoAppDataService.saveResource(
        ResourceWriteData(
          title: 'Source',
          description: 'Keep',
          category: 'registration',
          linkUrl: 'https://example.com/form',
          locationId: guestDemoLocationId,
          isPublished: status == 'archived',
          isArchived: status == 'archived',
        ),
      );
      final source = guestDemoAppDataService.resources.single;
      await tester.pumpWidget(
        const MaterialApp(home: AdminGeneralResourcesScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(status == 'draft' ? 'Draft' : 'Archived'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Resource actions'));
      await tester.tap(find.byTooltip('Resource actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      final copy = guestDemoAppDataService.resources.firstWhere(
        (e) => e.id != source.id,
      );
      expect(copy.isPublished, isFalse);
      expect(copy.isArchived, isFalse);
      expect(copy.linkUrl, source.linkUrl);
      expect(
        guestDemoAppDataService.resources.firstWhere((e) => e.id == source.id),
        same(source),
      );
    });
  }
  for (final historical in [false, true]) {
    testWidgets(
      'duplicate ${historical ? 'historical' : 'draft'} event requires new dates and resets publication',
      (tester) async {
        for (final event in guestDemoAppDataService.events) {
          await guestDemoAppDataService.deleteEvent(event.id);
        }
        await guestDemoAppDataService.saveEvent(
          EventWriteData(
            title: 'Source event',
            description: 'Keep',
            locationId: guestDemoLocationId,
            eventType: 'seminar',
            startDateTime: DateTime.utc(historical ? 2024 : 2027, 1, 1, 14),
            endDateTime: DateTime.utc(historical ? 2024 : 2027, 1, 1, 20),
            isPublished: historical,
          ),
        );
        final source = guestDemoAppDataService.events.single;
        await tester.pumpWidget(const MaterialApp(home: AdminEventsScreen()));
        await tester.pumpAndSettle();
        await tester.tap(find.text(historical ? 'Past' : 'Draft'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Duplicate'));
        await tester.tap(find.text('Duplicate'));
        await tester.pumpAndSettle();
        final fields = tester
            .widgetList<LocationDateTimeField>(
              find.byType(LocationDateTimeField),
            )
            .toList();
        expect(fields[0].value, isNull);
        fields[0].onChanged(DateTime.utc(2027, 2, 1, 14));
        fields[1].onChanged(DateTime.utc(2027, 2, 1, 20));
        await tester.pump();
        await tester.ensureVisible(find.text('Save Draft'));
        await tester.tap(find.text('Save Draft'));
        await tester.pumpAndSettle();
        final copy = guestDemoAppDataService.events.firstWhere(
          (e) => e.id != source.id,
        );
        expect(copy.isPublished, isFalse);
        expect(copy.createdAt.isBefore(source.createdAt), isFalse);
        expect(copy.description, source.description);
        expect(copy.startDateTime, DateTime.utc(2027, 2, 1, 14));
        expect(
          guestDemoAppDataService.events.firstWhere((e) => e.id == source.id),
          same(source),
        );
      },
    );
  }
  testWidgets(
    'resource duplicate keeps link, resets lifecycle and leaves source intact',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminGeneralResourcesScreen()),
      );
      await tester.pumpAndSettle();
      final before = guestDemoAppDataService.resources;
      await tester.ensureVisible(find.byTooltip('Resource actions').first);
      await tester.tap(find.byTooltip('Resource actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('Publish Resource'), findsNothing);
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      final copy = guestDemoAppDataService.resources.firstWhere(
        (r) => !before.any((old) => old.id == r.id),
      );
      final source = before.firstWhere((r) => r.title == copy.title);
      expect(copy.isPublished, isFalse);
      expect(copy.isArchived, isFalse);
      expect(copy.linkUrl, source.linkUrl);
      expect(
        guestDemoAppDataService.resources.firstWhere((r) => r.id == source.id),
        same(source),
      );
    },
  );
  testWidgets('event duplicate requires dates, can only save a new draft', (
    tester,
  ) async {
    final before = guestDemoAppDataService.events;
    await tester.pumpWidget(const MaterialApp(home: AdminEventsScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Duplicate').first);
    await tester.tap(find.text('Duplicate').first);
    await tester.pumpAndSettle();
    expect(find.text('Publish Event'), findsNothing);
    final start = tester
        .widgetList<LocationDateTimeField>(find.byType(LocationDateTimeField))
        .first;
    expect(start.value, isNull);
    start.onChanged(DateTime.utc(2027, 1, 1, 15));
    await tester.pump();
    tester
        .widgetList<LocationDateTimeField>(find.byType(LocationDateTimeField))
        .elementAt(1)
        .onChanged(DateTime.utc(2027, 1, 1, 17));
    await tester.pump();
    await tester.ensureVisible(find.text('Save Draft'));
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();
    final copy = guestDemoAppDataService.events.firstWhere(
      (e) => !before.any((old) => old.id == e.id),
    );
    expect(copy.isPublished, isFalse);
    expect(copy.isArchived, isFalse);
    expect(before.any((e) => e.title == copy.title), isTrue);
    expect(
      guestDemoAppDataService.events.firstWhere((e) => e.id == before.first.id),
      same(before.first),
    );
  });
}
