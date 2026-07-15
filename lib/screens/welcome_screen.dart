import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/debug_view_controller.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OtaBrandedScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 48.0 : 24.0;
          final isTablet = constraints.maxWidth >= 600;
          final logoSize = isTablet
              ? (constraints.maxWidth * 0.38).clamp(240.0, 280.0)
              : (constraints.maxWidth * 0.48).clamp(150.0, 230.0);
          final availableHeight = constraints.maxHeight - 48;
          final minimumContentHeight = kDebugMode
              ? logoSize + 540
              : logoSize + 400;
          final contentHeight = availableHeight > minimumContentHeight
              ? availableHeight
              : minimumContentHeight;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Center(
              child: SizedBox(
                width: 520,
                height: contentHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Center(child: OtaLogoMark(size: logoSize)),
                    const SizedBox(height: 32),
                    Text(
                      'WELCOME',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: OtaColors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Olympic Taekwondo Academy',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OtaColors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (kDebugMode) ...[
                      // Development-only shortcuts for visual UI work. The
                      // compile-time debug guard removes them from release.
                      const SizedBox(height: 24),
                      OtaActionButton(
                        label: 'Student View',
                        onPressed: () {
                          debugViewController.enterStudent();
                          Navigator.of(context).pushNamed(OtaRoutes.dashboard);
                        },
                      ),
                      const SizedBox(height: 14),
                      OtaActionButton(
                        label: 'Admin View',
                        variant: OtaActionButtonVariant.secondary,
                        onPressed: () {
                          debugViewController.enterAdmin();
                          Navigator.of(
                            context,
                          ).pushNamed(OtaRoutes.adminDashboard);
                        },
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 48),
                    OtaActionButton(
                      label: 'LOGIN',
                      onPressed: () {
                        Navigator.of(context).pushNamed(OtaRoutes.login);
                      },
                    ),
                    const SizedBox(height: 16),
                    OtaActionButton(
                      label: 'SIGN UP',
                      variant: OtaActionButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pushNamed(OtaRoutes.signup);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
