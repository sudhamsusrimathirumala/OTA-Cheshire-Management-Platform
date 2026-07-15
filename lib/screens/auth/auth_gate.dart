import 'package:flutter/material.dart';

import '../../services/firebase/firebase_session_controller.dart';
import '../admin/admin_dashboard_screen.dart';
import '../membership_status_screen.dart';
import '../student_dashboard_screen.dart';
import '../welcome_screen.dart';
import 'profile_creation_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: firebaseSessionController,
    builder: (context, _) {
      return authGateDestination(
        stage: firebaseSessionController.stage,
        errorMessage: firebaseSessionController.errorMessage,
      );
    },
  );
}

@visibleForTesting
Widget authGateDestination({
  required SessionStage stage,
  String? errorMessage,
}) => switch (stage) {
  SessionStage.loading => const _LoadingScreen(),
  SessionStage.signedOut => const WelcomeScreen(),
  SessionStage.needsProfiles => const ProfileCreationScreen(),
  SessionStage.incomplete ||
  SessionStage.pending ||
  SessionStage.rejected ||
  SessionStage.disabled => const MembershipStatusScreen(),
  SessionStage.adminDisabled => _SessionErrorScreen(
    message: errorMessage ?? 'This administrator account is unavailable.',
  ),
  SessionStage.approved => const StudentDashboardScreen(),
  SessionStage.admin => const AdminDashboardScreen(),
  SessionStage.error => _SessionErrorScreen(
    message: errorMessage ?? 'Your account could not be loaded.',
  ),
};

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your OTA account...'),
        ],
      ),
    ),
  );
}

class _SessionErrorScreen extends StatelessWidget {
  const _SessionErrorScreen({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_problem_rounded, size: 54),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: firebaseSessionController.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              TextButton(
                onPressed: firebaseSessionController.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
