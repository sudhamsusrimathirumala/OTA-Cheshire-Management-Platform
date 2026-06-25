import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/curriculum_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/ota_colors.dart';

void main() => runApp(const OTAApp());

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
      initialRoute: OtaRoutes.dashboard,
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
    );
  }
}
