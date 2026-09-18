import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/guest/guest_experience_controller.dart';
import '../../theme/ota_colors.dart';

class GuestDashboardScreen extends StatelessWidget {
  const GuestDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OtaColors.blush,
    appBar: AppBar(
      title: const Text('OTA Reviewer Demo'),
      backgroundColor: OtaColors.white,
      foregroundColor: OtaColors.ink,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose an experience',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: OtaColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All people and academy information are fictional. Changes stay on this device for the current session and never reach Firebase or send notifications.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: OtaColors.mutedText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _GuestViewCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin View',
                    description:
                        'Use the real administration layouts to review students, schedules, announcements, events, and resources.',
                    onTap: () => _open(context, GuestViewMode.admin),
                  ),
                  const SizedBox(height: 14),
                  _GuestViewCard(
                    icon: Icons.sports_martial_arts_rounded,
                    title: 'Student View',
                    description:
                        'Review Casey Rowan’s dashboard, schedule, curriculum, notifications, and profile.',
                    onTap: () => _open(context, GuestViewMode.student),
                  ),
                  const SizedBox(height: 14),
                  _GuestViewCard(
                    icon: Icons.family_restroom_rounded,
                    title: 'Parent View',
                    description:
                        'Switch between the fictional Rowan students and review the same information seen by the family.',
                    onTap: () => _open(context, GuestViewMode.parent),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _signOut(context);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _open(BuildContext context, GuestViewMode mode) {
    guestExperienceController.selectMode(mode);
    Navigator.of(context).pushNamedAndRemoveUntil(
      mode == GuestViewMode.admin
          ? OtaRoutes.adminDashboard
          : OtaRoutes.dashboard,
      (_) => false,
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    final session = guestSessionSignOut;
    if (session != null) await session();
    if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
  }
}

Future<void> Function()? guestSessionSignOut;

class GuestModeBanner extends StatelessWidget {
  const GuestModeBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF2CC),
    child: SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.visibility_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reviewer demo • ${_modeLabel(guestExperienceController.mode)} • local changes only',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            PopupMenuButton<GuestViewMode?>(
              tooltip: 'Switch reviewer view',
              onSelected: (mode) {
                if (mode == null) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    OtaRoutes.guestDashboard,
                    (_) => false,
                  );
                  return;
                }
                guestExperienceController.selectMode(mode);
                Navigator.of(context).pushNamedAndRemoveUntil(
                  mode == GuestViewMode.admin
                      ? OtaRoutes.adminDashboard
                      : OtaRoutes.dashboard,
                  (_) => false,
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: GuestViewMode.admin,
                  child: Text('Admin View'),
                ),
                PopupMenuItem(
                  value: GuestViewMode.student,
                  child: Text('Student View'),
                ),
                PopupMenuItem(
                  value: GuestViewMode.parent,
                  child: Text('Parent View'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(value: null, child: Text('View chooser')),
              ],
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

String _modeLabel(GuestViewMode mode) => switch (mode) {
  GuestViewMode.admin => 'Admin View',
  GuestViewMode.student => 'Student View',
  GuestViewMode.parent => 'Parent View',
};

class _GuestViewCard extends StatelessWidget {
  const _GuestViewCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: OtaColors.white,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: OtaColors.maroon, size: 34),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
