import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/screens/curriculum_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notification_detail_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notifications_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/signup_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5]) {
      testWidgets('primary routes fit ${size.width}x${size.height} at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in <Widget>[
          const LoginScreen(),
          const SignupScreen(),
          const StudentDashboardScreen(),
          const ScheduleScreen(),
          const CurriculumScreen(),
          const NotificationsScreen(),
          NotificationDetailScreen(
            notification: appDataService.notifications.first,
          ),
          const ProfileScreen(managementAvailableOverride: false),
          const AdminStudentsScreen(),
          const AdminScheduleScreen(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          _expectNoFlutterLayoutErrors(tester, screen.runtimeType.toString());
        }

        await _pumpAtSize(
          tester,
          const AdminStudentsScreen(),
          size: size,
          scale: scale,
        );
        final studentName = appDataService.adminStudentProfiles.first.name;
        await tester.ensureVisible(find.text(studentName).first);
        await tester.tap(find.text(studentName).first);
        await tester.pumpAndSettle();
        _expectNoFlutterLayoutErrors(tester, 'Student detail sheet');

        await _pumpAtSize(
          tester,
          const AdminScheduleScreen(),
          size: size,
          scale: scale,
        );
        await tester.ensureVisible(find.text('Add Class').first);
        await tester.tap(find.text('Add Class').first);
        await tester.pumpAndSettle();
        _expectNoFlutterLayoutErrors(tester, 'Add Class sheet');
      });
    }
  }
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required double scale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoFlutterLayoutErrors(WidgetTester tester, String screen) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    final text = error.toString();
    if (text.contains('RenderFlex') && text.contains('overflowed')) {
      fail('$screen RenderFlex overflow: $text');
    }
    fail('Unexpected Flutter error: $text');
  }
}
