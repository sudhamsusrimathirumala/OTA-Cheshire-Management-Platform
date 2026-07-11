import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/data/sample_schedule.dart';
import 'package:ota_cheshire_management_platform/main.dart';
import 'package:ota_cheshire_management_platform/models/academy_resource.dart';
import 'package:ota_cheshire_management_platform/models/curriculum_requirement.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_resources_screen.dart';
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
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/event_resource_rules.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_migration_service.dart';
import 'package:ota_cheshire_management_platform/widgets/location_date_time_field.dart';
import 'package:ota_cheshire_management_platform/widgets/resources/general_resources_view.dart';
import 'package:ota_cheshire_management_platform/widgets/resources/resources_landing_view.dart';

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

  testWidgets('app launches the welcome screen', (tester) async {
    await tester.pumpWidget(const OTAApp());

    expect(find.byType(WelcomeScreen), findsOneWidget);
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
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);

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
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('General Resources'), findsOneWidget);

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

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Resources'));
    await tester.tap(find.widgetWithText(TextButton, 'Resources'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminResourcesScreen), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Dashboard'));
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

  testWidgets('admin event form uses combined picker fields', (tester) async {
    LocationTimeService.initialize();
    await tester.pumpWidget(const MaterialApp(home: AdminEventsScreen()));
    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();

    expect(find.text('Start date and time'), findsOneWidget);
    expect(find.text('End date and time'), findsOneWidget);
    expect(find.text('Registration deadline'), findsOneWidget);
    expect(find.text('Start date'), findsNothing);
    expect(find.text('Start time'), findsNothing);
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
    expect(find.text('Taegeuk form placeholder'), findsOneWidget);
    expect(
      find.text('https://www.youtube.com/@OlympicTaekwondoAcademy'),
      findsWidgets,
    );
    expect(find.text('White Belt'), findsOneWidget);

    await tester.tap(find.text('White Belt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue-Red Belt').last);
    await tester.pumpAndSettle();

    expect(find.text('Blue-Red Belt'), findsOneWidget);
    expect(find.text('Advanced transition sequence'), findsOneWidget);
  });

  testWidgets('student and admin resources landings share two destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResourcesScreen()));
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('General Resources'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: AdminResourcesScreen()));
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('General Resources'), findsOneWidget);
    expect(find.text('Create Resource'), findsNothing);
  });

  testWidgets('shared resource card only shows editing in admin mode', (
    tester,
  ) async {
    final resource = AcademyResource(
      id: 'test-resource',
      title: 'Test Resource',
      description: 'Shared card test',
      resourceType: 'document',
      category: 'forms',
      locationId: 'ota-cheshire',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GeneralResourceCard(
          resource: resource,
          presentation: ResourcesPresentation.student,
        ),
      ),
    );
    expect(find.byTooltip('Edit resource'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: GeneralResourceCard(
          resource: resource,
          presentation: ResourcesPresentation.admin,
          onEdit: () {},
        ),
      ),
    );
    expect(find.byTooltip('Edit resource'), findsOneWidget);
  });

  testWidgets('admin general resources exposes create and edit controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminGeneralResourcesScreen()),
    );
    expect(find.text('Create Resource'), findsOneWidget);
    expect(find.byTooltip('Edit resource'), findsWidgets);
  });

  testWidgets('admin curriculum is read only', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CurriculumScreen(isAdmin: true)),
    );
    expect(find.text('Curriculum'), findsWidgets);
    expect(find.text('Create Curriculum'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  test('event resource rules exclude curriculum and archived resources', () {
    AcademyResource resource(
      String id, {
      String section = 'general',
      bool published = true,
      bool archived = false,
    }) => AcademyResource(
      id: id,
      title: id,
      description: '',
      resourceSection: section,
      resourceType: 'document',
      category: 'general',
      locationId: 'ota-cheshire',
      isPublished: published,
      isArchived: archived,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final draft = resource('draft', published: false);
    final archived = resource('archived', archived: true);
    final options = eventGeneralResourceOptions([
      resource('general'),
      resource('curriculum', section: 'curriculum'),
      archived,
      draft,
    ], locationId: 'ota-cheshire');

    expect(options.map((item) => item.id), ['draft', 'general']);
    expect(validatePublishedEventResource(draft), isNotNull);
    expect(validatePublishedEventResource(archived), isNotNull);
    expect(validatePublishedEventResource(options.last), isNull);
  });

  test('curriculum supports sorted multiple video and text items', () {
    final curriculum = CurriculumRequirement(
      locationId: 'ota-cheshire',
      belt: 'White',
      formItems: const [],
      oneStepItems: const [],
      breakingItems: const [],
      physicalChallengeItems: const [],
      sections: const [
        CurriculumSection(
          id: 'breaking',
          title: 'Breaking',
          sortOrder: 2,
          items: [
            CurriculumItem(
              id: 'break-2',
              title: 'Second break',
              contentType: CurriculumContentType.text,
              textContent: 'Second break details',
              sortOrder: 2,
            ),
            CurriculumItem(
              id: 'break-1',
              title: 'First break',
              contentType: CurriculumContentType.text,
              textContent: 'First break details',
              sortOrder: 1,
            ),
          ],
        ),
        CurriculumSection(
          id: 'forms',
          title: 'Forms',
          sortOrder: 1,
          items: [
            CurriculumItem(
              id: 'form-1',
              title: 'Form one',
              contentType: CurriculumContentType.video,
              videoUrl: 'https://www.youtube.com/watch?v=form-one',
              sortOrder: 1,
            ),
            CurriculumItem(
              id: 'form-2',
              title: 'Form two',
              contentType: CurriculumContentType.video,
              videoUrl: 'https://www.youtube.com/watch?v=form-two',
              sortOrder: 2,
            ),
          ],
        ),
      ],
    );

    expect(curriculum.sortedSections.first.id, 'forms');
    expect(curriculum.sortedSections.first.sortedItems, hasLength(2));
    expect(
      curriculum.sortedSections.first.sortedItems.last.videoUrl,
      'https://www.youtube.com/watch?v=form-two',
    );
    expect(
      curriculum.sortedSections.last.sortedItems.first.textContent,
      'First break details',
    );
  });

  test('academy event time round-trips through America New York', () {
    LocationTimeService.initialize();
    const service = LocationTimeService();
    final instant = service.combineDateAndTime(
      locationId: 'ota-cheshire',
      date: DateTime(2026, 7, 20),
      time: const TimeOfDay(hour: 19, minute: 30),
    );

    expect(instant, DateTime.utc(2026, 7, 20, 23, 30));
    final local = service.toLocationTime(instant, 'ota-cheshire');
    expect(local.hour, 19);
    expect(local.minute, 30);
    expect(local.timeZoneName, 'EDT');
  });

  test('schedule write data preserves wall clock minutes', () {
    const data = ClassSessionWriteData(
      className: 'Teen/Adult Sparring',
      classTypeId: 'teen-adult',
      bulkGroupId: 'teen-adult-evening',
      locationId: 'ota-cheshire',
      weekday: DateTime.friday,
      startMinutes: 19 * 60 + 20,
      endMinutes: 20 * 60,
      eligibleBelts: [],
      description: '',
      isActive: true,
      isPreferred: false,
    );

    expect(data.startMinutes, 1160);
    expect(data.startTime.hour, 19);
    expect(data.startTime.minute, 20);
  });

  testWidgets('combined date time field preserves value when canceled', (
    tester,
  ) async {
    LocationTimeService.initialize();
    final original = DateTime.utc(2026, 7, 20, 23, 30);
    DateTime? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationDateTimeField(
            label: 'Start date and time',
            locationId: 'ota-cheshire',
            value: original,
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    expect(find.textContaining('Jul 20, 2026 at 7:30 PM EDT'), findsOneWidget);
    await tester.tap(find.textContaining('Jul 20, 2026 at 7:30 PM EDT'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changedValue, isNull);
  });

  testWidgets('combined date selection opens the time picker', (tester) async {
    LocationTimeService.initialize();
    DateTime? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationDateTimeField(
            label: 'End date and time',
            locationId: 'ota-cheshire',
            value: DateTime.utc(2026, 7, 20, 23, 30),
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('Jul 20, 2026 at 7:30 PM EDT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(changedValue, isNull);
  });

  test('migration bulk group helper derives and repairs stable IDs', () {
    expect(migrationBulkGroupId({'className': 'Level 1'}), 'level-1-standard');
    expect(
      migrationBulkGroupId({'bulkGroupId': 'level-1-standard'}),
      'level-1-standard',
    );
    expect(
      migrationBulkGroupId({'bulkGroupId': 'level-1-standard-standard'}),
      'level-1-standard',
    );
    expect(
      migrationBulkGroupId({
        'bulkGroupId': 'teen-adult-standard-standard-standard',
      }),
      'teen-adult-standard',
    );
    expect(
      migrationBulkGroupId({'bulkGroupId': 'advanced-saturday-program'}),
      'advanced-saturday-program',
    );
  });

  test('migration resource and location helpers only add missing fields', () {
    expect(migrationResourceBackfill({'title': 'Existing'}), {
      'resourceSection': 'general',
      'isArchived': false,
    });
    expect(
      migrationResourceBackfill({
        'resourceSection': 'general',
        'isArchived': true,
      }),
      isEmpty,
    );
    expect(migrationLocationBackfill({}), {
      'name': 'OTA Cheshire',
      'timeZoneId': 'America/New_York',
      'isActive': true,
    });
    expect(
      migrationLocationBackfill({
        'name': 'Existing Academy Name',
        'timeZoneId': 'America/Chicago',
        'isActive': false,
      }),
      isEmpty,
    );
  });

  test('pure migration helper calculations are idempotent', () {
    final firstBulkGroupId = migrationBulkGroupId({
      'bulkGroupId': 'level-2-standard-standard-standard',
    });
    final secondBulkGroupId = migrationBulkGroupId({
      'bulkGroupId': firstBulkGroupId,
    });
    expect(secondBulkGroupId, firstBulkGroupId);

    final resource = <String, dynamic>{'title': 'Existing'};
    resource.addAll(migrationResourceBackfill(resource));
    expect(migrationResourceBackfill(resource), isEmpty);

    final location = <String, dynamic>{};
    location.addAll(migrationLocationBackfill(location));
    expect(migrationLocationBackfill(location), isEmpty);
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
        OtaRoutes.adminResources: (_) => const AdminResourcesScreen(),
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
