import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'routes.dart';
import 'screens/admin/admin_announcements_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_events_screen.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'screens/admin/admin_resources_screen.dart';
import 'screens/admin/admin_schedule_screen.dart';
import 'screens/admin/admin_students_screen.dart';
import 'screens/curriculum_screen.dart';
import 'screens/events_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/membership_status_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'services/firebase/firebase_session_controller.dart';
import 'services/firebase/route_authorization.dart';
import 'services/app_data_service_provider.dart';
import 'theme/ota_colors.dart';
import 'services/location_time_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocationTimeService.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  firebaseSessionController.start();
  initializeFirebaseAppDataService();
  runApp(const OTAApp());
}

class OTAApp extends StatefulWidget {
  const OTAApp({super.key});

  @override
  State<OTAApp> createState() => _OTAAppState();
}

class _OTAAppState extends State<OTAApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late SessionStage _previousStage;
  late bool _usesFirebase;

  @override
  void initState() {
    super.initState();
    _usesFirebase = Firebase.apps.isNotEmpty;
    _previousStage = _usesFirebase
        ? firebaseSessionController.stage
        : SessionStage.signedOut;
    if (_usesFirebase) {
      firebaseSessionController.addListener(_handleSessionChanged);
    }
  }

  void _handleSessionChanged() {
    final current = firebaseSessionController.stage;
    final shouldReset = protectedAccessWasLost(_previousStage, current);
    _previousStage = current;
    if (!shouldReset) return;
    setDevelopmentDataView(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        OtaRoutes.gate,
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    if (_usesFirebase) {
      firebaseSessionController.removeListener(_handleSessionChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Olympic Taekwondo Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OtaColors.maroon,
          brightness: Brightness.light,
        ),
      ),
      home: Firebase.apps.isNotEmpty ? const AuthGate() : const WelcomeScreen(),
      onGenerateRoute: _buildAuthorizedRoute,
    );
  }
}

Route<dynamic>? _buildAuthorizedRoute(RouteSettings settings) {
  final WidgetBuilder? builder = switch (settings.name) {
    OtaRoutes.gate => (_) => const AuthGate(),
    OtaRoutes.welcome => (_) => const WelcomeScreen(),
    OtaRoutes.dashboard => (_) => const StudentDashboardScreen(),
    OtaRoutes.schedule => (_) => const ScheduleScreen(),
    OtaRoutes.events => (_) => const EventsScreen(),
    OtaRoutes.resources => (_) => const ResourcesScreen(),
    OtaRoutes.generalResources => (_) => const GeneralResourcesScreen(),
    OtaRoutes.curriculum => (_) => const CurriculumScreen(),
    OtaRoutes.notifications => (_) => const NotificationsScreen(),
    OtaRoutes.profile => (_) => const ProfileScreen(),
    OtaRoutes.membership => (_) => const MembershipStatusScreen(),
    OtaRoutes.login => (_) => const LoginScreen(),
    OtaRoutes.signup => (_) => const SignupScreen(),
    OtaRoutes.adminDashboard => (_) => const AdminDashboardScreen(),
    OtaRoutes.adminStudents => (_) => const AdminStudentsScreen(),
    OtaRoutes.adminEvents => (_) => const AdminEventsScreen(),
    OtaRoutes.adminAnnouncements => (_) => const AdminAnnouncementsScreen(),
    OtaRoutes.adminSchedule => (_) => const AdminScheduleScreen(),
    OtaRoutes.adminResources => (_) => const AdminResourcesScreen(),
    OtaRoutes.adminGeneralResources =>
      (_) => const AdminGeneralResourcesScreen(),
    OtaRoutes.adminCurriculum => (_) => const CurriculumScreen(isAdmin: true),
    OtaRoutes.adminProfile => (_) => const AdminProfileScreen(),
    _ => null,
  };

  if (builder == null) {
    return null;
  }

  final developmentRequest = isDevelopmentNavigationRequest(settings.arguments);
  final authorized = isRouteAuthorized(
    routeName: settings.name,
    stage: Firebase.apps.isNotEmpty
        ? firebaseSessionController.stage
        : SessionStage.signedOut,
    arguments: settings.arguments,
  );
  setDevelopmentDataView(developmentRequest);
  final authorizedBuilder = authorized ? builder : (_) => const AuthGate();

  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) =>
        authorizedBuilder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
