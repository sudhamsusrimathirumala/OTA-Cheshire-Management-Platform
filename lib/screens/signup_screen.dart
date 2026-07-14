import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/firebase/firebase_authentication_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_auth_switch_link.dart';
import '../widgets/ota_auth_text_field.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      await firebaseSessionController.authentication.signUpWithEmail(
        _email.text,
        _password.text,
      );
      await firebaseSessionController.authentication.sendVerificationEmail();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on AuthenticationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OtaBrandedScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: OtaLogoMark(size: 118, isCompact: true)),
                  const SizedBox(height: 20),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: OtaColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 26),
                  OtaAuthTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        value != null &&
                            RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(value.trim())
                        ? null
                        : 'Enter a valid email address.',
                  ),
                  const SizedBox(height: 14),
                  OtaAuthTextField(
                    label: 'Password',
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value?.length ?? 0) >= 8
                        ? null
                        : 'Use at least 8 characters.',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OtaAuthTextField(
                    label: 'Confirm Password',
                    controller: _confirmation,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    validator: (value) => value == _password.text
                        ? null
                        : 'Passwords do not match.',
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFFD8D8)),
                        ),
                      ),
                    ),
                  OtaActionButton(
                    label: _loading ? 'CREATING ACCOUNT...' : 'CREATE ACCOUNT',
                    onPressed: _loading ? null : _createAccount,
                  ),
                  const SizedBox(height: 14),
                  OtaActionButton(
                    label: 'CONTINUE WITH GOOGLE',
                    variant: OtaActionButtonVariant.secondary,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    onPressed: _loading
                        ? null
                        : () => _run(
                            firebaseSessionController
                                .authentication
                                .signInWithGoogle,
                          ),
                  ),
                  const SizedBox(height: 24),
                  OtaAuthSwitchLink(
                    prompt: 'Already have an account?',
                    action: 'Login',
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(OtaRoutes.login),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
