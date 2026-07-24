import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/curriculum_requirement.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/curriculum_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_location_controller.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';

void main() {
  setUp(() {
    adminLocationController = AdminLocationController.forTesting(
      role: UserAccountRole.admin,
      locations: const [
        AcademyLocation(
          id: 'ota-cheshire',
          name: 'OTA Cheshire',
          timeZoneId: 'America/New_York',
          isActive: true,
        ),
      ],
      assignedLocationId: 'ota-cheshire',
    );
  });

  testWidgets('admin curriculum loads without reading a student profile', (
    tester,
  ) async {
    final service = _CurriculumService(throwOnSelectedStudent: true);

    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(isAdmin: true, dataService: service)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('No Belt content'), findsOneWidget);
    expect(find.byTooltip('Back to Events & Resources'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(360, 640)]) {
    for (final textScale in const [1.0, 1.5]) {
      testWidgets(
        'admin curriculum header fits ${size.width}x${size.height} at $textScale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: CurriculumScreen(
                  isAdmin: true,
                  dataService: _CurriculumService(throwOnSelectedStudent: true),
                ),
              ),
            ),
          );
          await tester.pump();

          final title = tester.widget<Text>(
            find.byKey(const ValueKey('curriculum-content-title')),
          );
          expect(title.data, 'Curriculum');
          expect(title.maxLines, 1);
          expect(title.style?.fontSize, isNot(lessThan(20)));
          expect(find.byTooltip('Back to Events & Resources'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('admin back button returns to Events and Resources', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/curriculum',
        routes: {
          '/curriculum': (_) => CurriculumScreen(
            isAdmin: true,
            dataService: _CurriculumService(throwOnSelectedStudent: true),
          ),
          OtaRoutes.adminResources: (_) =>
              const Scaffold(body: Text('ADMIN RESOURCES')),
        },
      ),
    );

    await tester.tap(find.byTooltip('Back to Events & Resources'));
    await tester.pumpAndSettle();

    expect(find.text('ADMIN RESOURCES'), findsOneWidget);
  });

  testWidgets('student back button keeps the student resources destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/curriculum',
        routes: {
          '/curriculum': (_) =>
              CurriculumScreen(dataService: _CurriculumService()),
          OtaRoutes.resources: (_) =>
              const Scaffold(body: Text('STUDENT RESOURCES')),
        },
      ),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('STUDENT RESOURCES'), findsOneWidget);
  });

  testWidgets('admin can review different belt levels', (tester) async {
    final service = _CurriculumService(throwOnSelectedStudent: true);
    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(isAdmin: true, dataService: service)),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('White Belt').last);
    await tester.pumpAndSettle();

    expect(find.text('White content'), findsOneWidget);
    expect(find.text('No Belt content'), findsNothing);
  });

  testWidgets('student curriculum begins at the selected student belt', (
    tester,
  ) async {
    final service = _CurriculumService(selectedBelt: 'Blue');
    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(dataService: service)),
    );

    expect(find.text('Blue content'), findsOneWidget);
    expect(find.text('No Belt content'), findsNothing);
  });

  testWidgets('empty admin curriculum fails safely', (tester) async {
    final service = _CurriculumService(
      throwOnSelectedStudent: true,
      curriculumData: const {},
      beltOrder: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(isAdmin: true, dataService: service)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Curriculum is not available.'), findsOneWidget);
  });
}

class _CurriculumService extends MockAppDataService {
  _CurriculumService({
    this.throwOnSelectedStudent = false,
    this.selectedBelt = 'White',
    Map<String, CurriculumRequirement>? curriculumData,
    this.beltOrder = const ['No Belt', 'White', 'Blue'],
  }) : curriculumData =
           curriculumData ??
           {
             'No Belt': _requirement('No Belt'),
             'White': _requirement('White'),
             'Blue': _requirement('Blue'),
           };

  final bool throwOnSelectedStudent;
  final String selectedBelt;
  final Map<String, CurriculumRequirement> curriculumData;
  final List<String> beltOrder;

  @override
  List<String> get curriculumBeltOrder => beltOrder;

  @override
  Map<String, CurriculumRequirement> get curriculum => curriculumData;

  @override
  Student get selectedStudentProfile {
    if (throwOnSelectedStudent) {
      throw StateError('Admin curriculum requested a student profile.');
    }
    return Student(
      id: 'student',
      name: 'Student',
      locationId: 'ota-cheshire',
      belt: selectedBelt,
      legacyAge: 12,
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Black',
    );
  }

  @override
  String beltDisplayLabel(String belt) =>
      belt == 'No Belt' ? belt : '$belt Belt';
}

CurriculumRequirement _requirement(String belt) => CurriculumRequirement(
  locationId: 'ota-cheshire',
  belt: belt,
  sections: [
    CurriculumSection(
      id: 'section-$belt',
      title: '$belt content',
      sortOrder: 1,
    ),
  ],
);
