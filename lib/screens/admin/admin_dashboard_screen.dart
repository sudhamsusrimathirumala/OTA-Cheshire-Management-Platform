import 'package:flutter/material.dart';

import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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
    return AdminPageShell(
      selectedDestination: AdminNavDestination.dashboard,
      title: 'Dashboard',
      subtitle:
          'Manage schedule changes, announcements, events, and student information.',
      child: LayoutBuilder(
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
                  if (section != sections.last) const SizedBox(height: 14),
                ],
              ],
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 198,
            ),
            itemBuilder: (context, index) => sections[index],
          );
        },
      ),
    );
  }
}

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
