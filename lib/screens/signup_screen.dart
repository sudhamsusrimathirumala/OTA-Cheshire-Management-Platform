import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_auth_switch_link.dart';
import '../widgets/ota_auth_text_field.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return OtaBrandedScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 48.0 : 24.0;
          final logoSize = constraints.maxWidth >= 600 ? 150.0 : 118.0;

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
                    const SizedBox(height: 24),
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: OtaColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join Olympic Taekwondo Academy management.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: OtaColors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const OtaAuthTextField(
                      label: 'First Name',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const OtaAuthTextField(
                      label: 'Last Name',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const OtaAuthTextField(
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const OtaAuthTextField(
                      label: 'Password',
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    const OtaAuthTextField(
                      label: 'Confirm Password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),
                    OtaActionButton(
                      label: 'CREATE ACCOUNT',
                      onPressed: () {
                        // TODO: Implement account creation action.
                      },
                    ),
                    const SizedBox(height: 14),
                    OtaActionButton(
                      label: 'CONTINUE WITH GOOGLE',
                      variant: OtaActionButtonVariant.secondary,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      onPressed: () {
                        // TODO: Implement Google sign-up.
                      },
                    ),
                    const SizedBox(height: 24),
                    OtaAuthSwitchLink(
                      prompt: 'Already have an account?',
                      action: 'Login',
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(OtaRoutes.login);
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
