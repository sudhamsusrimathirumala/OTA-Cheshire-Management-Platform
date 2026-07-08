import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/ota_colors.dart';
import '../widgets/debug_role_switcher.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_auth_switch_link.dart';
import '../widgets/ota_auth_text_field.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OtaBrandedScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 48.0 : 24.0;
          final logoSize = constraints.maxWidth >= 600 ? 150.0 : 122.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: OtaColors.navy.withValues(
                            alpha: 0.55,
                          ),
                          foregroundColor: OtaColors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(child: OtaLogoMark(size: logoSize, isCompact: true)),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: OtaColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your academy experience.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: OtaColors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      const DebugRoleSwitcher(),
                    ],
                    const SizedBox(height: 32),
                    const OtaAuthTextField(
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    const OtaAuthTextField(
                      label: 'Password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password flow.
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: OtaColors.white,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OtaActionButton(
                      label: 'LOGIN',
                      onPressed: () {
                        // TODO: Implement login action.
                      },
                    ),
                    const SizedBox(height: 14),
                    OtaActionButton(
                      label: 'CONTINUE WITH GOOGLE',
                      variant: OtaActionButtonVariant.secondary,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      onPressed: () {
                        // TODO: Implement Google sign-in.
                      },
                    ),
                    const SizedBox(height: 24),
                    OtaAuthSwitchLink(
                      prompt: "Don't have an account?",
                      action: 'Sign Up',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(OtaRoutes.signup);
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
