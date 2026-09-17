import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/data/belt_ranks.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/widgets/admin/belt_multi_select_dropdown.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  test('production belt options contain the complete canonical sequence', () {
    expect(curriculumBeltOrder, const [
      'No Belt',
      'White',
      'White-Yellow',
      'Yellow',
      'Yellow-Green',
      'Green',
      'Green-Blue',
      'Blue',
      'Blue-Red',
      'Red',
      'Red-Yellow',
      'Red-Green',
      'Red-Blue',
      'Red-Black',
      'Black',
    ]);
  });

  testWidgets('belt dropdown selects multiple canonical belt ranks', (
    tester,
  ) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return BeltMultiSelectDropdown(
                selectedBelts: selected,
                onChanged: (belts) => setState(() => selected = belts),
                label: 'Test belts',
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('belt-multi-select-Test belts')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('belt-option-White')));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('belt-option-Black')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('belt-option-Black')));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selected, {'White', 'Black'});
    expect(find.text('White, Black'), findsOneWidget);
  });

  testWidgets(
    'belt dropdown fits long selections on a narrow large-text view',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BeltMultiSelectDropdown(
                  selectedBelts: curriculumBeltOrder.toSet(),
                  onChanged: (_) {},
                  label: 'Target belts',
                  helperText: 'Select one or more belt ranks.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decorator = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byType(BeltMultiSelectDropdown),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(
        decorator.decoration.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      _expectNoFlutterErrors(tester);

      await tester.tap(
        find.byKey(const ValueKey('belt-multi-select-Target belts')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      _expectNoFlutterErrors(tester);
    },
  );

  testWidgets('class form uses the shared belt multi-select dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminScheduleScreen()));
    await tester.tap(find.text('Add Class'));
    await tester.pumpAndSettle();

    expect(find.byType(BeltMultiSelectDropdown), findsOneWidget);
    expect(find.text('Eligible belts'), findsOneWidget);
    expect(find.text('Comma-separated belt ranks.'), findsNothing);
    expect(
      find.text('Select each belt rank eligible for this class.'),
      findsOneWidget,
    );
    expect(find.text('Leave empty to allow all belt ranks.'), findsNothing);
  });

  testWidgets('announcement belt targeting uses the shared multi-select', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminAnnouncementsScreen()),
    );
    await tester.tap(find.text('Create Announcement'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('announcement-audience-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Specific belt').last);
    await tester.pumpAndSettle();

    expect(find.byType(BeltMultiSelectDropdown), findsOneWidget);
    expect(find.text('Target belts'), findsOneWidget);
  });
}

void _expectNoFlutterErrors(WidgetTester tester) {
  final errors = <Object>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    errors.add(error!);
  }
  expect(errors, isEmpty);
}
