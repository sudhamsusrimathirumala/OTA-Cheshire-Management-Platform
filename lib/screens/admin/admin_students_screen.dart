import 'package:flutter/material.dart';

import '../../models/student_profile.dart';
import '../../services/app_data_service_provider.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

enum _AgeFilter { all, minor, adult }

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final _searchController = TextEditingController();
  var _beltFilter = 'All belts';
  var _activeOnly = true;
  var _ageFilter = _AgeFilter.all;

  List<_AdminStudentRecord> get _students {
    final serviceStudents = [
      for (final profile in appDataService.linkedStudentProfiles)
        _AdminStudentRecord.fromProfile(
          profile,
          guardianId: appDataService.currentUserAccount.id,
          guardianName: appDataService.currentUserAccount.displayName,
        ),
    ];

    final byId = {
      for (final student in [...serviceStudents, ..._mockAdminStudents])
        student.id: student,
    };

    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_AdminStudentRecord> get _filteredStudents {
    final query = _searchController.text.trim().toLowerCase();

    return _students.where((student) {
      final matchesSearch =
          query.isEmpty || student.name.toLowerCase().contains(query);
      final matchesBelt =
          _beltFilter == 'All belts' || student.belt == _beltFilter;
      final matchesActive = !_activeOnly || student.isActive;
      final matchesAge = switch (_ageFilter) {
        _AgeFilter.all => true,
        _AgeFilter.minor => student.age < 18,
        _AgeFilter.adult => student.age >= 18,
      };

      return matchesSearch && matchesBelt && matchesActive && matchesAge;
    }).toList();
  }

  List<String> get _beltOptions {
    final belts = {for (final student in _students) student.belt}.toList()
      ..sort();
    return ['All belts', ...belts];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents;

    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        return AdminPageShell(
          selectedDestination: AdminNavDestination.students,
          title: 'Students',
          subtitle: 'Search and view student profiles.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentToolbar(
                searchController: _searchController,
                beltFilter: _beltFilter,
                beltOptions: _beltOptions,
                activeOnly: _activeOnly,
                ageFilter: _ageFilter,
                shownCount: students.length,
                onSearchChanged: (_) => setState(() {}),
                onBeltChanged: (value) {
                  if (value != null) {
                    setState(() => _beltFilter = value);
                  }
                },
                onActiveOnlyChanged: (value) {
                  setState(() => _activeOnly = value);
                },
                onAgeFilterChanged: (value) {
                  setState(() => _ageFilter = value);
                },
              ),
              const SizedBox(height: 14),
              _StudentsPanel(
                students: students,
                hasAnyStudents: _students.isNotEmpty,
                onOpenStudent: _openStudentDetail,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStudentDetail(_AdminStudentRecord student) async {
    // TODO: Replace mock/service-backed detail data with Firestore-backed
    // student profile reads and admin profile updates.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        final relatedStudents = _students
            .where(
              (candidate) =>
                  candidate.guardianId != null &&
                  candidate.guardianId == student.guardianId &&
                  candidate.id != student.id,
            )
            .toList();

        return _StudentDetailSheet(
          student: student,
          relatedStudents: relatedStudents,
        );
      },
    );
  }
}

class _StudentToolbar extends StatelessWidget {
  const _StudentToolbar({
    required this.searchController,
    required this.beltFilter,
    required this.beltOptions,
    required this.activeOnly,
    required this.ageFilter,
    required this.shownCount,
    required this.onSearchChanged,
    required this.onBeltChanged,
    required this.onActiveOnlyChanged,
    required this.onAgeFilterChanged,
  });

  final TextEditingController searchController;
  final String beltFilter;
  final List<String> beltOptions;
  final bool activeOnly;
  final _AgeFilter ageFilter;
  final int shownCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onBeltChanged;
  final ValueChanged<bool> onActiveOnlyChanged;
  final ValueChanged<_AgeFilter> onAgeFilterChanged;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: _fieldDecoration(
                    'Search students',
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: beltFilter,
                  decoration: _fieldDecoration('Belt'),
                  items: [
                    for (final belt in beltOptions)
                      DropdownMenuItem(value: belt, child: Text(belt)),
                  ],
                  onChanged: onBeltChanged,
                ),
              ),
              FilterChip(
                label: const Text('Active students'),
                selected: activeOnly,
                onSelected: onActiveOnlyChanged,
                showCheckmark: false,
                selectedColor: OtaColors.softRed,
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                labelStyle: TextStyle(
                  color: activeOnly ? OtaColors.maroon : OtaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _AgeFilterButton(
                label: 'All ages',
                selected: ageFilter == _AgeFilter.all,
                onTap: () => onAgeFilterChanged(_AgeFilter.all),
              ),
              _AgeFilterButton(
                label: 'Minor',
                selected: ageFilter == _AgeFilter.minor,
                onTap: () => onAgeFilterChanged(_AgeFilter.minor),
              ),
              _AgeFilterButton(
                label: 'Adult',
                selected: ageFilter == _AgeFilter.adult,
                onTap: () => onAgeFilterChanged(_AgeFilter.adult),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Showing $shownCount students',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsPanel extends StatelessWidget {
  const _StudentsPanel({
    required this.students,
    required this.hasAnyStudents,
    required this.onOpenStudent,
  });

  final List<_AdminStudentRecord> students;
  final bool hasAnyStudents;
  final ValueChanged<_AdminStudentRecord> onOpenStudent;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.groups_outlined,
            title: 'Student Directory',
            detail: '${students.length} shown',
          ),
          if (!hasAnyStudents)
            const _EmptyState(message: 'No students found.')
          else if (students.isEmpty)
            const _EmptyState(message: 'No students match this filter.')
          else
            for (final student in students) ...[
              _StudentRow(
                student: student,
                onTap: () => onOpenStudent(student),
              ),
              if (student != students.last)
                const Divider(height: 1, color: Color(0xFFE1E4EA)),
            ],
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final _AdminStudentRecord student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 760;
            final details = Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InlineMeta(
                  icon: Icons.workspace_premium_outlined,
                  label: student.belt,
                ),
                _InlineMeta(icon: Icons.cake_outlined, label: '${student.age}'),
                _InlineMeta(
                  icon: Icons.place_outlined,
                  label: student.locationId,
                ),
                _StatusBadge(
                  label: student.isActive ? 'Active' : 'Inactive',
                  tone: student.isActive
                      ? _BadgeTone.success
                      : _BadgeTone.neutral,
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: _rowTitleStyle(context)),
                  const SizedBox(height: 8),
                  details,
                  const SizedBox(height: 8),
                  _StickerProgressText(student: student),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(student.name, style: _rowTitleStyle(context)),
                ),
                Expanded(flex: 5, child: details),
                SizedBox(
                  width: 180,
                  child: _StickerProgressText(student: student),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: OtaColors.mutedText,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentDetailSheet extends StatelessWidget {
  const _StudentDetailSheet({
    required this.student,
    required this.relatedStudents,
  });

  final _AdminStudentRecord student;
  final List<_AdminStudentRecord> relatedStudents;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: student.name,
            subtitle: 'Student profile overview',
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Student Information',
            children: [
              _DetailRow(label: 'Name', value: student.name),
              _DetailRow(label: 'Age', value: '${student.age}'),
              _DetailRow(label: 'Belt', value: student.belt),
              _DetailRow(label: 'Location', value: student.locationId),
              _DetailRow(
                label: 'Status',
                value: student.isActive ? 'Active' : 'Inactive',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Parent / Guardian',
            children: [
              _DetailRow(
                label: 'Guardian',
                value: student.guardianName ?? 'No parent/guardian linked.',
              ),
              if (relatedStudents.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Related students under this parent',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (final relatedStudent in relatedStudents)
                  _RelatedStudentRow(student: relatedStudent),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Belt / Promotion',
            children: [
              _DetailRow(label: 'Current belt', value: student.belt),
              _DetailRow(label: 'Next rank', value: student.nextRank),
              _DetailRow(
                label: 'Sticker progress',
                value: '${student.stickerCount} / ${student.stickersRequired}',
              ),
              const _DetailRow(
                label: 'Testing notes',
                value: 'No testing notes recorded yet.',
              ),
              const _DetailRow(
                label: 'Promotion history',
                value: 'Promotion history will appear here later.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStudentRecord {
  const _AdminStudentRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.belt,
    required this.locationId,
    required this.stickerCount,
    required this.stickersRequired,
    required this.nextRank,
    required this.isActive,
    this.guardianId,
    this.guardianName,
  });

  factory _AdminStudentRecord.fromProfile(
    StudentProfile profile, {
    String? guardianId,
    String? guardianName,
  }) {
    return _AdminStudentRecord(
      id: profile.id,
      name: profile.name,
      age: profile.age,
      belt: profile.belt,
      locationId: profile.locationId,
      stickerCount: profile.stickerCount,
      stickersRequired: profile.stickersRequired,
      nextRank: profile.nextRank,
      isActive: true,
      guardianId: guardianId,
      guardianName: guardianName,
    );
  }

  final String id;
  final String name;
  final int age;
  final String belt;
  final String locationId;
  final int stickerCount;
  final int stickersRequired;
  final String nextRank;
  final bool isActive;
  final String? guardianId;
  final String? guardianName;
}

class _AgeFilterButton extends StatelessWidget {
  const _AgeFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? OtaColors.white : OtaColors.ink,
        backgroundColor: selected ? OtaColors.navy : OtaColors.white,
        side: BorderSide(
          color: selected ? OtaColors.navy : const Color(0xFFD0D5DD),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [OtaColors.navy, OtaColors.maroon],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: OtaColors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            detail,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OtaColors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: OtaColors.mutedText),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: OtaColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _badgeColors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StickerProgressText extends StatelessWidget {
  const _StickerProgressText({required this.student});

  final _AdminStudentRecord student;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${student.stickerCount} / ${student.stickersRequired} stickers',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: OtaColors.mutedText,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedStudentRow extends StatelessWidget {
  const _RelatedStudentRow({required this.student});

  final _AdminStudentRecord student;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 16, color: OtaColors.maroon),
          const SizedBox(width: 6),
          Expanded(child: Text('${student.name} · ${student.belt}')),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: OtaColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OtaColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OtaColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

enum _BadgeTone { success, neutral }

_BadgeColors _badgeColors(_BadgeTone tone) {
  return switch (tone) {
    _BadgeTone.success => const _BadgeColors(
      background: Color(0xFFEAF7EF),
      border: Color(0xFFB9DEC6),
      foreground: Color(0xFF23633B),
    ),
    _BadgeTone.neutral => const _BadgeColors(
      background: Color(0xFFF2F4F7),
      border: Color(0xFFD0D5DD),
      foreground: OtaColors.ink,
    ),
  };
}

InputDecoration _fieldDecoration(String label, {IconData? prefixIcon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: Color(0xFFD0D5DD)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: OtaColors.maroon, width: 1.4),
    ),
  );
}

TextStyle? _rowTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: OtaColors.ink,
    fontWeight: FontWeight.w900,
  );
}

const _mockAdminStudents = [
  _AdminStudentRecord(
    id: 'student_maya',
    name: 'Maya Patel',
    age: 9,
    belt: 'Yellow-Green',
    locationId: 'ota-cheshire',
    stickerCount: 2,
    stickersRequired: 4,
    nextRank: 'Green',
    isActive: true,
    guardianId: 'guardian_patel',
    guardianName: 'Rina Patel',
  ),
  _AdminStudentRecord(
    id: 'student_aarav',
    name: 'Aarav Patel',
    age: 6,
    belt: 'White-Yellow',
    locationId: 'ota-cheshire',
    stickerCount: 1,
    stickersRequired: 3,
    nextRank: 'Yellow',
    isActive: true,
    guardianId: 'guardian_patel',
    guardianName: 'Rina Patel',
  ),
  _AdminStudentRecord(
    id: 'student_elena',
    name: 'Elena Rivera',
    age: 13,
    belt: 'Blue',
    locationId: 'ota-cheshire',
    stickerCount: 3,
    stickersRequired: 4,
    nextRank: 'Blue-Red',
    isActive: true,
    guardianId: 'guardian_rivera',
    guardianName: 'Luis Rivera',
  ),
  _AdminStudentRecord(
    id: 'student_daniel',
    name: 'Daniel Kim',
    age: 21,
    belt: 'Black',
    locationId: 'ota-cheshire',
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'Second Dan',
    isActive: true,
  ),
];
