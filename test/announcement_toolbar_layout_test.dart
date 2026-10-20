import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';

void main() {
  setUp(initializeGuestDemoAppDataServiceForTests);

  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    testWidgets('announcement toolbar stacks at width $width and double text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const AdminAnnouncementsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final heading = find.text('Family-facing announcement management');
      final create = find.widgetWithText(FilledButton, 'Create Announcement');
      expect(tester.getSize(heading).width, greaterThan(width * 0.65));
      expect(
        tester.getTopLeft(create).dy,
        greaterThan(tester.getBottomLeft(heading).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Save Draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
