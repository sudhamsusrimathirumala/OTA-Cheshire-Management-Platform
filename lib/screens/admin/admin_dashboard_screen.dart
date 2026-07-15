import 'package:flutter/material.dart';

import '../../models/membership_application.dart';
import '../../routes.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/admin_location_controller.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _promptScheduled = false;

  static const _scheduleRows = [
    _InfoRow('4:00 PM', 'Little Tiger'),
    _InfoRow('5:00 PM', 'Level 2'),
    _InfoRow('6:15 PM', 'Teen & Black Belt'),
  ];

  static const _announcementRows = [
    _InfoRow('Draft', 'Tournament registration reminder'),
    _InfoRow('Sent', 'Summer schedule update'),
  ];

  static const _eventRows = [
    _InfoRow('Jul 12', 'Parent Night Out', 'Registration open'),
    _InfoRow('Aug 03', 'Summer Belt Testing', 'Link pending'),
  ];

  static const _updateRows = [
    _InfoRow('Today', 'Summer schedule updated', 'Admin'),
    _InfoRow('Jun 30', 'Parent Night Out event added', 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final pending = pendingApplicationsForAdmin(
          appDataService.adminMembershipApplications,
          adminLocationController,
        );
        final counts = pendingApprovalCounts(pending);
        _schedulePendingPrompt(pending, counts);
        return AdminPageShell(
          selectedDestination: AdminNavDestination.dashboard,
          title: 'Dashboard',
          subtitle:
              'Manage schedule changes, announcements, events, and student information.',
          child: Column(
            children: [
              _PendingApprovalsCard(
                counts: counts,
                isLoading: appDataService.isMembershipApplicationsLoading,
                errorMessage: appDataService.membershipApplicationsErrorMessage,
                onReview: () => Navigator.of(
                  context,
                ).pushReplacementNamed(OtaRoutes.adminStudents),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useTwoColumns = constraints.maxWidth >= 820;
                  final sections = [
                    const _SummarySection(
                      title: "Today's Schedule",
                      icon: Icons.today_outlined,
                      rows: _scheduleRows,
                    ),
                    const _SummarySection(
                      title: 'Active Announcements',
                      icon: Icons.campaign_outlined,
                      rows: _announcementRows,
                    ),
                    const _SummarySection(
                      title: 'Upcoming Events',
                      icon: Icons.event_available_outlined,
                      rows: _eventRows,
                    ),
                    const _SummarySection(
                      title: 'Recent Admin Updates',
                      icon: Icons.history_outlined,
                      rows: _updateRows,
                    ),
                  ];

                  if (!useTwoColumns) {
                    return Column(
                      children: [
                        for (final section in sections) ...[
                          section,
                          if (section != sections.last)
                            const SizedBox(height: 14),
                        ],
                      ],
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sections.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 198,
                        ),
                    itemBuilder: (context, index) => sections[index],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _schedulePendingPrompt(
    List<MembershipApplication> pending,
    PendingApprovalCounts counts,
  ) {
    if (_promptScheduled ||
        pending.isEmpty ||
        appDataService.isMembershipApplicationsLoading ||
        appDataService.membershipApplicationsErrorMessage != null ||
        adminLocationController.isDebugAdmin ||
        (!adminLocationController.isLocationAdmin &&
            !adminLocationController.isSuperAdmin) ||
        adminLocationController.pendingApplicationsPromptShown) {
      return;
    }
    _promptScheduled = true;
    adminLocationController.markPendingApplicationsPromptShown();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Membership applications need review'),
          content: Text(pendingApprovalMessage(counts)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(
                  context,
                ).pushReplacementNamed(OtaRoutes.adminStudents);
              },
              child: const Text('Review applications'),
            ),
          ],
        ),
      );
      _promptScheduled = false;
    });
  }
}

class _PendingApprovalsCard extends StatelessWidget {
  const _PendingApprovalsCard({
    required this.counts,
    required this.isLoading,
    required this.errorMessage,
    required this.onReview,
  });

  final PendingApprovalCounts counts;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Pending Membership Approvals',
    icon: Icons.how_to_reg_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isLoading)
          const LinearProgressIndicator()
        else if (errorMessage != null)
          Text(
            errorMessage!,
            style: const TextStyle(color: OtaColors.actionRed),
          )
        else ...[
          Text(pendingApprovalMessage(counts)),
          const SizedBox(height: 4),
          Text(
            '${counts.applicationCount} pending application batch'
            '${counts.applicationCount == 1 ? '' : 'es'}.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: counts.applicationCount > 0 ? onReview : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review applications'),
        ),
      ],
    ),
  );
}

class PendingApprovalCounts {
  const PendingApprovalCounts({
    required this.familyCount,
    required this.profileCount,
    required this.applicationCount,
  });

  final int familyCount;
  final int profileCount;
  final int applicationCount;
}

@visibleForTesting
PendingApprovalCounts pendingApprovalCounts(
  List<MembershipApplication> applications,
) => PendingApprovalCounts(
  familyCount: applications.map((item) => item.applicantUserId).toSet().length,
  profileCount: applications.fold(
    0,
    (total, item) => total + item.studentProfileIds.length,
  ),
  applicationCount: applications.length,
);

@visibleForTesting
String pendingApprovalMessage(PendingApprovalCounts counts) =>
    '${counts.familyCount} ${counts.familyCount == 1 ? 'family' : 'families'} '
    'and ${counts.profileCount} student profile'
    '${counts.profileCount == 1 ? '' : 's'} are awaiting approval.';

@visibleForTesting
List<MembershipApplication> pendingApplicationsForAdmin(
  List<MembershipApplication> applications,
  AdminLocationController controller,
) => [
  for (final application in applications)
    if (application.status == MembershipApplicationStatus.pending &&
        (controller.isDebugAdmin ||
            (controller.isSuperAdmin
                ? controller.activeLocationIds.contains(application.locationId)
                : controller.assignedLocation?.id == application.locationId)))
      application,
];

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (final row in rows) ...[
            _CompactRow(row: row),
            if (row != rows.last)
              const Divider(height: 14, color: Color(0xFFE1E4EA)),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        border: Border.all(color: const Color(0xFFE9D2D7)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x168B1E2D),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: OtaColors.softRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: OtaColors.maroon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9D2D7)),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.row});

  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: OtaColors.maroon,
      fontWeight: FontWeight.w800,
    );
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: OtaColors.ink,
      fontWeight: FontWeight.w700,
    );
    final metaStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: OtaColors.mutedText,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        if (row.meta != null) ...[
          const SizedBox(width: 10),
          Text(
            row.meta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
        ],
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.title, [this.meta]);

  final String label;
  final String title;
  final String? meta;
}
