import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../data/sample_constants.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';
import '../routes.dart';
import '../services/app_data_service_provider.dart';
import '../services/debug_view_controller.dart';
import '../services/location_time_service.dart';
import '../services/firebase/firebase_session_controller.dart';
import '../services/firebase/profile_service.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';
import '../widgets/profile/profile_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({this.managementAvailableOverride, super.key});

  final bool? managementAvailableOverride;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final student = appDataService.selectedStudentProfile;
        final account = appDataService.currentUserAccount;

        return Scaffold(
          backgroundColor: OtaColors.blush,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProfileIdentityHeader(student: student),
                            const SizedBox(height: 24),
                            _StudentInformationSection(student: student),
                            const SizedBox(height: 22),
                            _BeltPromotionSection(student: student),
                            const SizedBox(height: 22),
                            _FamilyAccountSection(account: account),
                            const SizedBox(height: 22),
                            _AcademySection(student: student),
                            const SizedBox(height: 22),
                            _SettingsActionsSection(
                              student: student,
                              account: account,
                              managementAvailableOverride:
                                  managementAvailableOverride,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              Firebase.apps.isEmpty ||
                  firebaseSessionController.stage == SessionStage.member
              ? const OtaBottomNavBar(
                  selectedDestination: OtaBottomNavDestination.profile,
                )
              : null,
        );
      },
    );
  }
}

class _ProfileIdentityHeader extends StatelessWidget {
  const _ProfileIdentityHeader({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: OtaColors.navy,
            shape: BoxShape.circle,
            border: Border.all(color: OtaColors.white, width: 4),
          ),
          alignment: Alignment.center,
          child: Text(
            student.initials,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: OtaColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_beltLabel(student.belt)} • ${_locationLabel(student)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: OtaColors.softRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Student Profile',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OtaColors.maroon,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentInformationSection extends StatelessWidget {
  const _StudentInformationSection({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return ProfileSection(
      title: 'Student Information',
      children: [
        ProfileInfoRow(
          icon: Icons.badge_rounded,
          label: 'Full Name',
          value: student.name,
        ),
        ProfileInfoRow(
          icon: Icons.cake_rounded,
          label: 'Age',
          value: '${const LocationTimeService().ageForStudent(student)}',
        ),
        ProfileInfoRow(
          icon: Icons.workspace_premium_rounded,
          label: 'Belt Rank',
          value: _beltLabel(student.belt),
        ),
        ProfileInfoRow(
          icon: Icons.location_on_rounded,
          label: 'Location',
          value: _locationLabel(student),
        ),
        const ProfileInfoRow(
          icon: Icons.school_rounded,
          label: 'Account Type',
          value: 'Student',
          showDivider: false,
        ),
      ],
    );
  }
}

class _BeltPromotionSection extends StatelessWidget {
  const _BeltPromotionSection({required this.student});

  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    final hasStickerProgress = student.stickersRequired > 0;

    return ProfileSection(
      title: 'Belt & Promotion',
      children: [
        ProfileInfoRow(
          icon: Icons.workspace_premium_rounded,
          label: 'Current Belt',
          value: _beltLabel(student.belt),
        ),
        ProfileInfoRow(
          icon: Icons.flag_rounded,
          label: 'Next Rank',
          value: _beltLabel(student.nextRank),
          showDivider: !hasStickerProgress,
        ),
        if (hasStickerProgress)
          ProfileInfoRow(
            icon: Icons.stars_rounded,
            label: 'Sticker Progress',
            value: '${student.stickerCount} of ${student.stickersRequired}',
            showDivider: false,
          ),
      ],
    );
  }
}

class _FamilyAccountSection extends StatelessWidget {
  const _FamilyAccountSection({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    final linkedProfileLabel =
        '${account.linkedStudentProfileIds.length} student ${account.linkedStudentProfileIds.length == 1 ? 'profile' : 'profiles'}';

    return ProfileSection(
      title: 'Family & Account',
      children: [
        ProfileInfoRow(
          icon: Icons.family_restroom_rounded,
          label: 'Parent / Guardian',
          value: account.displayName,
        ),
        ProfileInfoRow(
          icon: Icons.account_tree_rounded,
          label: 'Linked Profiles',
          value: linkedProfileLabel,
        ),
        ProfileInfoRow(
          icon: Icons.switch_account_rounded,
          label: 'Profile Switching',
          value: account.linkedStudentProfileIds.length > 1
              ? 'Available'
              : 'One linked profile',
        ),
        ProfileInfoRow(
          icon: Icons.verified_user_rounded,
          label: 'Account state',
          value: account.isActive ? 'Active' : 'Inactive',
          showDivider: false,
        ),
      ],
    );
  }
}

class _AcademySection extends StatelessWidget {
  const _AcademySection({required this.student});
  final StudentProfile student;

  @override
  Widget build(BuildContext context) => ProfileSection(
    title: 'Academy Location',
    children: [
      ProfileInfoRow(
        icon: Icons.place_outlined,
        label: 'Academy location',
        value: _locationLabel(student),
      ),
      if (student.guardianEmail != null)
        ProfileInfoRow(
          icon: Icons.alternate_email_rounded,
          label: 'Guardian email',
          value: student.guardianEmail!,
        ),
    ],
  );
}

class _SettingsActionsSection extends StatelessWidget {
  const _SettingsActionsSection({
    required this.student,
    required this.account,
    required this.managementAvailableOverride,
  });
  final StudentProfile student;
  final UserAccount account;
  final bool? managementAvailableOverride;

  @override
  Widget build(BuildContext context) {
    final hasFirebase = Firebase.apps.isNotEmpty;
    final managementAvailable = managementAvailableOverride ?? hasFirebase;
    final profileCount = hasFirebase
        ? firebaseSessionController.profiles.length
        : appDataService.linkedStudentProfiles.length;
    return ProfileSection(
      title: 'Settings & Actions',
      children: [
        ProfileActionRow(
          icon: Icons.manage_accounts_rounded,
          label: 'Manage Account & Student Profiles',
          onTap: managementAvailable
              ? () => Navigator.of(context).pushNamed(OtaRoutes.manageProfiles)
              : null,
        ),
        ProfileActionRow(
          icon: Icons.switch_account_rounded,
          label: 'Switch Profile',
          value: profileCount > 1 ? '$profileCount profiles' : '1 profile',
          onTap: hasFirebase && profileCount > 1
              ? () => _showProfileSwitcher(context)
              : null,
        ),
        const ProfileActionRow(
          icon: Icons.notifications_rounded,
          label: 'Notification Preferences',
        ),
        const ProfileActionRow(
          icon: Icons.lock_rounded,
          label: 'Privacy & Account',
        ),
        const ProfileActionRow(
          icon: Icons.help_rounded,
          label: 'Help / Contact Academy',
        ),
        ProfileActionRow(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
          onTap: debugViewController.isActive
              ? () {
                  debugViewController.clear();
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(OtaRoutes.welcome, (_) => false);
                }
              : hasFirebase
              ? () async {
                  await firebaseSessionController.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }
              : null,
        ),
      ],
    );
  }

  Future<void> _showProfileSwitcher(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Switch student')),
            for (final profile in firebaseSessionController.profiles)
              ListTile(
                leading: Icon(
                  profile.id == student.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${profile.beltRank} • ${_locationLabel(profile)}',
                ),
                onTap: () => Navigator.pop(context, profile.id),
              ),
          ],
        ),
      ),
    );
    if (id == null) return;
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await firebaseSessionController.selectProfile(id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(OtaRoutes.dashboard, (_) => false);
    } on ProfileServiceException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showError(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _showError(context, 'Unable to switch profiles. Please try again.');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _beltLabel(String belt) => '$belt Belt';

String _locationLabel(StudentProfile student) {
  if (student.locationId.isEmpty) return 'Not assigned';
  if (Firebase.apps.isNotEmpty &&
      firebaseSessionController.selectedProfile?.id == student.id) {
    return firebaseSessionController.selectedLocationName ??
        'Academy location loading';
  }
  if (student.locationId == otaCheshireLocationId) {
    return otaCheshireLocationName;
  }
  return student.locationId;
}
