import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/guest/guest_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/guest/guest_experience_controller.dart';

void main() {
  setUp(initializeGuestDemoAppDataServiceForTests);

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

  test('guest admin writer is the in-memory service', () {
    expect(adminWriteService, same(guestDemoAppDataService));
  });
}
