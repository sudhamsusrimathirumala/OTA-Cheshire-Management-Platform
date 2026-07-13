import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/data/sample_schedule.dart';
import 'package:ota_cheshire_management_platform/data/sample_student.dart';
import 'package:ota_cheshire_management_platform/data/sample_curriculum.dart'
    as curriculum_data;
import 'package:ota_cheshire_management_platform/models/academy_event.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
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
import 'package:ota_cheshire_management_platform/screens/events_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notifications_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/resource_detail_screen.dart';
import 'package:ota_cheshire_management_platform/screens/resources_screen.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/welcome_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/event_resource_rules.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_migration_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_schema_update_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_seed_service.dart';
import 'package:ota_cheshire_management_platform/widgets/location_date_time_field.dart';
import 'package:ota_cheshire_management_platform/widgets/admin/admin_bottom_nav_bar.dart';
import 'package:ota_cheshire_management_platform/widgets/ota_bottom_nav_bar.dart';
import 'package:ota_cheshire_management_platform/widgets/resources/general_resources_view.dart';
import 'package:ota_cheshire_management_platform/widgets/resources/resources_landing_view.dart';
import 'package:ota_cheshire_management_platform/widgets/schedule_time_field.dart';

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
      expect(storedClass.classTypeId, 'teen-adult-sparring');
      expect(storedClass.bulkGroupId, 'teen-adult-sparring-standard');
      expect(storedClass.isEligibleFor(sampleStudent), isTrue);
      final levelSparring = rawFridaySchedule.firstWhere(
        (session) => session.id == 'fri_sparring',
      );
      expect(levelSparring.classTypeId, 'level-1-2-sparring');
      expect(levelSparring.bulkGroupId, 'level-1-2-sparring-standard');
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

  testWidgets('schedule defaults to Day and keeps Week optional', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(initialDate: DateTime(2026, 6, 22))),
    );

    expect(find.text('12 AM'), findsWidgets);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('12 AM'), findsNothing);
    expect(find.text('Sunday'), findsWidgets);
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

    await tester.tap(find.widgetWithText(TextButton, 'Announcements'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminAnnouncementsScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Schedule'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminScheduleScreen), findsOneWidget);

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Events & Resources'),
    );
    final resourcesTab = find.widgetWithText(TextButton, 'Events & Resources');
    await tester.ensureVisible(resourcesTab);
    await tester.tap(resourcesTab);
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
    expect(
      find.widgetWithText(TextButton, 'Events & Resources'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Events'), findsNothing);
    expect(find.text('Create Event'), findsWidgets);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Published'), findsWidgets);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Back to Events & Resources'), findsOneWidget);
  });

  testWidgets('selected combined admin destination returns to its landing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: OtaRoutes.adminEvents,
        routes: {
          OtaRoutes.adminEvents: (_) => const AdminEventsScreen(),
          OtaRoutes.adminResources: (_) => const AdminResourcesScreen(),
        },
      ),
    );
    await tester.tap(find.text('Back to Events & Resources'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminResourcesScreen), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);
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
      findsNothing,
    );
    expect(find.text('Video coming soon'), findsNWidgets(2));
    expect(find.text('Red-Black Belt'), findsOneWidget);

    await tester.tap(find.text('Red-Black Belt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue-Red Belt').last);
    await tester.pumpAndSettle();

    expect(find.text('Blue-Red Belt'), findsOneWidget);
    expect(find.text('Advanced transition sequence'), findsOneWidget);
  });

  testWidgets('curriculum screen provides a back button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CurriculumScreen()));

    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('selected student resources destination can return home', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OtaBottomNavBar(
            selectedDestination: OtaBottomNavDestination.resources,
            onSelectedDestinationTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Resources'));
    expect(tapped, isTrue);
  });

  testWidgets('selected admin resources destination can return home', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminNavigationBar(
            selectedDestination: AdminNavDestination.resources,
            onSelectedDestinationTap: () => tapped = true,
          ),
        ),
      ),
    );

    final resourcesTab = find.widgetWithText(TextButton, 'Events & Resources');
    await tester.ensureVisible(resourcesTab);
    await tester.tap(resourcesTab);
    expect(tapped, isTrue);
  });

  testWidgets('student and admin resources landings share three destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ResourcesScreen()));
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('General Resources'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: AdminResourcesScreen()));
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('General Resources'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Events & Resources'), findsWidgets);
    expect(find.text('Create Resource'), findsNothing);
  });

  testWidgets('resource landing event cards use student and admin routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('student-resources-routes'),
        home: const ResourcesScreen(),
        routes: {
          OtaRoutes.events: (_) => const Scaffold(body: Text('Student events')),
        },
      ),
    );
    await tester.ensureVisible(find.text('Events'));
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Student events'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('admin-resources-routes'),
        home: const AdminResourcesScreen(),
        routes: {
          OtaRoutes.adminEvents: (_) =>
              const Scaffold(body: Text('Admin events')),
        },
      ),
    );
    await tester.ensureVisible(find.text('Events'));
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Admin events'), findsOneWidget);
  });

  testWidgets('events card follows General Resources on a narrow landing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ResourcesScreen()));
    expect(
      tester.getTopLeft(find.text('Events')).dy,
      greaterThan(tester.getTopLeft(find.text('General Resources')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resources visible and system Back return to dashboard', (
    tester,
  ) async {
    Widget app() => MaterialApp(
      initialRoute: OtaRoutes.resources,
      routes: {
        OtaRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard')),
        OtaRoutes.resources: (_) => const ResourcesScreen(),
        OtaRoutes.events: (_) => const EventsScreen(),
      },
    );

    await tester.pumpWidget(app());
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.pumpWidget(app());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('Curriculum and General Resources Back return to Resources', (
    tester,
  ) async {
    Future<void> verifyBack(String initialRoute) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(initialRoute),
          initialRoute: initialRoute,
          routes: {
            OtaRoutes.resources: (_) =>
                const Scaffold(body: Text('Resources landing destination')),
            OtaRoutes.curriculum: (_) => const CurriculumScreen(),
            OtaRoutes.generalResources: (_) => const GeneralResourcesScreen(),
          },
        ),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Resources landing destination'), findsOneWidget);
    }

    await verifyBack(OtaRoutes.curriculum);
    await verifyBack(OtaRoutes.generalResources);
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
    expect(find.text('Back to Events & Resources'), findsOneWidget);
    expect(find.byTooltip('Edit resource'), findsWidgets);

    await tester.tap(find.text('Create Resource'));
    await tester.pumpAndSettle();
    expect(find.text('Save Draft'), findsOneWidget);
    expect(find.text('Publish Resource'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit resource').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Resource'), findsOneWidget);
    expect(find.text('Update Published Resource'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Resource actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('student resource card opens resource detail page', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GeneralResourcesScreen()));

    await tester.tap(find.text('Parent Night Out Registration'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceDetailScreen), findsOneWidget);
    expect(find.text('Resource Detail'), findsOneWidget);
    expect(
      find.text('Registration form for the next Parent Night Out event.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('General Resources'), findsOneWidget);
  });

  testWidgets('valid resource links show open and copy actions', (
    tester,
  ) async {
    final resource = AcademyResource(
      id: 'linked',
      title: 'Linked Resource',
      description: '',
      resourceType: 'document',
      category: 'general',
      linkUrl: 'https://example.com/resource',
      locationId: 'ota-cheshire',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceDetailScreen(
          resource: resource,
          linkLauncher: (uri) async => true,
        ),
      ),
    );

    expect(find.text('Open Link'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
  });

  testWidgets('resource link launch failure shows a friendly error', (
    tester,
  ) async {
    final resource = AcademyResource(
      id: 'linked',
      title: 'Linked Resource',
      description: '',
      resourceType: 'document',
      category: 'general',
      linkUrl: 'https://example.com/resource',
      locationId: 'ota-cheshire',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceDetailScreen(
          resource: resource,
          linkLauncher: (uri) async => false,
        ),
      ),
    );

    await tester.tap(find.text('Open Link'));
    await tester.pump();
    expect(find.text('Unable to open this resource link.'), findsOneWidget);
  });

  testWidgets('missing and invalid resource links hide link actions', (
    tester,
  ) async {
    AcademyResource resource(String? link) => AcademyResource(
      id: 'resource',
      title: 'Resource',
      description: '',
      resourceType: 'document',
      category: 'general',
      linkUrl: link,
      locationId: 'ota-cheshire',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    for (final link in <String?>[null, 'not a link']) {
      await tester.pumpWidget(
        MaterialApp(home: ResourceDetailScreen(resource: resource(link))),
      );
      expect(find.text('Open Link'), findsNothing);
      expect(find.text('Copy Link'), findsNothing);
    }
  });

  testWidgets('admin resource form rejects an invalid entered URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminGeneralResourcesScreen()),
    );
    await tester.tap(find.text('Create Resource'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Reference',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Link URL'),
      'not a url',
    );
    await tester.tap(find.text('Save Draft'));
    await tester.pump();

    expect(
      find.text('Enter a valid HTTP or HTTPS link, or leave it empty.'),
      findsOneWidget,
    );
  });

  testWidgets('admin resource card opens detail with status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminGeneralResourcesScreen()),
    );

    await tester.tap(find.text('Parent Night Out Registration'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceDetailScreen), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('event popup opens its linked resource detail page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventsScreen(
          dataService: const MockAppDataService(),
          now: DateTime.utc(2026, 7, 12, 16),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Parent Night Out').first);
    await tester.tap(find.text('Parent Night Out').first);
    await tester.pumpAndSettle();
    expect(find.text('Go to Resource for Event'), findsOneWidget);

    await tester.tap(find.text('Go to Resource for Event'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceDetailScreen), findsOneWidget);
    expect(find.text('Parent Night Out Registration'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(EventsScreen), findsOneWidget);
    expect(find.byKey(const Key('month-calendar-grid')), findsOneWidget);
  });

  testWidgets('open student event popup updates from live service changes', (
    tester,
  ) async {
    final original = _testEvent(
      id: 'live-event',
      title: 'Original Live Title',
      start: DateTime.utc(2026, 1, 15, 15),
      end: DateTime.utc(2026, 1, 15, 16),
    );
    final service = _LiveEventsTestService([original]);
    await tester.pumpWidget(
      MaterialApp(
        home: EventsScreen(
          dataService: service,
          now: DateTime.utc(2026, 1, 15, 17),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Original Live Title'));
    await tester.tap(find.text('Original Live Title'));
    await tester.pumpAndSettle();

    service.replaceEvent(
      AcademyEvent(
        id: original.id,
        title: 'Updated Live Title',
        description: 'Updated live description',
        locationId: original.locationId,
        eventType: original.eventType,
        startDateTime: original.startDateTime,
        endDateTime: original.endDateTime,
        isPublished: true,
        createdAt: original.createdAt,
        updatedAt: DateTime.utc(2026, 1, 15, 18),
      ),
    );
    await tester.pump();

    expect(find.text('Updated Live Title'), findsWidgets);
    expect(find.text('Updated live description'), findsOneWidget);
    expect(find.text('Original Live Title'), findsNothing);
  });

  testWidgets('events back uses the caller route for dashboard and resources', (
    tester,
  ) async {
    Future<void> verifyCaller({
      required String key,
      required Widget origin,
      required String openLabel,
      required String originLabel,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(key),
          home: origin,
          routes: {
            OtaRoutes.events: (_) => EventsScreen(
              dataService: const MockAppDataService(),
              now: DateTime.utc(2026, 7, 12, 16),
            ),
          },
        ),
      );
      final eventAction = find.widgetWithText(InkWell, openLabel);
      await tester.ensureVisible(eventAction);
      await tester.pumpAndSettle();
      await tester.tap(eventAction);
      await tester.pumpAndSettle();
      expect(find.byType(EventsScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text(originLabel), findsWidgets);

      await tester.ensureVisible(eventAction);
      await tester.tap(eventAction);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(originLabel), findsWidgets);
    }

    await verifyCaller(
      key: 'dashboard-events-back',
      origin: const StudentDashboardScreen(),
      openLabel: 'Events',
      originLabel: 'Good Evening, Sudhamsu',
    );
    await verifyCaller(
      key: 'resources-events-back',
      origin: const ResourcesScreen(),
      openLabel: 'Events',
      originLabel: 'Curriculum',
    );
  });

  testWidgets('student events calendar renders and navigates across years', (
    tester,
  ) async {
    final service = _EventsTestService(events: const <AcademyEvent>[]);
    await tester.pumpWidget(
      MaterialApp(
        home: EventsScreen(
          dataService: service,
          now: DateTime.utc(2026, 1, 15, 17),
        ),
      ),
    );

    expect(find.byKey(const Key('month-calendar-grid')), findsOneWidget);
    for (final weekday in const [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ]) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(find.text('January 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('previous-month')));
    await tester.pump();
    expect(find.text('December 2025'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-month')));
    await tester.pump();
    expect(find.text('January 2026'), findsOneWidget);
    expect(find.byKey(const Key('calendar-day-2026-1-15')), findsOneWidget);
    expect(find.byType(OtaBottomNavBar), findsNothing);
  });

  testWidgets('calendar marks dates, filters selection, and sorts events', (
    tester,
  ) async {
    final events = [
      _testEvent(
        id: 'later',
        title: 'Later Event',
        start: DateTime.utc(2026, 1, 15, 20),
        end: DateTime.utc(2026, 1, 15, 21),
      ),
      _testEvent(
        id: 'earlier',
        title: 'Earlier Event',
        start: DateTime.utc(2026, 1, 15, 15),
        end: DateTime.utc(2026, 1, 15, 16),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: EventsScreen(
          dataService: _EventsTestService(events: events),
          now: DateTime.utc(2026, 1, 15, 17),
        ),
      ),
    );

    expect(find.byKey(const Key('event-marker-2026-1-15')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Earlier Event')).dy,
      lessThan(tester.getTopLeft(find.text('Later Event')).dy),
    );
    await tester.tap(find.byKey(const Key('calendar-day-2026-1-16')));
    await tester.pump();
    expect(find.text('Earlier Event'), findsNothing);
    expect(find.text('Later Event'), findsNothing);
    expect(find.text('No events on this date.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    final wrongLocation = AcademyResource(
      id: 'wrong-location',
      title: 'wrong-location',
      description: '',
      resourceType: 'document',
      category: 'general',
      locationId: 'other-location',
      isPublished: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final options = eventGeneralResourceOptions([
      resource('general'),
      resource('curriculum', section: 'curriculum'),
      archived,
      draft,
    ], locationId: 'ota-cheshire');

    expect(options.map((item) => item.id), ['draft', 'general']);
    expect(
      validatePublishedEventResource(null, eventLocationId: 'ota-cheshire'),
      isNull,
    );
    expect(
      validatePublishedEventResource(draft, eventLocationId: 'ota-cheshire'),
      isNotNull,
    );
    expect(
      validatePublishedEventResource(archived, eventLocationId: 'ota-cheshire'),
      isNotNull,
    );
    expect(
      validatePublishedEventResource(
        wrongLocation,
        eventLocationId: 'ota-cheshire',
      ),
      isNotNull,
    );
    expect(
      validatePublishedEventResource(
        options.last,
        eventLocationId: 'ota-cheshire',
      ),
      isNull,
    );
  });

  test('student resources only include visible matching general resources', () {
    AcademyResource resource(
      String id, {
      String locationId = 'ota-cheshire',
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
      locationId: locationId,
      isPublished: published,
      isArchived: archived,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final visible = visibleStudentGeneralResources([
      resource('published'),
      resource('draft', published: false),
      resource('archived', archived: true),
      resource('curriculum', section: 'curriculum'),
      resource('other-location', locationId: 'other-location'),
    ], locationId: 'ota-cheshire');

    expect(visible.map((resource) => resource.id), ['published']);
  });

  test('dashboard next class never falls back to an ineligible class', () {
    final mondayClasses = sampleSummerSchedule[DateTime.monday]!;
    final ineligibleClass = mondayClasses.firstWhere(
      (session) => session.className == 'Little Tiger (Age 3-5)',
    );
    final eligibleClass = mondayClasses.firstWhere(
      (session) => session.className == 'Teen & Black Belt',
    );

    expect(
      nextEligibleClassFromSchedule(
        {
          DateTime.monday: [ineligibleClass],
        },
        appDataService.selectedStudentProfile,
        currentWeekday: DateTime.sunday,
        currentMinutes: 0,
      ),
      isNull,
    );
    expect(
      nextEligibleClassFromSchedule(
        {
          DateTime.monday: [ineligibleClass, eligibleClass],
        },
        appDataService.selectedStudentProfile,
        currentWeekday: DateTime.sunday,
        currentMinutes: 0,
      ),
      same(eligibleClass),
    );
  });

  test('curriculum supports sorted multiple video and text items', () {
    final curriculum = CurriculumRequirement(
      locationId: 'ota-cheshire',
      belt: 'White',
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

  test('curriculum data uses No Belt and five canonical sections', () {
    const expectedIds = <String>[
      'forms',
      'one-step-sparring',
      'breaking-techniques',
      'kicking-combinations',
      'physical-challenges',
    ];

    expect(curriculum_data.curriculumBeltOrder.first, 'No Belt');
    expect(curriculum_data.beltDisplayLabel('No Belt'), 'No Belt');
    expect(curriculum_data.beltDisplayLabel('White'), 'White Belt');
    for (final curriculum in curriculum_data.sampleCurriculum.values) {
      expect(
        curriculum.sortedSections.map((section) => section.id),
        expectedIds,
      );
      expect(
        curriculum.sections.map((section) => section.title),
        isNot(contains('Requirements')),
      );
    }
    expect(
      curriculum_data.sampleCurriculum['White']!.sections.first.items,
      hasLength(2),
    );
    expect(
      curriculum_data.sampleCurriculum['No Belt']!.sections.first.items,
      isEmpty,
    );
  });

  test('local curriculum forms keep independent optional video URLs', () {
    const firstVideoId = 'abcdefghijk';
    const secondVideoUrl = 'https://youtu.be/lmnopqrstuv';
    final section = curriculum_data.buildLocalCurriculumFormsSection(const [
      curriculum_data.LocalCurriculumFormData(
        title: 'First approved form',
        videoUrl: firstVideoId,
      ),
      curriculum_data.LocalCurriculumFormData(
        title: 'Second approved form',
        videoUrl: secondVideoUrl,
      ),
      curriculum_data.LocalCurriculumFormData(
        title: 'Taegeuk form placeholder',
      ),
    ]);

    expect(section.items, hasLength(3));
    expect(section.items[0].videoUrl, firstVideoId);
    expect(section.items[1].videoUrl, secondVideoUrl);
    expect(section.items[2].videoUrl, isNull);
    expect(
      section.items.map((item) => item.videoUrl),
      isNot(contains('https://youtube.com/@OlympicTaekwondoAcademy')),
    );
    expect(
      curriculum_data.sampleCurriculum.values
          .expand((curriculum) => curriculum.sections.first.items)
          .every((item) => item.videoUrl == null),
      isTrue,
    );
  });

  test('curriculum belt selection falls back safely', () {
    final curriculum = <String, CurriculumRequirement>{
      'No Belt': _testCurriculum('No Belt'),
      'White': _testCurriculum('White'),
    };
    expect(
      initialCurriculumBelt(
        selectedStudentBelt: 'White',
        beltOrder: const ['No Belt', 'White'],
        curriculum: curriculum,
      ),
      'White',
    );
    expect(
      initialCurriculumBelt(
        selectedStudentBelt: 'Unknown',
        beltOrder: const ['No Belt', 'White'],
        curriculum: curriculum,
      ),
      'No Belt',
    );
    expect(
      initialCurriculumBelt(
        selectedStudentBelt: 'Unknown',
        beltOrder: const ['White'],
        curriculum: {'White': curriculum['White']!},
      ),
      'White',
    );
    expect(
      initialCurriculumBelt(
        selectedStudentBelt: 'Unknown',
        beltOrder: const [],
        curriculum: const {},
      ),
      isNull,
    );
  });

  test('YouTube parser accepts videos and rejects channel or invalid URLs', () {
    expect(youtubeVideoId('abcdefghijk'), 'abcdefghijk');
    expect(
      youtubeVideoId('https://www.youtube.com/watch?v=abcdefghijk'),
      'abcdefghijk',
    );
    expect(youtubeVideoId('https://youtu.be/abcdefghijk'), 'abcdefghijk');
    expect(
      youtubeVideoId('https://youtube.com/shorts/abcdefghijk'),
      'abcdefghijk',
    );
    expect(
      youtubeVideoId('https://youtube.com/@OlympicTaekwondoAcademy'),
      isNull,
    );
    expect(youtubeVideoId('not a video'), isNull);
  });

  testWidgets('curriculum defaults to selected belt and shows five cards', (
    tester,
  ) async {
    final service = _CurriculumTestService(
      selectedBelt: 'White',
      curriculum: {
        'No Belt': _testCurriculum('No Belt'),
        'White': _testCurriculum('White'),
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(dataService: service)),
    );

    expect(find.text('White Belt'), findsOneWidget);
    for (final title in const [
      'Forms',
      'One-Step Sparring',
      'Breaking Techniques',
      'Kicking Combinations',
      'Physical Challenges',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('None for this belt'), findsNWidgets(5));
  });

  testWidgets('curriculum renders multiple text and video items safely', (
    tester,
  ) async {
    final curriculum = _testCurriculum(
      'No Belt',
      forms: const [
        CurriculumItem(
          id: 'form-1',
          title: 'First form',
          contentType: CurriculumContentType.video,
          sortOrder: 0,
          videoUrl: 'abcdefghijk',
        ),
        CurriculumItem(
          id: 'form-2',
          title: 'Second form',
          contentType: CurriculumContentType.video,
          sortOrder: 1,
          videoUrl: 'lmnopqrstuv',
        ),
        CurriculumItem(
          id: 'form-3',
          title: 'Future form',
          contentType: CurriculumContentType.video,
          sortOrder: 2,
          videoUrl: 'invalid',
        ),
      ],
      oneSteps: const [
        CurriculumItem(
          id: 'step-1',
          title: 'First step',
          contentType: CurriculumContentType.text,
          sortOrder: 0,
          textContent: 'First step details',
        ),
        CurriculumItem(
          id: 'step-2',
          title: 'Second step',
          contentType: CurriculumContentType.text,
          sortOrder: 1,
        ),
      ],
    );
    final service = _CurriculumTestService(
      selectedBelt: 'Unknown',
      curriculum: {'No Belt': curriculum},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumScreen(
          dataService: service,
          videoBuilder: (context, videoId) => Text('player:$videoId'),
        ),
      ),
    );

    expect(find.text('No Belt'), findsOneWidget);
    expect(find.text('player:abcdefghijk'), findsOneWidget);
    expect(find.text('player:lmnopqrstuv'), findsOneWidget);
    expect(find.text('Video coming soon'), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(find.text('First step details'), findsOneWidget);
    expect(find.text('Second step'), findsOneWidget);
    expect(find.textContaining('youtube.com/@'), findsNothing);
  });

  testWidgets('embedded player identity changes with the video ID', (
    tester,
  ) async {
    var videoId = 'abcdefghijk';
    late StateSetter updateVideo;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateVideo = setState;
            return Scaffold(
              body: CurriculumSectionCard(
                section: CurriculumSection(
                  id: 'forms',
                  title: 'Forms',
                  sortOrder: 0,
                  items: [
                    CurriculumItem(
                      id: 'form-1',
                      title: 'Form',
                      contentType: CurriculumContentType.video,
                      sortOrder: 0,
                      videoUrl: videoId,
                    ),
                  ],
                ),
                videoBuilder: (context, parsedVideoId) =>
                    Text('player:$parsedVideoId'),
              ),
            );
          },
        ),
      ),
    );

    const firstKey = ValueKey<String>('youtube-player-abcdefghijk');
    const secondKey = ValueKey<String>('youtube-player-lmnopqrstuv');
    expect(find.byKey(firstKey), findsOneWidget);
    expect(find.byKey(secondKey), findsNothing);

    updateVideo(() => videoId = 'lmnopqrstuv');
    await tester.pump();

    expect(find.byKey(firstKey), findsNothing);
    expect(find.byKey(secondKey), findsOneWidget);
    expect(find.text('player:lmnopqrstuv'), findsOneWidget);
  });

  testWidgets('curriculum fits a narrow mobile layout', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _CurriculumTestService(
      selectedBelt: 'No Belt',
      curriculum: {'No Belt': _testCurriculum('No Belt')},
    );

    await tester.pumpWidget(
      MaterialApp(home: CurriculumScreen(dataService: service)),
    );
    expect(tester.takeException(), isNull);
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
      classTypeId: 'teen-adult-sparring',
      bulkGroupId: 'teen-adult-sparring-standard',
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
    expect(data.bulkGroupId, 'teen-adult-sparring-standard');
    expect(minutesForTimeOfDay(const TimeOfDay(hour: 19, minute: 20)), 1160);
  });

  test('resource write fields preserve edit identity and schema', () {
    final createdAt = DateTime.utc(2026, 6, 1, 12);
    final now = DateTime.utc(2026, 7, 11, 15);
    final resource = AcademyResource(
      id: 'existing-resource',
      title: 'Original',
      description: 'Original description',
      resourceType: 'document',
      category: 'forms',
      locationId: 'ota-cheshire',
      isPublished: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final data = ResourceWriteData.fromResource(
      resource,
      title: 'Updated',
      description: 'Updated description',
      resourceType: 'document',
      category: 'forms',
      locationId: resource.locationId,
      isPublished: true,
      linkUrl: 'https://example.com/resource',
    );
    final fields = resourceWriteFields(data, now: now);

    expect(data.id, 'existing-resource');
    expect(data.createdAt, createdAt);
    expect(fields['resourceSection'], 'general');
    expect(fields['locationId'], 'ota-cheshire');
    expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    expect((fields['updatedAt']! as Timestamp).toDate().toUtc(), now);
    expect(
      fields.keys,
      containsAll(<String>{
        'title',
        'description',
        'resourceSection',
        'resourceType',
        'category',
        'linkUrl',
        'locationId',
        'isPublished',
        'isArchived',
        'createdAt',
        'updatedAt',
      }),
    );
  });

  test('event write fields synchronize and can clear primary resource', () {
    final createdAt = DateTime.utc(2026, 6, 1, 12);
    final now = DateTime.utc(2026, 7, 11, 15);
    final event = AcademyEvent(
      id: 'event-1',
      title: 'Event',
      description: 'Description',
      locationId: 'ota-cheshire',
      eventType: 'specialEvent',
      startDateTime: DateTime.utc(2026, 7, 20, 23, 30),
      endDateTime: DateTime.utc(2026, 7, 21, 1),
      linkedResourceIds: const ['old-resource'],
      primaryRegistrationResourceId: 'old-resource',
      isPublished: false,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final cleared = EventWriteData.fromEvent(
      event,
      title: event.title,
      description: event.description,
      locationId: event.locationId,
      eventType: event.eventType,
      startDateTime: event.startDateTime,
      endDateTime: event.endDateTime,
      linkedResourceIds: const [],
      primaryRegistrationResourceId: null,
      isPublished: false,
    );
    expect(cleared.primaryRegistrationResourceId, isNull);

    final linked = EventWriteData(
      id: event.id,
      title: event.title,
      description: event.description,
      locationId: event.locationId,
      eventType: event.eventType,
      startDateTime: event.startDateTime,
      endDateTime: event.endDateTime,
      linkedResourceIds: const ['new-resource'],
      primaryRegistrationResourceId: 'new-resource',
      isPublished: true,
      createdAt: createdAt,
    );
    final fields = eventWriteFields(linked, now: now);
    expect(fields['linkedResourceIds'], ['new-resource']);
    expect(fields['primaryRegistrationResourceId'], 'new-resource');
    expect(
      (fields['startDateTime']! as Timestamp).toDate().toUtc(),
      event.startDateTime,
    );
    expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    expect(
      fields.keys,
      containsAll(<String>{
        'title',
        'description',
        'locationId',
        'eventType',
        'startDateTime',
        'endDateTime',
        'registrationDeadline',
        'linkedResourceIds',
        'primaryRegistrationResourceId',
        'isPublished',
        'isArchived',
        'createdAt',
        'updatedAt',
      }),
    );
  });

  test('event writes allow no resource and reject contradictory links', () {
    EventWriteData data({
      required bool published,
      List<String> linked = const <String>[],
      String? primary,
    }) => EventWriteData(
      title: 'Event',
      description: 'Description',
      locationId: 'ota-cheshire',
      eventType: 'specialEvent',
      startDateTime: DateTime.utc(2026, 8, 1),
      endDateTime: DateTime.utc(2026, 8, 1, 1),
      linkedResourceIds: linked,
      primaryRegistrationResourceId: primary,
      isPublished: published,
    );

    expect(
      eventWriteFields(
        data(published: true),
        now: DateTime.utc(2026),
      )['linkedResourceIds'],
      isEmpty,
    );
    expect(
      () => eventWriteFields(
        data(published: false, linked: const ['one', 'two'], primary: 'one'),
        now: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      () => eventWriteFields(
        data(published: false, linked: const ['one'], primary: 'two'),
        now: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
    expect(
      eventWriteFields(
        data(published: false),
        now: DateTime.utc(2026),
      )['linkedResourceIds'],
      isEmpty,
    );
  });

  test('class session write fields preserve schedule edit metadata', () {
    final createdAt = DateTime.utc(2026, 6, 1, 12);
    final now = DateTime.utc(2026, 7, 11, 15);
    final data = ClassSessionWriteData(
      id: 'fri-sparring',
      className: 'Teen/Adult Sparring',
      classTypeId: 'teen-adult-sparring',
      bulkGroupId: 'teen-adult-sparring-standard',
      locationId: 'ota-cheshire',
      weekday: DateTime.friday,
      startMinutes: 1160,
      endMinutes: 1200,
      eligibleBelts: const ['Red-Black', 'Black'],
      description: 'Sparring',
      eligibilityNote: 'Instructor approval',
      isActive: true,
      isPreferred: false,
      createdAt: createdAt,
    );
    final fields = classSessionWriteFields(data, now: now);

    expect(fields['weekday'], DateTime.friday);
    expect(fields['startMinutes'], 1160);
    expect(fields['endMinutes'], 1200);
    expect(fields['bulkGroupId'], 'teen-adult-sparring-standard');
    expect((fields['createdAt']! as Timestamp).toDate().toUtc(), createdAt);
    expect(
      fields.keys,
      containsAll(<String>{
        'className',
        'classTypeId',
        'bulkGroupId',
        'locationId',
        'weekday',
        'startMinutes',
        'endMinutes',
        'eligibleBelts',
        'description',
        'eligibilityNote',
        'isActive',
        'isPreferred',
        'createdAt',
        'updatedAt',
      }),
    );
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

  test('event writes use only General Resource registration fields', () {
    final fields = eventWriteFields(
      EventWriteData(
        title: 'Event',
        description: 'Description',
        locationId: 'ota-cheshire',
        eventType: 'specialEvent',
        startDateTime: DateTime.utc(2026, 8, 1),
        endDateTime: DateTime.utc(2026, 8, 1, 1),
        primaryRegistrationResourceId: 'registration-resource',
        linkedResourceIds: const ['registration-resource'],
        isPublished: true,
      ),
      now: DateTime.utc(2026, 7, 12),
    );

    expect(fields, isNot(contains('registrationUrl')));
    expect(fields, isNot(contains('showInResources')));
    expect(fields['linkedResourceIds'], ['registration-resource']);
  });

  test('event parser ignores removed legacy event fields', () {
    final event = academyEventFromFirestoreData('event', {
      'title': 'Event',
      'locationId': 'ota-cheshire',
      'startDateTime': Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
      'registrationUrl': 'https://legacy.example',
      'showInResources': true,
    });

    expect(event, isNotNull);
    expect(event!.primaryRegistrationResourceId, isNull);
    expect(event.registrationLabel, 'No registration');
  });

  test(
    'student calendar filtering keeps published past matching events only',
    () {
      final visible = _testEvent(
        id: 'past',
        title: 'Past Event',
        start: DateTime.utc(2025, 1, 1, 15),
        end: DateTime.utc(2025, 1, 1, 16),
      );
      final filtered = visibleStudentCalendarEvents([
        visible,
        _testEvent(
          id: 'draft',
          title: 'Draft',
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 1, 1),
          published: false,
        ),
        _testEvent(
          id: 'archived',
          title: 'Archived',
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 1, 1),
          archived: true,
        ),
        _testEvent(
          id: 'closure',
          title: 'Closure',
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 1, 1),
          eventType: 'closure',
        ),
        _testEvent(
          id: 'other-location',
          title: 'Other',
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 1, 1, 1),
          locationId: 'other',
        ),
      ], locationId: 'ota-cheshire');

      expect(filtered, [visible]);
    },
  );

  test(
    'academy-local multi-day event dates cross DST month and year safely',
    () {
      final dstEvent = _testEvent(
        id: 'dst',
        title: 'DST Event',
        start: DateTime.utc(2026, 3, 8, 4, 30),
        end: DateTime.utc(2026, 3, 9, 3, 30),
      );
      expect(eventAcademyLocalStartDate(dstEvent), DateTime(2026, 3, 7));
      expect(eventAcademyLocalEndDate(dstEvent), DateTime(2026, 3, 8));
      expect(eventOccursOnAcademyDate(dstEvent, DateTime(2026, 3, 7)), isTrue);
      expect(eventOccursOnAcademyDate(dstEvent, DateTime(2026, 3, 8)), isTrue);
      expect(eventOccursOnAcademyDate(dstEvent, DateTime(2026, 3, 9)), isFalse);

      final yearEvent = _testEvent(
        id: 'year',
        title: 'New Year Event',
        start: DateTime.utc(2027, 1, 1, 4),
        end: DateTime.utc(2027, 1, 1, 6),
      );
      expect(
        eventOccursOnAcademyDate(yearEvent, DateTime(2026, 12, 31)),
        isTrue,
      );
      expect(eventOccursOnAcademyDate(yearEvent, DateTime(2027, 1, 1)), isTrue);
      expect(monthGridDates(DateTime(2026, 12)).length % 7, 0);
      expect(
        monthGridDates(DateTime(2027, 1)).whereType<DateTime>().length,
        31,
      );
    },
  );

  test('student profile writes date of birth and never age', () {
    final fields = studentProfileWriteFields(sampleStudent);
    expect(fields['dateOfBirth'], isA<Timestamp>());
    expect(fields, isNot(contains('age')));
  });

  test('computed age handles birthday boundaries', () {
    final student = Student(
      id: 'student',
      name: 'Student',
      locationId: 'ota-cheshire',
      belt: 'Black',
      dateOfBirth: DateTime(2009, 7, 12),
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Second Dan',
    );

    expect(student.ageOn(DateTime(2026, 7, 11)), 16);
    expect(student.ageOn(DateTime(2026, 7, 12)), 17);
  });

  test('student parser temporarily falls back to legacy age', () {
    final student = studentProfileFromFirestoreData('student', {
      'fullName': 'Student',
      'locationId': 'ota-cheshire',
      'beltRank': 'Black',
      'age': 17,
    });

    expect(student, isNotNull);
    expect(student!.dateOfBirth, isNull);
    expect(student.legacyAge, 17);
  });

  test('approved schema update contains targeted updates and no deletes', () {
    final operations = approvedSchemaUpdateOperations();
    expect(operations, hasLength(9));
    expect(
      operations.every((operation) => operation.documentId.isNotEmpty),
      isTrue,
    );
    final session = operations.first;
    expect(session.fields, approvedTeenAdultSparringUpdate());
    final event = operations.firstWhere(
      (operation) => operation.documentId == 'parent_night_out',
    );
    expect(event.fields['registrationUrl'], isA<FieldValue>());
    expect(event.fields['showInResources'], isA<FieldValue>());
    final student = operations.firstWhere(
      (operation) => operation.documentId == 'student_sudhamsu',
    );
    expect(student.fields['dateOfBirth'], isA<Timestamp>());
    expect(student.fields['age'], isA<FieldValue>());
  });
}

CurriculumRequirement _testCurriculum(
  String belt, {
  List<CurriculumItem> forms = const <CurriculumItem>[],
  List<CurriculumItem> oneSteps = const <CurriculumItem>[],
}) {
  return CurriculumRequirement(
    locationId: 'ota-cheshire',
    belt: belt,
    sections: <CurriculumSection>[
      CurriculumSection(
        id: 'forms',
        title: 'Forms',
        sortOrder: 0,
        items: forms,
      ),
      CurriculumSection(
        id: 'one-step-sparring',
        title: 'One-Step Sparring',
        sortOrder: 1,
        items: oneSteps,
      ),
      const CurriculumSection(
        id: 'breaking-techniques',
        title: 'Breaking Techniques',
        sortOrder: 2,
      ),
      const CurriculumSection(
        id: 'kicking-combinations',
        title: 'Kicking Combinations',
        sortOrder: 3,
      ),
      const CurriculumSection(
        id: 'physical-challenges',
        title: 'Physical Challenges',
        sortOrder: 4,
      ),
    ],
  );
}

class _CurriculumTestService extends MockAppDataService {
  _CurriculumTestService({
    required this.selectedBelt,
    required this.curriculum,
  });

  final String selectedBelt;

  @override
  final Map<String, CurriculumRequirement> curriculum;

  @override
  Student get selectedStudentProfile => Student(
    id: 'student',
    name: 'Student',
    locationId: 'ota-cheshire',
    belt: selectedBelt,
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'White',
  );

  @override
  List<String> get curriculumBeltOrder => curriculum.keys.toList();

  @override
  CurriculumRequirement curriculumForBelt(String belt) =>
      curriculum[belt] ?? curriculum.values.first;

  @override
  String beltDisplayLabel(String belt) =>
      curriculum_data.beltDisplayLabel(belt);
}

AcademyEvent _testEvent({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
  String locationId = 'ota-cheshire',
  String eventType = 'specialEvent',
  bool published = true,
  bool archived = false,
}) {
  return AcademyEvent(
    id: id,
    title: title,
    description: '$title description',
    locationId: locationId,
    eventType: eventType,
    startDateTime: start,
    endDateTime: end,
    isPublished: published,
    isArchived: archived,
    createdAt: DateTime.utc(2025),
    updatedAt: DateTime.utc(2025),
  );
}

class _EventsTestService extends MockAppDataService {
  const _EventsTestService({required this.events});

  @override
  final List<AcademyEvent> events;

  @override
  List<AcademyResource> get resources => const <AcademyResource>[];
}

class _LiveEventsTestService extends MockAppDataService {
  _LiveEventsTestService(List<AcademyEvent> events)
    : _events = List<AcademyEvent>.from(events);

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  List<AcademyEvent> _events;

  @override
  List<AcademyEvent> get events => List<AcademyEvent>.unmodifiable(_events);

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void replaceEvent(AcademyEvent event) {
    _events = <AcademyEvent>[event];
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
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
