import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../models/class_session.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';
import '../routes.dart';
import '../services/app_data_service_provider.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/firebase/profile_service.dart';
import '../services/location_time_service.dart';
import '../theme/ota_colors.dart';
import '../widgets/profile/profile_edit_sheets.dart';

class ManageProfilesScreen extends StatelessWidget {
  const ManageProfilesScreen({
    this.selectProfile,
    this.updateAccountContact,
    this.createChild,
    super.key,
  });

  final Future<void> Function(String profileId)? selectProfile;
  final AccountContactUpdater? updateAccountContact;
  final ChildProfileCreator? createChild;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appDataService,
    builder: (context, _) {
      final account = appDataService.currentUserAccount;
      final profiles = appDataService.linkedStudentProfiles
          .where((profile) => profile.isActive)
          .toList(growable: false);
      final selectedId = appDataService.selectedStudentProfile.id;
      final hasSelfProfile = profiles.any(
        (profile) => profile.linkedUserId == account.id,
      );

      return Scaffold(
        backgroundColor: OtaColors.blush,
        appBar: AppBar(
          title: const Text('Manage Account & Student Profiles'),
          backgroundColor: OtaColors.white,
          foregroundColor: OtaColors.ink,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AccountInformationCard(
                        account: account,
                        onEdit: () => _editAccount(context, account),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Student Profiles',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: OtaColors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage the active student profiles connected to this account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OtaColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final profile in profiles) ...[
                        _StudentProfileCard(
                          profile: profile,
                          account: account,
                          selected: profile.id == selectedId,
                          preferredClass: _preferredClassName(profile),
                          onEdit: () => _editStudent(context, profile),
                          onSwitch: profile.id == selectedId
                              ? null
                              : () => _switchProfile(context, profile.id),
                          onRemove:
                              account.role == UserAccountRole.parent &&
                                  profiles.length > 1
                              ? () => _removeLinkedProfile(
                                  context,
                                  profile,
                                  isSelfProfile:
                                      profile.linkedUserId == account.id,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (account.role == UserAccountRole.parent) ...[
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () => _addChild(context, account),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Add child'),
                        ),
                        if (!hasSelfProfile) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => _addSelfProfile(context, account),
                            icon: const Icon(Icons.sports_martial_arts_rounded),
                            label: const Text('Add my student profile'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  String? _preferredClassName(StudentProfile profile) {
    final group = profile.preferredClassGroupIds.firstOrNull;
    if (group == null) return null;
    for (final sessions in appDataService.schedule.values) {
      for (final session in sessions) {
        if (matchesResolvedPreferredClassGroup(
          profile.preferredClassGroupIds,
          session.bulkGroupId,
        )) {
          return session.className;
        }
      }
    }
    return 'Preferred class selected';
  }

  Future<void> _editAccount(BuildContext context, UserAccount account) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountEditScreen(
          account: account,
          service: updateAccountContact == null
              ? firebaseSessionController.profileService
              : null,
          updateAccountContact: updateAccountContact,
        ),
      ),
    );
    if (changed == true && context.mounted) {
      _success(context, 'Account updated.');
    }
  }

  Future<void> _editStudent(
    BuildContext context,
    StudentProfile profile,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StudentProfileEditScreen(
          student: profile,
          service: firebaseSessionController.profileService,
          guardianEmailRequired: profile.linkedUserId == null,
        ),
      ),
    );
    if (changed == true && context.mounted) {
      _success(context, 'Student profile updated.');
    }
  }

  Future<void> _addChild(BuildContext context, UserAccount account) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddChildScreen(
          account: account,
          service: createChild == null
              ? firebaseSessionController.profileService
              : null,
          createChild: createChild,
        ),
      ),
    );
    if (added == true && context.mounted) {
      _success(context, 'Child added to your account.');
    }
  }

  Future<void> _addSelfProfile(
    BuildContext context,
    UserAccount account,
  ) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddParentStudentProfileScreen(
          account: account,
          service: firebaseSessionController.profileService,
        ),
      ),
    );
    if (added == true && context.mounted) {
      _success(context, 'Your student profile was added.');
    }
  }

  Future<void> _switchProfile(BuildContext context, String profileId) async {
    _showLoading(context);
    try {
      await (selectProfile ?? firebaseSessionController.selectProfile)(
        profileId,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(OtaRoutes.dashboard, (_) => false);
    } on ProfileServiceException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _error(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _error(context, 'Unable to switch profiles. Please try again.');
    }
  }

  Future<void> _removeLinkedProfile(
    BuildContext context,
    StudentProfile profile, {
    required bool isSelfProfile,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSelfProfile
              ? 'Remove your student profile?'
              : 'Remove ${profile.name} from account?',
        ),
        content: Text(
          isSelfProfile
              ? 'Your parent account and linked child profiles will remain active. Your student profile will become inactive, and academy history will be retained.'
              : 'This child will stop appearing in the parent account and the profile will become inactive. Academy history is retained and no data is permanently erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove from account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    _showLoading(context);
    try {
      await firebaseSessionController.profileService.removeLinkedProfile(
        profile.id,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _success(
        context,
        isSelfProfile
            ? 'Your student profile was removed.'
            : 'Student removed from this account.',
      );
    } on ProfileServiceException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _error(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _error(context, 'Unable to remove this student profile.');
    }
  }

  void _showLoading(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  void _success(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _error(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _AccountInformationCard extends StatelessWidget {
  const _AccountInformationCard({required this.account, required this.onEdit});

  final UserAccount account;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _ManagementCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Account Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _InfoLine('Account holder', account.displayName),
        _InfoLine('Email', account.email),
        _InfoLine('Role', account.roleLabel),
        _InfoLine(
          'Academy location',
          Firebase.apps.isNotEmpty
              ? firebaseSessionController.selectedLocationName ??
                    account.locationId
              : account.locationId,
        ),
      ],
    ),
  );
}

class _StudentProfileCard extends StatelessWidget {
  const _StudentProfileCard({
    required this.profile,
    required this.account,
    required this.selected,
    required this.preferredClass,
    required this.onEdit,
    required this.onSwitch,
    required this.onRemove,
  });

  final StudentProfile profile;
  final UserAccount account;
  final bool selected;
  final String? preferredClass;
  final VoidCallback onEdit;
  final VoidCallback? onSwitch;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final relationship = profile.linkedUserId == account.id
        ? 'My student profile'
        : account.role == UserAccountRole.parent
        ? 'Child profile'
        : 'Student profile';
    final sticker = profile.stickersRequired == 0
        ? 'Not configured'
        : '${profile.stickerCount} of ${profile.stickersRequired}';
    return _ManagementCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      relationship,
                      style: const TextStyle(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Chip(
                  avatar: Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Selected'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine('Belt rank', '${profile.belt} Belt'),
          _InfoLine(
            'Age',
            '${const LocationTimeService().ageForStudent(profile)}',
          ),
          _InfoLine('Sticker progress', sticker),
          _InfoLine('Preferred class', preferredClass ?? 'None selected'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit'),
              ),
              if (onSwitch != null)
                FilledButton.tonalIcon(
                  onPressed: onSwitch,
                  icon: const Icon(Icons.switch_account_rounded),
                  label: const Text('Switch to profile'),
                ),
              if (onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.person_remove_alt_1_rounded),
                  label: const Text('Remove from account'),
                  style: TextButton.styleFrom(
                    foregroundColor: OtaColors.actionRed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: OtaColors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: OtaColors.navy.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: const TextStyle(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: OtaColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
