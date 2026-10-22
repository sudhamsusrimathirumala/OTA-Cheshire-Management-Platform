import 'package:flutter/material.dart';

import '../routes.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/guest/guest_dashboard_screen.dart';
import '../services/debug_view_controller.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/firebase/route_authorization.dart';
import '../services/guest/guest_experience_controller.dart';

/// Rechecks access before a mounted route can build with a cleared identity.
class AuthorizedRoute extends StatelessWidget {
  const AuthorizedRoute({
    required this.routeName,
    required this.builder,
    this.session,
    super.key,
  });

  final String? routeName;
  final WidgetBuilder builder;
  final FirebaseSessionController? session;

  @override
  Widget build(BuildContext context) {
    final controller = session ?? firebaseSessionController;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        debugViewController,
        guestExperienceController,
      ]),
      builder: (context, _) {
        if (!isRouteAuthorized(
          routeName: routeName,
          stage: controller.stage,
          debugMode: debugViewController.mode,
          guestMode: guestExperienceController.mode,
        )) {
          return AuthGate(session: controller);
        }
        final page = builder(context);
        return controller.stage == SessionStage.guest &&
                routeName != OtaRoutes.gate
            ? GuestModeShell(child: page)
            : page;
      },
    );
  }
}
