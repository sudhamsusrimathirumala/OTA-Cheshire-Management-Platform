import 'package:flutter/material.dart';

import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../../data/sample_curriculum.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/location_time_service.dart';
import '../../services/firebase/firebase_admin_write_service.dart';
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
          relationship: adminStudentRelationship(profile, accounts),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) => _StudentDetailSheet(student: student),
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

@visibleForTesting
UserAccount? parentAccountForProfile(
  StudentProfile profile,
  List<UserAccount> accounts,
) => accounts.where((account) {
  return account.role == UserAccountRole.parent &&
      account.id != profile.linkedUserId &&
      (account.linkedStudentProfileIds.contains(profile.id) ||
          profile.guardianUserIds.contains(account.id));
}).firstOrNull;

enum AdminStudentProfileType {
  child('Child profile'),
  parentSelf('Parent’s own student profile'),
  studentSelf('Self-managed student'),
  unknown('Unknown relationship');

  const AdminStudentProfileType(this.label);

  final String label;
}

class AdminStudentRelationship {
  const AdminStudentRelationship({required this.type, this.account});

  final AdminStudentProfileType type;
  final UserAccount? account;
}

@visibleForTesting
AdminStudentRelationship adminStudentRelationship(
  StudentProfile profile,
  List<UserAccount> accounts,
) {
  final linkedAccount = accounts
      .where((account) => account.id == profile.linkedUserId)
      .firstOrNull;
  if (linkedAccount?.role == UserAccountRole.parent) {
    return AdminStudentRelationship(
      type: AdminStudentProfileType.parentSelf,
      account: linkedAccount,
    );
  }
  if (linkedAccount?.role == UserAccountRole.student) {
    return AdminStudentRelationship(
      type: AdminStudentProfileType.studentSelf,
      account: linkedAccount,
    );
  }
  final parent = parentAccountForProfile(profile, accounts);
  if (parent != null) {
    return AdminStudentRelationship(
      type: AdminStudentProfileType.child,
      account: parent,
    );
  }
  if (linkedAccount != null) {
    return AdminStudentRelationship(
      type: AdminStudentProfileType.unknown,
      account: linkedAccount,
    );
  }
  if (profile.linkedUserId == null && profile.guardianEmail != null) {
    return const AdminStudentRelationship(type: AdminStudentProfileType.child);
  }
  return const AdminStudentRelationship(type: AdminStudentProfileType.unknown);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _Meta(
                  icon: Icons.workspace_premium_outlined,
                  text: profile.belt,
                ),
                _Meta(icon: Icons.cake_outlined, text: 'Age $age'),
              ],
            );
            final identity = Text(
              profile.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            );
            if (constraints.maxWidth < 520) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 6), details],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: identity),
                Expanded(flex: 4, child: details),
                const Icon(Icons.chevron_right_rounded),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentDetailSheet extends StatefulWidget {
  const _StudentDetailSheet({required this.student});

  final _AdminStudentRecord student;

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  var _editing = false;
  var _saving = false;
  String? _error;

  Future<void> _save(
    String belt,
    String currentText,
    String requiredText,
  ) async {
    final current = int.tryParse(currentText);
    final required = int.tryParse(requiredText);
    if (current == null || required == null) {
      setState(() => _error = 'Sticker values must be whole numbers.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirebaseAdminWriteService().updateStudentProgress(
        AdminStudentProgressWriteData(
          profileId: widget.student.profile.id,
          beltRank: belt,
          stickerCurrent: current,
          stickerRequired: required,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message?.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Progress could not be saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.student.profile;
    final relationship = widget.student.relationship;
    final account = relationship.account;
    final required = profile.stickersRequired;
    if (_editing) {
      return _StudentProgressEditor(
        profile: profile,
        saving: _saving,
        error: _error,
        onCancel: () => setState(() => _editing = false),
        onSave: _save,
      );
    }
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
          _DetailSection(
            title: 'Student details',
            children: [
              _DetailRow(label: 'Name', value: profile.name),
              _DetailRow(
                label: 'Age',
                value: '${const LocationTimeService().ageForStudent(profile)}',
              ),
              _DetailRow(label: 'Current belt', value: profile.belt),
              if (required > 0)
                _DetailRow(
                  label: 'Sticker progress',
                  value: '${profile.stickerCount} / $required',
                ),
              _DetailRow(label: 'Profile type', value: relationship.type.label),
              if (account != null)
                _DetailRow(label: 'Account role', value: account.roleLabel),
              if (relationship.type == AdminStudentProfileType.child &&
                  account != null) ...[
                _DetailRow(label: 'Parent name', value: account.displayName),
                _DetailRow(label: 'Parent email', value: account.email),
              ] else if ((relationship.type ==
                          AdminStudentProfileType.parentSelf ||
                      relationship.type ==
                          AdminStudentProfileType.studentSelf) &&
                  account != null) ...[
                _DetailRow(
                  label: 'Account holder name',
                  value: account.displayName,
                ),
                _DetailRow(label: 'Account holder email', value: account.email),
              ] else if (relationship.type == AdminStudentProfileType.child &&
                  account == null &&
                  profile.guardianEmail != null)
                _DetailRow(
                  label: 'Parent email',
                  value: profile.guardianEmail!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('Edit Progress'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminStudentRecord {
  const _AdminStudentRecord({
    required this.profile,
    required this.relationship,
  });
  final StudentProfile profile;
  final AdminStudentRelationship relationship;
  UserAccount? get account => relationship.account;
}

class _StudentProgressEditor extends StatefulWidget {
  const _StudentProgressEditor({
    required this.profile,
    required this.saving,
    required this.error,
    required this.onCancel,
    required this.onSave,
  });
  final StudentProfile profile;
  final bool saving;
  final String? error;
  final VoidCallback onCancel;
  final Future<void> Function(String, String, String) onSave;
  @override
  State<_StudentProgressEditor> createState() => _StudentProgressEditorState();
}

class _StudentProgressEditorState extends State<_StudentProgressEditor> {
  late String _belt = widget.profile.belt;
  late final _current = TextEditingController(
    text: '${widget.profile.stickerCount}',
  );
  late final _required = TextEditingController(
    text: '${widget.profile.stickersRequired}',
  );
  @override
  void dispose() {
    _current.dispose();
    _required.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      18,
      14,
      18,
      18 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit Progress',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _belt,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Current belt'),
          items: [
            for (final belt in curriculumBeltOrder)
              DropdownMenuItem(value: belt, child: Text(belt)),
          ],
          onChanged: widget.saving
              ? null
              : (value) => setState(() => _belt = value!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _current,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current stickers'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _required,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Required stickers'),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              widget.error!,
              style: const TextStyle(color: OtaColors.maroon),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: widget.saving ? null : widget.onCancel,
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: widget.saving
                  ? null
                  : () => widget.onSave(_belt, _current.text, _required.text),
              child: Text(widget.saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Wrap(
    spacing: 3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [Icon(icon, size: 16), Text(text)],
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
