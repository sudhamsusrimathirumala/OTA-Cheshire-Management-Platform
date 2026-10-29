import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectSignupBirthDate(WidgetTester tester, String date) async {
  final field = find.widgetWithText(TextFormField, 'Date of birth');
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextFormField),
    ),
    date,
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
