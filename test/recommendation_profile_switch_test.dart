import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';

class _Family extends MockAppDataService {
  int selected = 0;
  @override
  final linkedStudentProfiles = const [
    Student(
      id: 'young',
      name: 'Younger',
      locationId: 'ota-cheshire',
      belt: 'White',
      legacyAge: 7,
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Black',
      preferredClassGroupIds: ['level-1'],
    ),
    Student(
      id: 'older',
      name: 'Older',
      locationId: 'ota-cheshire',
      belt: 'Red',
      legacyAge: 14,
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Red-Yellow',
      // An obsolete younger-student preference must not override teen placement.
      preferredClassGroupIds: ['level-1-standard'],
    ),
  ];
  @override
  Student get selectedStudentProfile => linkedStudentProfiles[selected];
  @override
  final schedule = {
    DateTime.monday: [
      ClassSession(
        id: 'beginner',
        className: 'Level 1',
        classTypeId: 'level-1',
        locationId: 'ota-cheshire',
        startTime: DateTime(2027, 1, 4, 16),
        endTime: DateTime(2027, 1, 4, 17),
        eligibleBelts: ['White'],
        description: '',
      ),
      ClassSession(
        id: 'advanced',
        className: 'Teen & Black Belt',
        classTypeId: 'teen-adult',
        locationId: 'ota-cheshire',
        startTime: DateTime(2027, 1, 4, 18),
        endTime: DateTime(2027, 1, 4, 19),
        eligibleBelts: ['Black'],
        description: '',
      ),
    ],
  };
  @override
  ClassSession? nextClassForDashboard() => nextEligibleClassFromSchedule(
    schedule,
    selectedStudentProfile,
    currentWeekday: DateTime.monday,
    currentMinutes: 0,
  );
  void select(int index) {
    selected = index;
    notifyListeners();
  }
}

void main() {
  setUp(initializeMockAppDataServiceForTests);
  testWidgets(
    'parent Dashboard recomputes age-appropriate classes on child switch',
    (tester) async {
      final family = _Family();
      appDataService = family;
      await tester.pumpWidget(
        const MaterialApp(home: StudentDashboardScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Level 1 Class'), findsOneWidget);
      family.select(1);
      await tester.pumpAndSettle();
      expect(find.text('Teen & Black Belt Class'), findsOneWidget);
      expect(find.text('Level 1 Class'), findsNothing);
      family.select(0);
      await tester.pumpAndSettle();
      expect(find.text('Level 1 Class'), findsOneWidget);
    },
  );
  testWidgets(
    'Schedule recommendation changes from younger belt to teen age group',
    (tester) async {
      final family = _Family();
      appDataService = family;
      await tester.pumpWidget(
        MaterialApp(home: ScheduleScreen(initialDate: DateTime(2027, 1, 4))),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Next recommended class: Level 1'),
        findsOneWidget,
      );
      family.select(1);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Next recommended class: Teen & Black Belt'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Next recommended class: Level 1'),
        findsNothing,
      );
    },
  );
}
