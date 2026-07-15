import 'package:flutter/material.dart';

import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/location_time_service.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, _) {
        final allStudents = _records(
          appDataService.adminStudentProfiles,
          appDataService.adminUserAccounts,
        );
        final belts = {
          for (final student in allStudents) student.profile.belt,
        }.toList()..sort();
        final beltOptions = ['All belts', ...belts];
        final effectiveBelt = beltOptions.contains(_beltFilter)
            ? _beltFilter
            : 'All belts';
        final students = _filtered(allStudents, effectiveBelt);

        return AdminPageShell(
          selectedDestination: AdminNavDestination.students,
          title: 'Students',
          subtitle: 'Search and view student profiles for your academy.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudentToolbar(
                searchController: _searchController,
                beltFilter: effectiveBelt,
                beltOptions: beltOptions,
                activeOnly: _activeOnly,
                ageFilter: _ageFilter,
                shownCount: students.length,
                onSearchChanged: (_) => setState(() {}),
                onBeltChanged: (value) {
                  if (value != null) setState(() => _beltFilter = value);
                },
                onActiveOnlyChanged: (value) =>
                    setState(() => _activeOnly = value),
                onAgeFilterChanged: (value) =>
                    setState(() => _ageFilter = value),
              ),
              const SizedBox(height: 14),
              _StudentsPanel(
                students: students,
                hasAnyStudents: allStudents.isNotEmpty,
                isLoading: appDataService.isAdminStudentsLoading,
                errorMessage: appDataService.adminStudentsErrorMessage,
                onOpenStudent: _openStudentDetail,
              ),
            ],
          ),
        );
      },
    );
  }

  List<_AdminStudentRecord> _records(
    List<StudentProfile> profiles,
    List<UserAccount> accounts,
  ) {
    final records = [
      for (final profile in profiles)
        _AdminStudentRecord(
          profile: profile,
          account: accountHolderForProfile(profile, accounts),
        ),
    ]..sort((a, b) => a.profile.name.compareTo(b.profile.name));
    return records;
  }

  List<_AdminStudentRecord> _filtered(
    List<_AdminStudentRecord> students,
    String beltFilter,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return students.where((student) {
      final profile = student.profile;
      final age = const LocationTimeService().ageForStudent(profile);
      final matchesSearch =
          query.isEmpty ||
          profile.name.toLowerCase().contains(query) ||
          (student.account?.displayName.toLowerCase().contains(query) ??
              false) ||
          (student.account?.email.toLowerCase().contains(query) ?? false) ||
          (profile.guardianEmail?.toLowerCase().contains(query) ?? false);
      final matchesBelt =
          beltFilter == 'All belts' || profile.belt == beltFilter;
      final matchesActive = !_activeOnly || profile.isActive;
      final matchesAge = switch (_ageFilter) {
        _AgeFilter.all => true,
        _AgeFilter.minor => age < 18,
        _AgeFilter.adult => age >= 18,
      };
      return matchesSearch && matchesBelt && matchesActive && matchesAge;
    }).toList();
  }

  Future<void> _openStudentDetail(_AdminStudentRecord student) async {
    final all = _records(
      appDataService.adminStudentProfiles,
      appDataService.adminUserAccounts,
    );
    final related = all
        .where(
          (candidate) =>
              candidate.profile.id != student.profile.id &&
              candidate.account?.id != null &&
              candidate.account?.id == student.account?.id,
        )
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) =>
          _StudentDetailSheet(student: student, relatedStudents: related),
    );
  }
}

@visibleForTesting
UserAccount? accountHolderForProfile(
  StudentProfile profile,
  List<UserAccount> accounts,
) {
  final ownerIds = <String>{
    if (profile.linkedUserId != null) profile.linkedUserId!,
    ...profile.guardianUserIds,
  };
  return accounts.where((account) => ownerIds.contains(account.id)).firstOrNull;
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
  Widget build(BuildContext context) => _AdminPanel(
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
                  'Search students or account holders',
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
            ),
            for (final entry in const [
              (_AgeFilter.all, 'All ages'),
              (_AgeFilter.minor, 'Minor'),
              (_AgeFilter.adult, 'Adult'),
            ])
              ChoiceChip(
                label: Text(entry.$2),
                selected: ageFilter == entry.$1,
                onSelected: (_) => onAgeFilterChanged(entry.$1),
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

class _StudentsPanel extends StatelessWidget {
  const _StudentsPanel({
    required this.students,
    required this.hasAnyStudents,
    required this.isLoading,
    required this.errorMessage,
    required this.onOpenStudent,
  });

  final List<_AdminStudentRecord> students;
  final bool hasAnyStudents;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<_AdminStudentRecord> onOpenStudent;

  @override
  Widget build(BuildContext context) => _AdminPanel(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHeader(
          icon: Icons.groups_outlined,
          title: 'Student Directory',
          detail: '${students.length} shown',
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          )
        else if (errorMessage != null)
          _EmptyState(message: errorMessage!, showRetry: true)
        else if (!hasAnyStudents)
          const _EmptyState(message: 'No students found.')
        else if (students.isEmpty)
          const _EmptyState(message: 'No students match this filter.')
        else
          for (var index = 0; index < students.length; index++) ...[
            _StudentRow(
              student: students[index],
              onTap: () => onOpenStudent(students[index]),
            ),
            if (index != students.length - 1)
              const Divider(height: 1, color: Color(0xFFE1E4EA)),
          ],
      ],
    ),
  );
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final _AdminStudentRecord student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = student.profile;
    final age = const LocationTimeService().ageForStudent(profile);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (student.account != null)
                    Text(
                      student.account!.displayName,
                      style: const TextStyle(color: OtaColors.mutedText),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Meta(
                    icon: Icons.workspace_premium_outlined,
                    text: profile.belt,
                  ),
                  _Meta(icon: Icons.cake_outlined, text: '$age'),
                  _Meta(
                    icon: Icons.place_outlined,
                    text: _locationLabel(profile.locationId),
                  ),
                  Chip(label: Text(profile.isActive ? 'Active' : 'Inactive')),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
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
    final profile = student.profile;
    final account = student.account;
    final required = profile.stickersRequired;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Text('Student profile overview'),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Student Information',
            children: [
              _DetailRow(label: 'Name', value: profile.name),
              _DetailRow(
                label: 'Age',
                value: '${const LocationTimeService().ageForStudent(profile)}',
              ),
              _DetailRow(label: 'Belt', value: profile.belt),
              _DetailRow(
                label: 'Academy',
                value: _locationLabel(profile.locationId),
              ),
              _DetailRow(
                label: 'State',
                value: profile.isActive ? 'Active' : 'Inactive',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Account holder or parent',
            children: [
              if (account != null) ...[
                _DetailRow(label: 'Name', value: account.displayName),
                _DetailRow(label: 'Email', value: account.email),
                _DetailRow(
                  label: 'Phone',
                  value: account.phoneNumber ?? 'Not provided',
                ),
                _DetailRow(label: 'Role', value: account.roleLabel),
              ] else ...[
                _DetailRow(
                  label: 'Guardian email',
                  value: profile.guardianEmail ?? 'Not provided',
                ),
              ],
              if (relatedStudents.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Linked student profiles',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final related in relatedStudents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(related.profile.name),
                    subtitle: Text(related.profile.belt),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'Belt / Promotion',
            children: [
              _DetailRow(label: 'Current belt', value: profile.belt),
              _DetailRow(label: 'Next rank', value: profile.nextRank),
              _DetailRow(
                label: 'Sticker progress',
                value: required > 0
                    ? '${profile.stickerCount} / $required'
                    : 'Not configured',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStudentRecord {
  const _AdminStudentRecord({required this.profile, required this.account});
  final StudentProfile profile;
  final UserAccount? account;
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: OtaColors.white,
      border: Border.all(color: const Color(0xFFE9D2D7)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon, color: OtaColors.maroon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Text(detail, style: const TextStyle(color: OtaColors.mutedText)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.showRetry = false});
  final String message;
  final bool showRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        Text(message),
        if (showRetry)
          TextButton.icon(
            onPressed: appDataService.retryLiveData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
      ],
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16), const SizedBox(width: 3), Text(text)],
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBF7),
      border: Border.all(color: const Color(0xFFE9D2D7)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: const TextStyle(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

InputDecoration _fieldDecoration(String label, {IconData? prefixIcon}) =>
    InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      border: const OutlineInputBorder(),
      isDense: true,
    );

String _locationLabel(String locationId) {
  for (final location in adminLocationController.locations) {
    if (location.id == locationId) return location.name;
  }
  return locationId;
}
