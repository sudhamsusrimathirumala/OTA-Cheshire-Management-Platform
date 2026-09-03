import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_resources_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_location_controller.dart';
import 'package:ota_cheshire_management_platform/widgets/admin/admin_bottom_nav_bar.dart';
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
  setUp(initializeMockAppDataServiceForTests);

  testWidgets('Super Admin sees the location selector on Dashboard', (
    tester,
  ) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });

    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));

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

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminPageShell(
          selectedDestination: AdminNavDestination.dashboard,
          title: 'Dashboard',
          subtitle: 'Admin overview',
          child: Text('Dashboard content'),
        ),
      ),
    );

    expect(_locationDropdown(), findsNothing);
  });

  testWidgets('selection updates the controller and persists across pages', (
    tester,
  ) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: OtaRoutes.adminDashboard,
        routes: {
          OtaRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
          OtaRoutes.adminStudents: (_) => const AdminStudentsScreen(),
        },
      ),
    );

    await tester.tap(_locationDropdown());
    await tester.pumpAndSettle();
    await tester.tap(find.text('OTA Chicago').last);
    await tester.pumpAndSettle();

    expect(controller.selectedLocationId, _chicago.id);

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminStudentsScreen), findsOneWidget);
    expect(_locationDropdown(), findsOneWidget);
    expect(controller.selectedLocationId, _chicago.id);
    expect(find.text('OTA Chicago'), findsWidgets);
  });

  testWidgets('management pages show only the shared selector', (tester) async {
    final controller = _useSuperAdminController();
    addTearDown(() {
      controller.dispose();
      initializeMockAppDataServiceForTests();
    });
    const pages = <Widget>[
      AdminScheduleScreen(),
      AdminAnnouncementsScreen(),
      AdminEventsScreen(),
      AdminGeneralResourcesScreen(),
      AdminProfileScreen(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();
      expect(
        _locationDropdown(),
        findsOneWidget,
        reason: '${page.runtimeType} should have one location selector',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
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
