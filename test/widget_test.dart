import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/main.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/welcome_screen.dart';

void main() {
  testWidgets('welcome screen displays its primary actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Olympic Taekwondo Academy'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
  });

  testWidgets('student dashboard displays key student information', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));

    expect(find.text('Good Evening, Sudhamsu'), findsOneWidget);
    expect(find.text('Teen & Black Belt Class'), findsOneWidget);
    expect(find.text('Black Belt'), findsOneWidget);
    expect(find.text('Summer Camp Registration Open'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.ensureVisible(find.text('Message OTA'));

    expect(find.text('Message OTA'), findsOneWidget);
  });

  testWidgets('schedule screen displays timeline and class blocks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(initialDate: DateTime(2026, 6, 22))),
    );

    expect(find.text('12 AM'), findsWidgets);
    expect(find.text('Schedule'), findsOneWidget);

    await tester.ensureVisible(find.text('Level 3'));

    expect(find.text('Level 3'), findsWidgets);
    expect(find.textContaining('Next eligible class:'), findsOneWidget);
  });

  testWidgets('bottom navigation opens every primary destination', (
    tester,
  ) async {
    await tester.pumpWidget(const OTAApp());

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Next eligible class:'), findsOneWidget);

    await tester.tap(find.text('Curriculum'));
    await tester.pumpAndSettle();
    expect(find.text('Curriculum Page Coming Soon'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications Page Coming Soon'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile Page Coming Soon'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Good Evening, Sudhamsu'), findsOneWidget);
  });
}
