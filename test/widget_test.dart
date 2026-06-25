import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/main.dart';
import 'package:ota_cheshire_management_platform/screens/curriculum_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notifications_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
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
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('Summer Camp Registration Now Open'), findsOneWidget);
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
    expect(
      find.text('Review belt requirements and training material'),
      findsOneWidget,
    );

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(
      find.text('Stay up to date with academy news and announcements.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Student Information'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Good Evening, Sudhamsu'), findsOneWidget);
  });

  testWidgets('curriculum screen updates displayed belt content', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CurriculumScreen()));

    expect(find.text('Curriculum'), findsWidgets);
    expect(find.text('Form video placeholder'), findsOneWidget);
    expect(find.text('White Belt'), findsOneWidget);

    await tester.tap(find.text('White Belt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue-Red Belt').last);
    await tester.pumpAndSettle();

    expect(find.text('Blue-Red Belt'), findsOneWidget);
    expect(find.text('Advanced transition sequence'), findsOneWidget);
  });

  testWidgets('notifications screen filters announcements', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));

    expect(find.text('Summer Camp Registration Now Open'), findsOneWidget);
    expect(find.text('Unread'), findsWidgets);
    expect(find.text('Important'), findsWidgets);

    await tester.tap(find.text('Important').first);
    await tester.pumpAndSettle();

    expect(find.text('Reminder: Belt Testing This Saturday'), findsOneWidget);
    expect(find.text('Academy Closed for Independence Day'), findsNothing);

    await tester.tap(find.text('Unread').first);
    await tester.pumpAndSettle();

    expect(find.text('Parent Meeting Next Thursday'), findsOneWidget);
    expect(find.text('New Curriculum Videos Available'), findsNothing);
  });

  testWidgets('tapping a notification opens detail screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));

    await tester.tap(find.text('Tournament Registration Closes Friday'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Detail'), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);
    expect(find.text('Tournament'), findsWidgets);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Future Resources'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
  });

  testWidgets('profile screen displays student and account settings', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    expect(find.text('Sudhamsu'), findsWidgets);
    expect(find.text('Red-Black Belt • OTA Cheshire'), findsOneWidget);
    expect(find.text('Student Information'), findsOneWidget);
    expect(find.text('Belt & Promotion'), findsOneWidget);
    expect(find.text('Family & Account'), findsOneWidget);
    expect(find.text('OTA Parent'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign Out'));

    expect(find.text('Settings & Actions'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
