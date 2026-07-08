import 'package:flutter/material.dart';

import '../models/student_profile.dart';
import '../models/user_account.dart';
import '../routes.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';
import '../widgets/profile/profile_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                        const _SettingsActionsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const OtaBottomNavBar(
        selectedDestination: OtaBottomNavDestination.profile,
      ),
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
                '${_beltLabel(student.belt)} • OTA Cheshire',
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
          value: '${student.age}',
        ),
        ProfileInfoRow(
          icon: Icons.workspace_premium_rounded,
          label: 'Belt Rank',
          value: _beltLabel(student.belt),
        ),
        const ProfileInfoRow(
          icon: Icons.location_on_rounded,
          label: 'Location',
          value: 'OTA Cheshire',
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
        const ProfileInfoRow(
          icon: Icons.switch_account_rounded,
          label: 'Profile Switching',
          value: 'Coming later',
        ),
        ProfileInfoRow(
          icon: Icons.verified_user_rounded,
          label: 'Account Status',
          value: account.approvalStatusLabel,
          showDivider: false,
        ),
      ],
    );
  }
}

class _SettingsActionsSection extends StatelessWidget {
  const _SettingsActionsSection();

  @override
  Widget build(BuildContext context) {
    return ProfileSection(
      title: 'Settings & Actions',
      children: [
        const ProfileActionRow(icon: Icons.edit_rounded, label: 'Edit Profile'),
        const ProfileActionRow(
          icon: Icons.switch_account_rounded,
          label: 'Switch Profile',
          value: 'Coming later',
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
        const ProfileActionRow(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
        ),
        ProfileActionRow(
          icon: Icons.home_rounded,
          label: 'Exit to Welcome',
          showDivider: false,
          onTap: () {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(OtaRoutes.welcome, (_) => false);
          },
        ),
      ],
    );
  }
}

String _beltLabel(String belt) => '$belt Belt';
