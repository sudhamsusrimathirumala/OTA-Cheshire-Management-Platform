import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/guest/guest_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/guest/guest_experience_controller.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';

void main() {
  setUp(() {
    initializeGuestDemoAppDataServiceForTests();
  });

  tearDown(() {
    setGuestDemoActive(false);
  });

  Widget guestTestApp() => MaterialApp(
    key: UniqueKey(),
    home: const GuestDashboardScreen(),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => settings.name == '/admin/dashboard'
          ? const AdminDashboardScreen()
          : StudentDashboardScreen(
              selectProfile: guestDemoAppDataService.selectProfile,
            ),
    ),
  );

  testWidgets('chooser opens the real admin and member dashboard layouts', (
    tester,
  ) async {
    await tester.pumpWidget(guestTestApp());

    await tester.tap(find.text('Admin View'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(guestExperienceController.mode, GuestViewMode.admin);

    guestExperienceController.reset();
    await tester.pumpWidget(guestTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student View'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentDashboardScreen), findsOneWidget);
    expect(find.textContaining('Casey'), findsWidgets);
    expect(guestExperienceController.mode, GuestViewMode.student);
  });

  testWidgets('guest banner remains usable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                GuestModeBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Reviewer demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest banner view chooser is a selectable navigation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: GuestModeBanner()),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const GuestDashboardScreen(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Switch reviewer view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View chooser'));
    await tester.pumpAndSettle();

    expect(find.byType(GuestDashboardScreen), findsOneWidget);
    expect(find.text('Choose an experience'), findsOneWidget);
  });

  testWidgets(
    'guest menu repeatedly switches real views and profiles without signing out',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      Widget shell(Widget child) => GuestModeShell(child: child);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: shell(const GuestDashboardScreen()),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => shell(switch (settings.name) {
              OtaRoutes.adminDashboard => const AdminDashboardScreen(),
              OtaRoutes.adminProfile => const AdminProfileScreen(),
              OtaRoutes.profile => const ProfileScreen(),
              OtaRoutes.guestDashboard => const GuestDashboardScreen(),
              _ => StudentDashboardScreen(
                selectProfile: guestDemoAppDataService.selectProfile,
              ),
            }),
          ),
        ),
      );

      Future<void> selectView(String label) async {
        await tester.tap(find.byTooltip('Switch reviewer view'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await selectView('Admin View');
      expect(guestExperienceController.mode, GuestViewMode.admin);
      expect(
        guestDemoAppDataService.currentUserAccount.displayName,
        'Jordan Lee',
      );
      navigatorKey.currentState!.pushNamed(OtaRoutes.adminProfile);
      await tester.pumpAndSettle();
      expect(find.byType(AdminProfileScreen), findsOneWidget);
      expect(find.text('Jordan Lee'), findsOneWidget);

      await selectView('Student View');
      expect(guestExperienceController.mode, GuestViewMode.student);
      expect(
        guestDemoAppDataService.currentUserAccount.displayName,
        'Casey Rowan',
      );
      navigatorKey.currentState!.pushNamed(OtaRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining('Casey'), findsWidgets);

      await selectView('Parent View');
      expect(guestExperienceController.mode, GuestViewMode.parent);
      expect(
        guestDemoAppDataService.currentUserAccount.displayName,
        'Alex Rowan',
      );
      navigatorKey.currentState!.pushNamed(OtaRoutes.profile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.textContaining('Alex'), findsWidgets);

      await selectView('Admin View');
      await selectView('Parent View');
      expect(isGuestDemoActive, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'guest session stage cannot fall through to a standard data service',
    () {
      setGuestDemoActive(false);
      appDataService = MockAppDataService();

      expect(isGuestDemoActive, isTrue);
      expect(appDataService, same(guestDemoAppDataService));
      expect(adminWriteService, same(guestDemoAppDataService));
    },
  );

  test('guest admin writer is the in-memory service', () {
    expect(adminWriteService, same(guestDemoAppDataService));
  });
}
