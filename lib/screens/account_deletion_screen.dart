import 'package:flutter/material.dart';

import '../models/user_account.dart';
import '../services/debug_view_controller.dart';
import '../services/firebase/account_deletion_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../theme/ota_colors.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({
    this.service,
    this.accountOverride,
    this.completeSession,
    super.key,
  });

  final AccountDeletionService? service;
  final UserAccount? accountOverride;
  final Future<void> Function()? completeSession;

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  late final AccountDeletionService _service;
  final _passwordController = TextEditingController();
  AccountReauthenticationMethod? _method;
  bool _busy = false;
  String? _message;

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
    if (methods.contains(AccountReauthenticationMethod.password)) {
      _method = AccountReauthenticationMethod.password;
    } else if (methods.contains(AccountReauthenticationMethod.google)) {
      _method = AccountReauthenticationMethod.google;
    } else if (methods.contains(AccountReauthenticationMethod.apple)) {
      _method = AccountReauthenticationMethod.apple;
    }
  }

  @override
  void dispose() {
    _passwordController
      ..clear()
      ..dispose();
    super.dispose();
  }

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
                        : _buildMemberFlow(account),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberFlow(UserAccount? account) {
    if (account == null) {
      return const _MessageCard(
        icon: Icons.person_off_outlined,
        title: 'Account unavailable',
        message: 'Sign in again before deleting your account.',
      );
    }
    final methods = _service.availableMethods;
    if (methods.isEmpty) {
      return const _MessageCard(
        icon: Icons.no_accounts_outlined,
        title: 'Verification unavailable',
        message:
            'This account does not have a supported password, Google, or Apple '
            'sign-in method. Contact the academy.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Permanent account deletion',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: OtaColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This permanently deletes the login account and every student '
          'profile linked to it.',
        ),
        const SizedBox(height: 18),
        _DeletionSummary(profileCount: account.linkedStudentProfileIds.length),
        const SizedBox(height: 18),
        const _MessageCard(
          icon: Icons.warning_amber_rounded,
          title: 'This cannot be undone',
          message:
              'All linked student profiles, progress, and preferences will be '
              'deleted and must be recreated manually if the student returns.',
        ),
        const SizedBox(height: 18),
        if (methods.length > 1) ...[
          if (methods.contains(AccountReauthenticationMethod.password)) ...[
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
          ],
          if (methods.contains(AccountReauthenticationMethod.google)) ...[
            _MethodTile(
              label: 'Google account',
              icon: Icons.account_circle_outlined,
              selected: _method == AccountReauthenticationMethod.google,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _method = AccountReauthenticationMethod.google;
                      _message = null;
                    }),
            ),
            const SizedBox(height: 10),
          ],
          if (methods.contains(AccountReauthenticationMethod.apple))
            _MethodTile(
              label: 'Apple account',
              icon: Icons.apple,
              selected: _method == AccountReauthenticationMethod.apple,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _method = AccountReauthenticationMethod.apple;
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
                'The linked Google account will be verified before deletion.',
          ),
        if (_method == AccountReauthenticationMethod.apple)
          const _MessageCard(
            icon: Icons.apple,
            title: 'Apple verification',
            message:
                'The linked Apple account will be verified before deletion.',
          ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _InlineError(message: _message!),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy || _method == null ? null : _deleteAccount,
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final method = _method;
    if (method == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _service.deleteAccount(
        method,
        password: method == AccountReauthenticationMethod.password
            ? _passwordController.text
            : null,
      );
      await _completeDeletion();
    } on AccountDeletionException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Account deletion failed safely. Please try again.',
        );
      }
    } finally {
      _passwordController.clear();
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
