import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/data/sample_schedule.dart';
import 'package:ota_cheshire_management_platform/main.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/screens/curriculum_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notifications_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/resources_screen.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/welcome_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';

void main() {
  test(
    'teen adult sparring is stored in mock data but hidden from active schedule',
    () {
      final rawFridaySchedule =
          sampleSummerSchedule[DateTime.friday] ?? const [];
      final storedClass = rawFridaySchedule.firstWhere(
        (session) => session.id == 'fri_teen_adult_sparring',
      );

      expect(storedClass.className, 'Teen/Adult Sparring');
      expect(storedClass.startLabel, '7:20 PM');
      expect(storedClass.isPublished, isFalse);
      expect(storedClass.resumesOn, DateTime(2026, 9, 5));
      expect(
        appDataService
            .scheduleForWeekday(DateTime.friday)
            .where((session) => session.id == 'fri_teen_adult_sparring'),
        isEmpty,
      );
    },
  );

  testWidgets('app launches the admin dashboard for development', (
    tester,
  ) async {
    await tester.pumpWidget(const OTAApp());

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('OTA Cheshire Control Panel'), findsOneWidget);
    expect(find.text("Today's Schedule"), findsOneWidget);
    expect(find.text('Recent Admin Updates'), findsOneWidget);
  });

  testWidgets('welcome screen displays its primary actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Olympic Taekwondo Academy'), findsOneWidget);
    expect(find.text('Student View'), findsOneWidget);
    expect(find.text('Admin View'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
  });

  testWidgets('welcome debug view buttons open student and admin dashboards', (
    tester,
  ) async {
    await tester.pumpWidget(const _WelcomeViewButtonTestApp());

    await tester.tap(find.text('Student View'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentDashboardScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const _WelcomeViewButtonTestApp());

    await tester.tap(find.text('Admin View'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
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

  testWidgets('student dashboard fits narrow mobile width', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StudentDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.pumpWidget(const _StudentNavigationTestApp());

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleScreen), findsOneWidget);

    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();
    expect(find.text('Student resources are coming soon.'), findsOneWidget);

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

  testWidgets('admin navigation opens every admin destination', (tester) async {
    await tester.pumpWidget(const _AdminNavigationTestApp());

    await tester.tap(find.widgetWithText(TextButton, 'Students'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminStudentsScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Events'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminEventsScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Announcements'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementsScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Schedule'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminScheduleScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDashboardScreen), findsOneWidget);
  });

  testWidgets('admin profile icon opens profile and exits to welcome', (
    tester,
  ) async {
    await tester.pumpWidget(const _AdminNavigationTestApp());

    await tester.tap(find.byTooltip('Admin profile'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminProfileScreen), findsOneWidget);
    expect(find.text('Admin Profile'), findsOneWidget);
    expect(find.text('Exit to Welcome'), findsOneWidget);

    await tester.tap(find.text('Exit to Welcome'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('admin schedule page displays class management controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminScheduleScreen()));

    expect(find.text('Add Class'), findsOneWidget);
    expect(find.text('Bulk Actions'), findsOneWidget);

    await tester.tap(find.text('Monday').first);
    await tester.pumpAndSettle();

    expect(find.text('Little Tiger (Age 3-5)'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Edit'), findsWidgets);
    expect(find.text('Delete'), findsWidgets);

    await tester.tap(find.text('Add Class'));
    await tester.pumpAndSettle();

    expect(find.text('Class name'), findsOneWidget);
    expect(find.text('Save Class'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bulk Actions'));
    await tester.tap(find.text('Bulk Actions'));
    await tester.pumpAndSettle();

    expect(find.text('Bulk Schedule Action'), findsOneWidget);
    expect(find.text('Delete all classes in date range'), findsOneWidget);
    expect(find.text('Close Preview'), findsOneWidget);
  });

  testWidgets('admin announcements page displays filters and mock form', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminAnnouncementsScreen()),
    );

    expect(find.text('Create Announcement'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Published'), findsWidgets);
    expect(find.text('Summer Camp Registration Now Open'), findsOneWidget);
    expect(find.text('Preview'), findsWidgets);

    await tester.tap(find.text('Create Announcement'));
    await tester.pumpAndSettle();

    expect(find.text('Full message/body'), findsOneWidget);
    expect(find.text('Audience'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish Announcement'), findsOneWidget);
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
    expect(find.text('Important'), findsWidgets);
    expect(find.text('Tournament'), findsWidgets);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Future Resources'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
  });

  testWidgets('profile screen displays student and account settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: OtaRoutes.profile,
        routes: {
          OtaRoutes.profile: (_) => const ProfileScreen(),
          OtaRoutes.welcome: (_) => const WelcomeScreen(),
        },
      ),
    );

    expect(find.text('Sudhamsu'), findsWidgets);
    expect(find.text('Red-Black Belt • OTA Cheshire'), findsOneWidget);
    expect(find.text('Student Information'), findsOneWidget);
    expect(find.text('Belt & Promotion'), findsOneWidget);
    expect(find.text('Family & Account'), findsOneWidget);
    expect(find.text('OTA Parent'), findsOneWidget);

    await tester.ensureVisible(find.text('Sign Out'));

    expect(find.text('Settings & Actions'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Exit to Welcome'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Exit to Welcome'),
      240,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit to Welcome'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}

class _StudentNavigationTestApp extends StatelessWidget {
  const _StudentNavigationTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: OtaRoutes.dashboard,
      routes: {
        OtaRoutes.dashboard: (_) => const StudentDashboardScreen(),
        OtaRoutes.schedule: (_) => const ScheduleScreen(),
        OtaRoutes.resources: (_) => const ResourcesScreen(),
        OtaRoutes.curriculum: (_) => const CurriculumScreen(),
        OtaRoutes.notifications: (_) => const NotificationsScreen(),
        OtaRoutes.profile: (_) => const ProfileScreen(),
      },
    );
  }
}

class _AdminNavigationTestApp extends StatelessWidget {
  const _AdminNavigationTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: OtaRoutes.adminDashboard,
      routes: {
        OtaRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
        OtaRoutes.adminStudents: (_) => const AdminStudentsScreen(),
        OtaRoutes.adminEvents: (_) => const AdminEventsScreen(),
        OtaRoutes.adminAnnouncements: (_) => const AdminAnnouncementsScreen(),
        OtaRoutes.adminSchedule: (_) => const AdminScheduleScreen(),
        OtaRoutes.adminProfile: (_) => const AdminProfileScreen(),
        OtaRoutes.welcome: (_) => const WelcomeScreen(),
      },
    );
  }
}

class _WelcomeViewButtonTestApp extends StatelessWidget {
  const _WelcomeViewButtonTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: OtaRoutes.welcome,
      routes: {
        OtaRoutes.welcome: (_) => const WelcomeScreen(),
        OtaRoutes.dashboard: (_) => const StudentDashboardScreen(),
        OtaRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
      },
    );
  }
}
