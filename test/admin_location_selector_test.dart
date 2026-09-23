import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/academy_announcement.dart';
import 'package:ota_cheshire_management_platform/models/academy_event.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student_profile.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_resources_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_location_controller.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';
import 'package:ota_cheshire_management_platform/widgets/admin/admin_location_selector.dart';

const _cheshire = AcademyLocation(
  id: 'cheshire',
  name: 'OTA Cheshire',
  timeZoneId: 'America/New_York',
  isActive: true,
);

const _chicago = AcademyLocation(
  id: 'chicago',
  name: 'OTA Chicago',
  timeZoneId: 'America/Chicago',
  isActive: true,
);

const _inactive = AcademyLocation(
  id: 'inactive',
  name: 'Closed Academy',
  timeZoneId: 'America/New_York',
  isActive: false,
);

void main() {
  setUp(() {
    initializeMockAppDataServiceForTests();
    const timeService = LocationTimeService();
    LocationTimeService.initialize();
    timeService.cacheTimeZone(_cheshire.id, _cheshire.timeZoneId);
    timeService.cacheTimeZone(_chicago.id, _chicago.timeZoneId);
  });

  testWidgets('Super Admin can open the selector from the header and profile', (
    tester,
  ) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    expect(_locationDropdown(), findsNothing);
    expect(find.byTooltip('Change academy location'), findsOneWidget);

    await tester.tap(find.byTooltip('Change academy location'));
    await tester.pumpAndSettle();
    expect(find.text('Admin data location'), findsOneWidget);
    expect(_locationDropdown(), findsOneWidget);

    await tester.tap(_locationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTA Chicago').last);
    await tester.pumpAndSettle();
    expect(controller.selectedLocationId, _chicago.id);

    await tester.tap(_locationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('All locations').last);
    await tester.pumpAndSettle();
    expect(controller.selectedLocationId, isNull);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: AdminProfileScreen()));
    expect(_locationDropdown(), findsOneWidget);
  });

  testWidgets('location Admin does not see a location selector', (
    tester,
  ) async {
    adminLocationController = AdminLocationController.forTesting(
      role: UserAccountRole.admin,
      locations: const [_cheshire],
      assignedLocationId: _cheshire.id,
    );
    final controller = adminLocationController;
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminProfileScreen()));

    expect(_locationDropdown(), findsNothing);
    expect(find.byTooltip('Change academy location'), findsNothing);
  });

  testWidgets('profile selection updates the controller and persists', (
    tester,
  ) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminProfileScreen()));

    await tester.tap(_locationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTA Chicago').last);
    await tester.pumpAndSettle();

    expect(controller.selectedLocationId, _chicago.id);

    await tester.pumpWidget(const MaterialApp(home: AdminStudentsScreen()));

    expect(find.byType(AdminStudentsScreen), findsOneWidget);
    expect(_locationDropdown(), findsNothing);
    expect(controller.selectedLocationId, _chicago.id);
    expect(find.text('OTA Chicago'), findsWidgets);
  });

  testWidgets('standard admin pages expose the selector from the header', (
    tester,
  ) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });
    const pages = <Widget>[
      AdminDashboardScreen(),
      AdminStudentsScreen(),
      AdminScheduleScreen(),
      AdminAnnouncementsScreen(),
      AdminEventsScreen(),
      AdminGeneralResourcesScreen(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(
        _locationDropdown(),
        findsNothing,
        reason: '${page.runtimeType} should not have an inline selector',
      );
      expect(find.byTooltip('Change academy location'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'Dashboard scopes all summaries when selecting switching and clearing',
    (tester) async {
      final controller = _useSuperAdminController();
      appDataService = _MultiLocationAppDataService();
      addTearDown(() {
        controller.dispose();
        initializeMockAppDataServiceForTests();
      });

      await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
      await tester.pumpAndSettle();

      _expectDashboardLocation(cheshire: true, chicago: true);
      expect(find.text('All locations'), findsOneWidget);

      controller.selectLocation(_cheshire.id);
      await tester.pump();
      _expectDashboardLocation(cheshire: true, chicago: false);

      controller.selectLocation(_chicago.id);
      await tester.pump();
      _expectDashboardLocation(cheshire: false, chicago: true);

      controller.clearSelection();
      await tester.pump();
      _expectDashboardLocation(cheshire: true, chicago: true);
      expect(find.text('All locations'), findsOneWidget);
    },
  );

  testWidgets(
    'Students scopes counts search empty state and location changes',
    (tester) async {
      final controller = _useSuperAdminController();
      appDataService = _MultiLocationAppDataService();
      addTearDown(() {
        controller.dispose();
        initializeMockAppDataServiceForTests();
      });

      await tester.pumpWidget(const MaterialApp(home: AdminStudentsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Cheshire Student'), findsOneWidget);
      expect(find.text('Chicago Student'), findsOneWidget);
      expect(find.text('Showing 2 students'), findsOneWidget);

      controller.selectLocation(_cheshire.id);
      await tester.pump();
      expect(find.text('Cheshire Student'), findsOneWidget);
      expect(find.text('Chicago Student'), findsNothing);
      expect(find.text('Showing 1 students'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search students or account holders'),
        'Chicago',
      );
      await tester.pump();
      expect(find.text('No students match this filter.'), findsOneWidget);

      controller.selectLocation(_chicago.id);
      await tester.pump();
      expect(find.text('Chicago Student'), findsOneWidget);
      expect(find.text('No students match this filter.'), findsNothing);

      controller.clearSelection();
      await tester.pump();
      expect(find.text('Chicago Student'), findsOneWidget);
      expect(find.text('Showing 1 students'), findsOneWidget);
    },
  );

  test('regular and Guest Admin location scope remains assigned', () {
    final regular = AdminLocationController.forTesting(
      role: UserAccountRole.admin,
      locations: const [_cheshire],
      assignedLocationId: _cheshire.id,
    );
    addTearDown(regular.dispose);
    expect(regular.includesLocation(_cheshire.id), isTrue);
    expect(regular.includesLocation(_chicago.id), isFalse);

    final guest = AdminLocationController.forTesting(
      role: UserAccountRole.guest,
      locations: const [AdminLocationController.guestDemoLocation],
      assignedLocationId: AdminLocationController.guestDemoLocation.id,
    )..setGuestDemoActive(true);
    addTearDown(guest.dispose);
    expect(
      guest.includesLocation(AdminLocationController.guestDemoLocation.id),
      isTrue,
    );
    expect(guest.includesLocation(_cheshire.id), isFalse);
  });
}

void _expectDashboardLocation({required bool cheshire, required bool chicago}) {
  for (final prefix in ['Class', 'Announcement', 'Event']) {
    expect(
      find.text('Cheshire $prefix'),
      cheshire ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('Chicago $prefix'),
      chicago ? findsOneWidget : findsNothing,
    );
  }
}

Finder _locationDropdown() => find.descendant(
  of: find.byType(AdminLocationSelector),
  matching: find.byType(DropdownButtonFormField<String>),
);

AdminLocationController _useSuperAdminController() {
  final controller = AdminLocationController.forTesting(
    role: UserAccountRole.superAdmin,
    locations: const [_cheshire, _chicago, _inactive],
  );
  adminLocationController = controller;
  return controller;
}

class _MultiLocationAppDataService extends MockAppDataService {
  _MultiLocationAppDataService();

  static final _now = DateTime.now();

  @override
  Map<int, List<ClassSession>> get schedule => {
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      weekday: [
        _session('cheshire-class', 'Cheshire Class', _cheshire.id),
        _session('chicago-class', 'Chicago Class', _chicago.id),
      ],
  };

  @override
  List<AcademyAnnouncement> get adminAnnouncements => [
    _announcement(
      'cheshire-announcement',
      'Cheshire Announcement',
      _cheshire.id,
    ),
    _announcement('chicago-announcement', 'Chicago Announcement', _chicago.id),
  ];

  @override
  List<AcademyEvent> get events => [
    _event('cheshire-event', 'Cheshire Event', _cheshire.id),
    _event('chicago-event', 'Chicago Event', _chicago.id),
  ];

  @override
  List<StudentProfile> get adminStudentProfiles => const [
    StudentProfile(
      id: 'cheshire-student',
      name: 'Cheshire Student',
      locationId: 'cheshire',
      belt: 'White',
      legacyAge: 10,
      stickerCount: 0,
      stickersRequired: 4,
      nextRank: 'White-Yellow',
      linkedUserId: 'cheshire-account',
    ),
    StudentProfile(
      id: 'chicago-student',
      name: 'Chicago Student',
      locationId: 'chicago',
      belt: 'Yellow',
      legacyAge: 11,
      stickerCount: 1,
      stickersRequired: 4,
      nextRank: 'Yellow-Green',
      linkedUserId: 'chicago-account',
    ),
  ];

  @override
  List<UserAccount> get adminUserAccounts => const [
    UserAccount(
      id: 'cheshire-account',
      firstName: 'Cheshire',
      lastName: 'Parent',
      email: 'cheshire@example.invalid',
      role: UserAccountRole.parent,
      linkedStudentProfileIds: ['cheshire-student'],
      locationId: 'cheshire',
    ),
    UserAccount(
      id: 'chicago-account',
      firstName: 'Chicago',
      lastName: 'Parent',
      email: 'chicago@example.invalid',
      role: UserAccountRole.parent,
      linkedStudentProfileIds: ['chicago-student'],
      locationId: 'chicago',
    ),
  ];

  static ClassSession _session(String id, String name, String locationId) {
    return ClassSession(
      id: id,
      className: name,
      classTypeId: id,
      locationId: locationId,
      startTime: DateTime(2026, 1, 1, 16),
      endTime: DateTime(2026, 1, 1, 16, 40),
      eligibleBelts: const ['White'],
      description: 'Test class',
    );
  }

  static AcademyAnnouncement _announcement(
    String id,
    String title,
    String locationId,
  ) {
    return AcademyAnnouncement(
      id: id,
      title: title,
      summary: title,
      body: title,
      announcementType: 'general',
      priority: 'general',
      status: 'published',
      audienceType: 'everyone',
      locationId: locationId,
      publishedAt: _now,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  static AcademyEvent _event(String id, String title, String locationId) {
    return AcademyEvent(
      id: id,
      title: title,
      description: title,
      locationId: locationId,
      eventType: 'specialEvent',
      startDateTime: _now.add(const Duration(days: 1)),
      endDateTime: _now.add(const Duration(days: 1, hours: 1)),
      isPublished: true,
      createdAt: _now,
      updatedAt: _now,
    );
  }
}
