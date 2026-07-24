import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import 'login_screen.dart' show authenticationDisplayMessage;
import '../services/firebase/firebase_authentication_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/debug_view_controller.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_auth_switch_link.dart';
import '../widgets/ota_auth_text_field.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    this.emailSignUp,
    this.googleSignIn,
    this.emailSignupSessionTransition,
  });

  final Future<Object?> Function(String email, String password)? emailSignUp;
  final Future<Object?> Function()? googleSignIn;
  final Future<SessionStage> Function()? emailSignupSessionTransition;

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
  bool _emailAccountCreated = false;
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
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_emailAccountCreated) {
        await (widget.emailSignUp?.call(_email.text, _password.text) ??
            firebaseSessionController.authentication.signUpWithEmail(
              _email.text,
              _password.text,
            ));
        _emailAccountCreated = true;
      }

      final stage = await _completeEmailSignupSession();
      if (stage != SessionStage.needsProfiles) {
        throw const _SignupSessionTransitionException();
      }
      if (!mounted) return;
      _openAuthGate();
    } on AuthenticationException catch (error) {
      if (mounted) {
        setState(
          () => _error = _emailAccountCreated
              ? _SignupSessionTransitionException.message
              : authenticationDisplayMessage(
                  error,
                  includeDiagnostic: kDebugMode,
                ),
        );
      }
    } on _SignupSessionTransitionException {
      if (mounted) {
        setState(() => _error = _SignupSessionTransitionException.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _emailAccountCreated
              ? _SignupSessionTransitionException.message
              : 'Account creation could not be completed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<SessionStage> _completeEmailSignupSession() {
    final transition = widget.emailSignupSessionTransition;
    if (transition != null) return transition();
    if (widget.emailSignUp != null) {
      return Future.value(SessionStage.needsProfiles);
    }
    return firebaseSessionController.adoptAuthenticatedUserAfterSignup();
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      _openAuthGate();
    } on AuthenticationException catch (error) {
      if (mounted) {
        setState(
          () => _error = authenticationDisplayMessage(
            error,
            includeDiagnostic: kDebugMode,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Account creation could not be completed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAuthGate() {
    debugViewController.clear();
    Navigator.of(context).pushNamedAndRemoveUntil(OtaRoutes.gate, (_) => false);
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
                            () =>
                                widget.googleSignIn?.call() ??
                                firebaseSessionController.authentication
                                    .signInWithGoogle(),
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

class _SignupSessionTransitionException implements Exception {
  const _SignupSessionTransitionException();

  static const message =
      'Your account was created, but profile setup could not be opened. Please return to Login and sign in.';
}
