import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'routes.dart';
import 'screens/admin/admin_announcements_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_events_screen.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'screens/admin/admin_schedule_screen.dart';
import 'screens/admin/admin_students_screen.dart';
import 'screens/curriculum_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/ota_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const OTAApp());
}

// TODO: Replace this mock launch switch with Firebase Auth and UserAccount.role
// based routing when real authentication is added.
const bool _launchAdminForDevelopment = true;

class OTAApp extends StatelessWidget {
  const OTAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Olympic Taekwondo Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OtaColors.maroon,
          brightness: Brightness.light,
        ),
      ),
      initialRoute: _launchAdminForDevelopment
          ? OtaRoutes.adminDashboard
          : OtaRoutes.dashboard,
      routes: {
        OtaRoutes.welcome: (_) => const WelcomeScreen(),
        OtaRoutes.dashboard: (_) => const StudentDashboardScreen(),
        OtaRoutes.schedule: (_) => const ScheduleScreen(),
        OtaRoutes.curriculum: (_) => const CurriculumScreen(),
        OtaRoutes.notifications: (_) => const NotificationsScreen(),
        OtaRoutes.profile: (_) => const ProfileScreen(),
        OtaRoutes.login: (_) => const LoginScreen(),
        OtaRoutes.signup: (_) => const SignupScreen(),
      },
      onGenerateRoute: _buildAdminRoute,
    );
  }
}

Route<dynamic>? _buildAdminRoute(RouteSettings settings) {
  final WidgetBuilder? builder = switch (settings.name) {
    OtaRoutes.adminDashboard => (_) => const AdminDashboardScreen(),
    OtaRoutes.adminStudents => (_) => const AdminStudentsScreen(),
    OtaRoutes.adminEvents => (_) => const AdminEventsScreen(),
    OtaRoutes.adminAnnouncements => (_) => const AdminAnnouncementsScreen(),
    OtaRoutes.adminSchedule => (_) => const AdminScheduleScreen(),
    OtaRoutes.adminProfile => (_) => const AdminProfileScreen(),
    _ => null,
  };

  if (builder == null) {
    return null;
  }

  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
