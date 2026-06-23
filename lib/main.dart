import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
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
      initialRoute: OtaRoutes.welcome,
      routes: {
        OtaRoutes.welcome: (_) => const WelcomeScreen(),
        OtaRoutes.login: (_) => const LoginScreen(),
        OtaRoutes.signup: (_) => const SignupScreen(),
      },
    );
  }
}
