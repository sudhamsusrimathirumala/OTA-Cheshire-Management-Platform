import 'package:flutter/material.dart';

import '../../services/app_data_service_provider.dart';
import '../../services/debug_view_controller.dart';
import '../../services/firebase/firebase_session_controller.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/profile/profile_edit_sheets.dart';
import '../../widgets/profile/profile_section.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final account = appDataService.currentUserAccount;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F4),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: OtaColors.white,
                              foregroundColor: OtaColors.maroon,
                              side: const BorderSide(color: Color(0xFFE9D2D7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                          ),
                          const Spacer(),
                          Text(
                            'Admin Profile',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: OtaColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: OtaColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE9D2D7)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: OtaColors.maroon,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: OtaColors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: OtaColors.ink,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    account.roleLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: OtaColors.mutedText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      ProfileSection(
                        title: 'Account',
                        children: [
                          ProfileInfoRow(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            value: account.email,
                          ),
                          ProfileInfoRow(
                            icon: Icons.location_on_rounded,
                            label: 'Location',
                            value: account.locationId,
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ProfileSection(
                        title: 'Actions',
                        children: [
                          ProfileActionRow(
                            icon: Icons.edit_rounded,
                            label: 'Edit Account',
                            onTap: debugViewController.isActive
                                ? null
                                : () async {
                                    final changed = await showAccountEditSheet(
                                      context,
                                      account: account,
                                      service: firebaseSessionController
                                          .profileService,
                                    );
                                    if (changed && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Admin account updated.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          ProfileActionRow(
                            icon: Icons.logout_rounded,
                            label: debugViewController.isActive
                                ? 'Exit Sample View'
                                : 'Sign Out',
                            isDestructive: true,
                            showDivider: false,
                            onTap: () async {
                              if (debugViewController.isActive) {
                                debugViewController.clear();
                              } else {
                                await firebaseSessionController.signOut();
                              }
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
