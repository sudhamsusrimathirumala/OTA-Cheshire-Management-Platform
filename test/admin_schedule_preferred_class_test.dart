import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  testWidgets('admin class form has no class-wide preferred toggle', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminScheduleScreen()));

    await tester.tap(find.text('Add Class'));
    await tester.pumpAndSettle();

    expect(find.text('Save Class'), findsOneWidget);
    expect(find.text('Preferred class'), findsNothing);
  });

  testWidgets('editing a legacy preferred class still opens safely', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminScheduleScreen()));
    await tester.tap(find.text('Monday').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Class'), findsOneWidget);
    expect(find.text('Update Class'), findsOneWidget);
    expect(find.text('Preferred class'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('class writes omit the legacy preferred field', () {
    final fields = classSessionWriteFields(
      ClassSessionWriteData(
        className: 'Level 1',
        classTypeId: 'level-1',
        bulkGroupId: 'level-1-standard',
        locationId: 'ota-cheshire',
        weekday: DateTime.monday,
        startMinutes: 600,
        endMinutes: 660,
        eligibleBelts: const ['White'],
        description: 'Fundamentals',
        isActive: true,
      ),
      now: DateTime.utc(2026, 7, 23),
    );

    expect(fields, isNot(contains('isPreferred')));
    expect(fields['bulkGroupId'], 'level-1-standard');
  });

  test('student preference matching ignores legacy class-wide values', () {
    final student = _student(
      preferredClassGroupIds: const ['level-1-standard'],
    );
    final legacyPreferred = _session(isPreferred: true);
    final legacyNotPreferred = _session(isPreferred: false);

    expect(
      matchesResolvedPreferredClassGroup(
        student.preferredClassGroupIds,
        legacyPreferred.bulkGroupId,
      ),
      isTrue,
    );
    expect(
      matchesResolvedPreferredClassGroup(
        student.preferredClassGroupIds,
        legacyNotPreferred.bulkGroupId,
      ),
      isTrue,
    );
    expect(
      matchesResolvedPreferredClassGroup(
        const <String>[],
        legacyPreferred.bulkGroupId,
      ),
      isFalse,
    );
  });
}

ClassSession _session({required bool isPreferred}) => ClassSession(
  id: isPreferred ? 'legacy-true' : 'legacy-false',
  className: 'Level 1',
  classTypeId: 'level-1',
  bulkGroupId: 'level-1-standard',
  locationId: 'ota-cheshire',
  startTime: DateTime(2026, 7, 20, 10),
  endTime: DateTime(2026, 7, 20, 11),
  eligibleBelts: const ['White'],
  description: 'Fundamentals',
  isPreferred: isPreferred,
);

Student _student({required List<String> preferredClassGroupIds}) => Student(
  id: 'student',
  name: 'Student',
  locationId: 'ota-cheshire',
  belt: 'White',
  legacyAge: 10,
  stickerCount: 0,
  stickersRequired: 0,
  nextRank: 'Yellow',
  preferredClassGroupIds: preferredClassGroupIds,
);
