import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notifications_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  for (final size in const [Size(320, 568), Size(360, 640)]) {
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
          const StudentDashboardScreen(),
          const NotificationsScreen(),
          const ProfileScreen(managementAvailableOverride: false),
          const AdminStudentsScreen(),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
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
      });
    }
  }
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
