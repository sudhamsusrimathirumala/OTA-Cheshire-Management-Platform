import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/firebase/firebase_authentication_service.dart';
import '../../services/firebase/firebase_session_controller.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/ota_action_button.dart';
import '../../widgets/ota_branded_scaffold.dart';
import '../../widgets/ota_logo_mark.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _loading = false;
  int _cooldown = 0;
  String? _message;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    await _run(() async {
      await firebaseSessionController.authentication.sendVerificationEmail();
      _cooldown = 60;
      _message = 'Verification email sent. Check your inbox and spam folder.';
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _cooldown--);
        if (_cooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _refresh() async {
    await _run(() async {
      final user = await firebaseSessionController.authentication.refreshUser();
      _message = user?.emailVerified == true
          ? 'Email verified. Continuing...'
          : 'Verification is not visible yet. Try again after opening the link.';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await action();
    } on AuthenticationException catch (error) {
      _message = error.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = firebaseSessionController.authUser?.email ?? '';
    return OtaBrandedScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: OtaLogoMark(size: 112, isCompact: true)),
                const SizedBox(height: 24),
                Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: OtaColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OtaColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Open the verification link we sent, then return here. Check your spam folder if it is not in your inbox.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OtaColors.white.withValues(alpha: .88),
                  ),
                ),
                const SizedBox(height: 24),
                OtaActionButton(
                  label: _loading ? 'CHECKING...' : 'I VERIFIED MY EMAIL',
                  onPressed: _loading ? null : _refresh,
                ),
                const SizedBox(height: 12),
                OtaActionButton(
                  label: _cooldown > 0
                      ? 'RESEND IN $_cooldown SECONDS'
                      : 'RESEND VERIFICATION EMAIL',
                  variant: OtaActionButtonVariant.secondary,
                  onPressed: _loading || _cooldown > 0 ? null : _resend,
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OtaColors.white),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : firebaseSessionController.signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: TextButton.styleFrom(foregroundColor: OtaColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
