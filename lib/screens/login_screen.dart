import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/firebase/firebase_authentication_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/debug_view_controller.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_action_button.dart';
import '../widgets/ota_auth_switch_link.dart';
import '../widgets/ota_auth_text_field.dart';
import '../widgets/ota_branded_scaffold.dart';
import '../widgets/ota_logo_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.emailSignIn,
    this.googleSignIn,
    this.passwordReset,
  });

  final Future<Object?> Function(String email, String password)? emailSignIn;
  final Future<Object?> Function()? googleSignIn;
  final Future<void> Function(String email)? passwordReset;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    await _run(
      () =>
          widget.emailSignIn?.call(_email.text, _password.text) ??
          firebaseSessionController.authentication.signInWithEmail(
            _email.text,
            _password.text,
          ),
    );
  }

  Future<void> _googleSignIn() async {
    await _run(
      () =>
          widget.googleSignIn?.call() ??
          firebaseSessionController.authentication.signInWithGoogle(),
    );
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
      debugViewController.clear();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(OtaRoutes.gate, (_) => false);
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
          () => _error = 'Sign-in could not be completed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPasswordReset() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordResetDialog(initialEmail: _email.text),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await (widget.passwordReset?.call(email) ??
          firebaseSessionController.authentication.sendPasswordReset(email));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists with this email, password reset instructions have been sent.',
          ),
        ),
      );
    } on AuthenticationException catch (error) {
      if (mounted) setState(() => _error = error.message);
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
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: OtaLogoMark(size: 122, isCompact: true)),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: OtaColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 28),
                    OtaAuthTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: _emailValidator,
                      onChanged: (_) => _clearServerError(),
                    ),
                    const SizedBox(height: 16),
                    OtaAuthTextField(
                      label: 'Password',
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null,
                      onChanged: (_) => _clearServerError(),
                      onFieldSubmitted: (_) => _loading ? null : _signIn(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _showPasswordReset,
                        style: TextButton.styleFrom(
                          foregroundColor: OtaColors.white,
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
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
                      label: _loading ? 'SIGNING IN...' : 'LOGIN',
                      onPressed: _loading ? null : _signIn,
                    ),
                    const SizedBox(height: 14),
                    OtaActionButton(
                      label: 'CONTINUE WITH GOOGLE',
                      variant: OtaActionButtonVariant.secondary,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      onPressed: _loading ? null : _googleSignIn,
                    ),
                    const SizedBox(height: 24),
                    OtaAuthSwitchLink(
                      prompt: "Don't have an account?",
                      action: 'Sign Up',
                      onTap: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(OtaRoutes.signup),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _clearServerError() {
    if (_error != null) setState(() => _error = null);
  }
}

String authenticationDisplayMessage(
  AuthenticationException error, {
  required bool includeDiagnostic,
}) {
  final code = error.diagnosticCode;
  if (!includeDiagnostic || code == null || code.isEmpty) return error.message;
  return '${error.message} (Code: $code)';
}

String? _emailValidator(String? value) =>
    value != null &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
    ? null
    : 'Enter a valid email address.';

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: AlertDialog(
      title: const Text('Reset password'),
      content: TextFormField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: _emailValidator,
        decoration: const InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, _controller.text.trim().toLowerCase());
          },
          child: const Text('Send reset email'),
        ),
      ],
    ),
  );
}
