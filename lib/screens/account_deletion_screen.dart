import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_account.dart';
import '../services/debug_view_controller.dart';
import '../services/firebase/account_deletion_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../theme/ota_colors.dart';

enum _DeletionStep { explanation, reauthentication, confirmation }

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    this.service,
    this.accountOverride,
    this.suspendSession,
    this.completeSession,
    this.restoreSession,
    this.currentFirebaseUid,
    super.key,
  });

  final AccountDeletionService? service;
  final UserAccount? accountOverride;
  final Future<void> Function()? suspendSession;
  final Future<void> Function()? completeSession;
  final Future<void> Function()? restoreSession;
  final String? Function()? currentFirebaseUid;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late final AccountDeletionService _service;
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  _DeletionStep _step = _DeletionStep.explanation;
  AccountReauthenticationMethod? _method;
  AccountDeletionAuthorization? _authorization;
  bool _busy = false;
  bool _firestoreDeletionCompleted = false;
  bool _recoveringAuthenticationDeletion = false;
  String? _message;
  AccountDeletionDebugDiagnostics? _debugDiagnostics;

  UserAccount? get _account =>
      widget.accountOverride ?? firebaseSessionController.account;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        createFirebaseAccountDeletionService(
          authentication: firebaseSessionController.authentication,
        );
    final methods = _service.availableMethods;
    if (methods.length == 1) _method = methods.single;
    _confirmationController.addListener(_confirmationChanged);
  }

  @override
  void dispose() {
    _passwordController
      ..clear()
      ..dispose();
    _confirmationController
      ..removeListener(_confirmationChanged)
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _confirmationChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final privileged =
        account?.role == UserAccountRole.admin ||
        account?.role == UserAccountRole.superAdmin;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: OtaColors.blush,
        appBar: AppBar(
          title: const Text('Delete Account'),
          backgroundColor: OtaColors.blush,
          foregroundColor: OtaColors.ink,
          automaticallyImplyLeading: !_busy,
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 44,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: privileged
                        ? const _PrivilegedAccountRestriction()
                        : _buildMemberFlow(context, account),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberFlow(BuildContext context, UserAccount? account) {
    if (account == null) {
      return const _MessageCard(
        icon: Icons.person_off_outlined,
        title: 'Account unavailable',
        message: 'Sign in again before deleting your account.',
      );
    }
    return switch (_step) {
      _DeletionStep.explanation => _ExplanationStep(
        profileCount: account.linkedStudentProfileIds.length,
        onContinue: () => setState(() {
          _message = null;
          _step = _DeletionStep.reauthentication;
        }),
      ),
      _DeletionStep.reauthentication => _buildReauthenticationStep(),
      _DeletionStep.confirmation => _buildConfirmationStep(account),
    };
  }

  Widget _buildReauthenticationStep() {
    final methods = _service.availableMethods;
    if (methods.isEmpty) {
      return const _MessageCard(
        icon: Icons.no_accounts_outlined,
        title: 'Verification unavailable',
        message:
            'This account does not have a supported password or Google '
            'sign-in method. Contact the academy.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          step: 'Step 2 of 3',
          title: 'Verify your identity',
          message:
              'Recent sign-in verification is required immediately before '
              'permanent deletion.',
        ),
        const SizedBox(height: 18),
        if (methods.length > 1) ...[
          _MethodTile(
            label: 'Current password',
            icon: Icons.password_rounded,
            selected: _method == AccountReauthenticationMethod.password,
            onTap: _busy
                ? null
                : () => setState(() {
                    _method = AccountReauthenticationMethod.password;
                    _message = null;
                  }),
          ),
          const SizedBox(height: 10),
          _MethodTile(
            label: 'Google Sign-In',
            icon: Icons.account_circle_outlined,
            selected: _method == AccountReauthenticationMethod.google,
            onTap: _busy
                ? null
                : () => setState(() {
                    _method = AccountReauthenticationMethod.google;
                    _message = null;
                  }),
          ),
          const SizedBox(height: 18),
        ],
        if (_method == AccountReauthenticationMethod.password)
          TextField(
            controller: _passwordController,
            obscureText: true,
            enabled: !_busy,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
        if (_method == AccountReauthenticationMethod.google)
          const _MessageCard(
            icon: Icons.account_circle_outlined,
            title: 'Google verification',
            message:
                'Continue to choose and verify the Google account currently '
                'connected to OTA.',
          ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _InlineError(message: _message!),
        ],
        if (kDebugMode && _debugDiagnostics != null) ...[
          const SizedBox(height: 14),
          _AccountDeletionDiagnostics(value: _debugDiagnostics!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy || _method == null ? null : _reauthenticate,
          child: _busy
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify and continue'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _message = null;
                  _step = _DeletionStep.explanation;
                }),
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildConfirmationStep(UserAccount account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHeader(
          step: 'Step 3 of 3',
          title: 'Final confirmation',
          message:
              'Type DELETE exactly to permanently remove this login account '
              'and every linked student profile.',
        ),
        const SizedBox(height: 18),
        _DeletionSummary(profileCount: account.linkedStudentProfileIds.length),
        const SizedBox(height: 18),
        TextField(
          controller: _confirmationController,
          enabled: !_busy && !_firestoreDeletionCompleted,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Type DELETE',
            border: OutlineInputBorder(),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _InlineError(message: _message!),
        ],
        if (kDebugMode && _debugDiagnostics != null) ...[
          const SizedBox(height: 14),
          _AccountDeletionDiagnostics(value: _debugDiagnostics!),
        ],
        const SizedBox(height: 20),
        if (_firestoreDeletionCompleted)
          FilledButton(
            onPressed: _busy ? null : _retryAuthenticationDeletion,
            style: FilledButton.styleFrom(backgroundColor: OtaColors.actionRed),
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Retry sign-in account removal'),
          )
        else
          FilledButton.icon(
            onPressed: _busy || _confirmationController.text != 'DELETE'
                ? null
                : _deleteAccount,
            style: FilledButton.styleFrom(
              backgroundColor: OtaColors.actionRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Permanently delete account'),
          ),
        TextButton(
          onPressed: _busy || _firestoreDeletionCompleted
              ? null
              : () {
                  _authorization = null;
                  _confirmationController.clear();
                  setState(() {
                    _message = null;
                    _step = _DeletionStep.reauthentication;
                  });
                },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _reauthenticate() async {
    final method = _method;
    if (method == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final password = method == AccountReauthenticationMethod.password
          ? _passwordController.text
          : null;
      _authorization = _recoveringAuthenticationDeletion
          ? await _service.reauthenticateRemainingSignIn(
              method,
              password: password,
            )
          : await _service.reauthenticate(method, password: password);
      if (!mounted) return;
      setState(() => _step = _DeletionStep.confirmation);
    } on AccountDeletionException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Account verification failed. Please try again.',
        );
      }
    } finally {
      _passwordController.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final authorization = _authorization;
    if (authorization == null ||
        _confirmationController.text != 'DELETE' ||
        _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    var suspended = false;
    try {
      final firebaseUidBeforeSuspension = _readCurrentFirebaseUid();
      await (widget.suspendSession ??
          firebaseSessionController.suspendForAccountDeletion)();
      suspended = true;
      if (kDebugMode) {
        final firebaseUidAfterSuspension = _readCurrentFirebaseUid();
        setState(() {
          _debugDiagnostics = AccountDeletionDebugDiagnostics(
            authorizationUid: authorization.uid,
            firebaseUidBeforeSuspension: firebaseUidBeforeSuspension,
            firebaseUidAfterSuspension: firebaseUidAfterSuspension,
            deletionServiceUidAfterSuspension:
                _service.authGateway.currentIdentity?.uid,
          );
        });
      }
      await _service.deleteAccount(authorization);
      await _completeDeletion();
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      if (error.firestoreDeletionCompleted) {
        setState(() {
          _firestoreDeletionCompleted = true;
          _recoveringAuthenticationDeletion = true;
          _authorization = null;
          _step = _DeletionStep.reauthentication;
          _message =
              '${error.message} Verify your sign-in again before retrying.';
        });
      } else {
        if (suspended) await _restoreSession();
        if (mounted) setState(() => _message = error.message);
      }
    } catch (_) {
      if (suspended) await _restoreSession();
      if (mounted) {
        setState(
          () => _message = 'Account deletion failed safely. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryAuthenticationDeletion() async {
    final authorization = _authorization;
    if (authorization == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.retryAuthenticationDeletion(authorization);
      await _completeDeletion();
    } on AccountDeletionException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'The remaining sign-in account could not be removed. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeDeletion() async {
    debugViewController.clear();
    await (widget.completeSession ??
        firebaseSessionController.completeAccountDeletion)();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _restoreSession() async {
    await (widget.restoreSession ?? firebaseSessionController.retry)();
  }

  String? _readCurrentFirebaseUid() {
    final override = widget.currentFirebaseUid;
    if (override != null) return override();
    if (Firebase.apps.isEmpty) return _service.authGateway.currentIdentity?.uid;
    return FirebaseAuth.instance.currentUser?.uid;
  }
}

class AccountDeletionDebugDiagnostics {
  const AccountDeletionDebugDiagnostics({
    required this.authorizationUid,
    required this.firebaseUidBeforeSuspension,
    required this.firebaseUidAfterSuspension,
    required this.deletionServiceUidAfterSuspension,
  });

  final String authorizationUid;
  final String? firebaseUidBeforeSuspension;
  final String? firebaseUidAfterSuspension;
  final String? deletionServiceUidAfterSuspension;

  bool get firebaseCurrentUserBecameNull =>
      firebaseUidBeforeSuspension != null && firebaseUidAfterSuspension == null;
}

class _AccountDeletionDiagnostics extends StatelessWidget {
  const _AccountDeletionDiagnostics({required this.value});

  final AccountDeletionDebugDiagnostics value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: OtaColors.navy.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        color: OtaColors.ink,
        fontFamily: 'monospace',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deletion diagnostics (debug only)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('Authorization UID: ${value.authorizationUid}'),
          Text(
            'Firebase UID before suspension: '
            '${value.firebaseUidBeforeSuspension ?? 'null'}',
          ),
          Text(
            'Firebase UID after suspension: '
            '${value.firebaseUidAfterSuspension ?? 'null'}',
          ),
          Text(
            'FirebaseAuth.currentUser became null: '
            '${value.firebaseCurrentUserBecameNull ? 'Yes' : 'No'}',
          ),
          Text(
            'Deletion service UID after suspension: '
            '${value.deletionServiceUidAfterSuspension ?? 'null'}',
          ),
        ],
      ),
    ),
  );
}

class _ExplanationStep extends StatelessWidget {
  const _ExplanationStep({
    required this.profileCount,
    required this.onContinue,
  });

  final int profileCount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _StepHeader(
        step: 'Step 1 of 3',
        title: 'Permanent account deletion',
        message:
            'This is different from removing one child profile. It deletes '
            'the entire login account and every student profile linked to it.',
      ),
      const SizedBox(height: 18),
      _DeletionSummary(profileCount: profileCount),
      const SizedBox(height: 18),
      const _MessageCard(
        icon: Icons.warning_amber_rounded,
        title: 'This cannot be undone',
        message:
            'If this person returns, the account, student profiles, progress, '
            'and preferences must be recreated manually.',
      ),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: onContinue,
        child: const Text('Continue to verification'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _DeletionSummary extends StatelessWidget {
  const _DeletionSummary({required this.profileCount});
  final int profileCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: OtaColors.actionRed.withValues(alpha: 0.24)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bullet('The Firebase login account'),
        _bullet(
          '$profileCount linked student '
          '${profileCount == 1 ? 'profile' : 'profiles'}',
        ),
        _bullet('Belt, sticker, testing, and promotion progress'),
        _bullet('Preferred classes and profile preferences'),
        _bullet('Notification-read and registered-device records'),
      ],
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.remove_circle_outline,
            size: 18,
            color: OtaColors.actionRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _PrivilegedAccountRestriction extends StatelessWidget {
  const _PrivilegedAccountRestriction();

  @override
  Widget build(BuildContext context) => const _MessageCard(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Privileged account deletion is restricted',
    message:
        'Admin and Super Admin accounts cannot delete themselves here. '
        'The account must be removed by another authorized administrator.',
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.message,
  });

  final String step;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        step,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: OtaColors.maroon,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: OtaColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      Text(message, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: OtaColors.maroon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? OtaColors.maroon : OtaColors.mutedText,
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: OtaColors.navy.withValues(alpha: 0.08)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: OtaColors.maroon, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: OtaColors.softRed,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(
        color: OtaColors.actionRed,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
