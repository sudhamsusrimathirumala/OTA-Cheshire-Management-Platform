import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';

void main() {
  setUp(() {
    initializeMockAppDataServiceForTests();
    appDataService = _ShortClassAppDataService();
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      testWidgets('schedule fits short and overlapping classes at '
          '${size.width}x${size.height} and ${scale}x text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: ScheduleScreen(initialDate: DateTime(2026, 9, 14)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        _expectNoFlutterErrors(tester, 'day view');

        final shortClass = find.byKey(
          const ValueKey('schedule-class-short-15'),
        );
        expect(shortClass, findsOneWidget);
        await tester.ensureVisible(shortClass);
        await tester.tap(shortClass);
        await tester.pumpAndSettle();
        expect(find.text('15-minute beginner class'), findsOneWidget);
        expect(find.text('Description'), findsOneWidget);
        _expectNoFlutterErrors(tester, 'class detail sheet');

        Navigator.of(
          tester.element(find.byType(ScheduleScreen)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Next day'));
        await tester.pumpAndSettle();
        _expectNoFlutterErrors(tester, 'next-day navigation');
        await tester.tap(find.byTooltip('Previous day'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(find.text('15-minute beginner class'), findsOneWidget);
        _expectNoFlutterErrors(tester, 'week view');
      });
    }
  }
}

class _ShortClassAppDataService extends MockAppDataService {
  _ShortClassAppDataService() {
    final locationId = selectedStudentProfile.locationId;
    scheduleItems = {
      DateTime.monday: [
        _session(
          'short-15',
          '15-minute beginner class',
          8 * 60,
          15,
          locationId,
        ),
        _session(
          'short-20',
          '20-minute overlapping class with a long title',
          8 * 60,
          20,
          locationId,
        ),
        _session(
          'short-30',
          '30-minute narrow class with a long title',
          8 * 60 + 30,
          30,
          locationId,
        ),
        _session(
          'short-40',
          '40-minute overlapping class with a long title',
          8 * 60 + 30,
          40,
          locationId,
        ),
      ],
    };
  }

  late final Map<int, List<ClassSession>> scheduleItems;

  @override
  Map<int, List<ClassSession>> get schedule => scheduleItems;
}

ClassSession _session(
  String id,
  String name,
  int startMinutes,
  int durationMinutes,
  String locationId,
) {
  final start = DateTime(2026, 9, 14).add(Duration(minutes: startMinutes));
  return ClassSession(
    id: id,
    className: name,
    classTypeId: 'level-3',
    bulkGroupId: '$id-group',
    locationId: locationId,
    startTime: start,
    endTime: start.add(Duration(minutes: durationMinutes)),
    startMinutes: startMinutes,
    endMinutes: startMinutes + durationMinutes,
    eligibleBelts: const ['Red-Black'],
    description: 'Full class details remain available from the timeline.',
  );
}

void _expectNoFlutterErrors(WidgetTester tester, String surface) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    final detail = error is FlutterError ? error.toStringDeep() : '$error';
    fail('$surface: $detail');
  }
}
