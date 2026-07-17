import 'package:flutter/material.dart';

import '../../data/sample_curriculum.dart';
import '../../models/student_profile.dart';
import '../../models/user_account.dart';
import '../../models/class_session.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/profile_service.dart';
import '../../theme/ota_colors.dart';

typedef AccountContactUpdater =
    Future<void> Function(AccountContactInput input);
typedef ChildProfileCreator =
    Future<String> Function(StudentProfileInput input);

class AccountEditScreen extends StatelessWidget {
  const AccountEditScreen({
    required this.account,
    this.service,
    this.updateAccountContact,
    super.key,
  }) : assert(service != null || updateAccountContact != null);

  final UserAccount account;
  final FirestoreProfileService? service;
  final AccountContactUpdater? updateAccountContact;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OtaColors.blush,
    appBar: AppBar(title: const Text('Edit account information')),
    body: _AccountEditSheet(
      account: account,
      service: service,
      updateAccountContact: updateAccountContact,
    ),
  );
}

class StudentProfileEditScreen extends StatelessWidget {
  const StudentProfileEditScreen({
    required this.student,
    this.service,
    required this.guardianEmailRequired,
    this.schedule,
    this.updatePreferredClass,
    super.key,
  }) : assert(service != null || updatePreferredClass != null);

  final StudentProfile student;
  final FirestoreProfileService? service;
  final bool guardianEmailRequired;
  final Map<int, List<ClassSession>>? schedule;
  final Future<void> Function(StudentProfile, ClassSession?)?
  updatePreferredClass;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OtaColors.blush,
    appBar: AppBar(title: const Text('Edit student profile')),
    body: _StudentEditSheet(
      student: student,
      service: service,
      guardianEmailRequired: guardianEmailRequired,
      schedule: schedule ?? appDataService.schedule,
      updatePreferredClass: updatePreferredClass,
    ),
  );
}

class AddChildScreen extends StatelessWidget {
  const AddChildScreen({
    required this.account,
    this.service,
    this.createChild,
    super.key,
  }) : assert(service != null || createChild != null);

  final UserAccount account;
  final FirestoreProfileService? service;
  final ChildProfileCreator? createChild;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OtaColors.blush,
    appBar: AppBar(title: const Text('Add child')),
    body: _AddChildSheet(
      account: account,
      service: service,
      createChild: createChild,
    ),
  );
}

class AddParentStudentProfileScreen extends StatelessWidget {
  const AddParentStudentProfileScreen({
    required this.account,
    this.service,
    this.createProfile,
    super.key,
  }) : assert(service != null || createProfile != null);

  final UserAccount account;
  final FirestoreProfileService? service;
  final Future<String> Function(ParentSelfProfileInput input)? createProfile;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OtaColors.blush,
    appBar: AppBar(title: const Text('Add my student profile')),
    body: _ParentSelfProfileForm(
      account: account,
      service: service,
      createProfile: createProfile,
    ),
  );
}

Future<bool> showAccountEditSheet(
  BuildContext context, {
  required UserAccount account,
  required FirestoreProfileService service,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountEditSheet(account: account, service: service),
    ) ??
    false;

Future<bool> showStudentEditSheet(
  BuildContext context, {
  required StudentProfile student,
  required FirestoreProfileService service,
  required bool guardianEmailRequired,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StudentEditSheet(
        student: student,
        service: service,
        guardianEmailRequired: guardianEmailRequired,
        schedule: appDataService.schedule,
      ),
    ) ??
    false;

Future<bool> showAddChildSheet(
  BuildContext context, {
  required UserAccount account,
  required FirestoreProfileService service,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddChildSheet(account: account, service: service),
    ) ??
    false;

class _AccountEditSheet extends StatefulWidget {
  const _AccountEditSheet({
    required this.account,
    this.service,
    this.updateAccountContact,
  }) : assert(service != null || updateAccountContact != null);

  final UserAccount account;
  final FirestoreProfileService? service;
  final AccountContactUpdater? updateAccountContact;

  @override
  State<_AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<_AccountEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.account.firstName);
    _lastName = TextEditingController(text: widget.account.lastName);
    _phone = TextEditingController(text: widget.account.phoneNumber);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    final editRoute = ModalRoute.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final input = AccountContactInput(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phoneNumber: _phone.text,
      );
      await (widget.updateAccountContact?.call(input) ??
          widget.service!.updateAccountContact(input));
      if (!mounted || editRoute?.isCurrent != true || !navigator.canPop()) {
        return;
      }
      navigator.pop(true);
      return;
    } on ProfileServiceException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to update the account.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Edit account',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _requiredField(_firstName, 'First name'),
          _requiredField(_lastName, 'Last name'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StudentEditSheet extends StatefulWidget {
  const _StudentEditSheet({
    required this.student,
    this.service,
    required this.guardianEmailRequired,
    required this.schedule,
    this.updatePreferredClass,
  });

  final StudentProfile student;
  final FirestoreProfileService? service;
  final bool guardianEmailRequired;
  final Map<int, List<ClassSession>> schedule;
  final Future<void> Function(StudentProfile, ClassSession?)?
  updatePreferredClass;

  @override
  State<_StudentEditSheet> createState() => _StudentEditSheetState();
}

class _StudentEditSheetState extends State<_StudentEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _guardianEmail;
  late final TextEditingController _current;
  late final TextEditingController _required;
  late DateTime _dateOfBirth;
  late String _belt;
  bool _saving = false;
  String? _error;
  late List<String> _preferredGroupIds;
  String? _selectedPreferredGroupId;
  bool _savingPreference = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstName = TextEditingController(text: student.firstName);
    _lastName = TextEditingController(text: student.lastName);
    _guardianEmail = TextEditingController(text: student.guardianEmail);
    _current = TextEditingController(text: '${student.stickerCount}');
    _required = TextEditingController(text: '${student.stickersRequired}');
    _dateOfBirth = student.dateOfBirth ?? DateTime.now();
    _belt = curriculumBeltOrder.contains(student.belt)
        ? student.belt
        : curriculumBeltOrder.first;
    _preferredGroupIds = [...student.preferredClassGroupIds];
    _selectedPreferredGroupId = _preferredGroupIds.firstOrNull;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _guardianEmail.dispose();
    _current.dispose();
    _required.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _dateOfBirth = date);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service!.updateManagedProfile(
        StudentProfileEditInput(
          profileId: widget.student.id,
          firstName: _firstName.text,
          lastName: _lastName.text,
          dateOfBirth: _dateOfBirth,
          beltRank: _belt,
          guardianEmail: _guardianEmail.text,
          stickerCurrent: int.parse(_current.text),
          stickerRequired: int.parse(_required.text),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ProfileServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to update this student.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePreferredClass(ClassSession? session) async {
    final previous = [..._preferredGroupIds];
    setState(() {
      _savingPreference = true;
      _error = null;
      _preferredGroupIds = session == null
          ? <String>[]
          : <String>[session.bulkGroupId];
      _selectedPreferredGroupId = session?.bulkGroupId;
    });
    try {
      final callback = widget.updatePreferredClass;
      if (callback != null) {
        await callback(widget.student, session);
      } else {
        await widget.service!.updatePreferredClass(
          profile: widget.student,
          session: session,
        );
      }
    } on ProfileServiceException catch (error) {
      if (mounted) {
        setState(() {
          _preferredGroupIds = previous;
          _selectedPreferredGroupId = previous.firstOrNull;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preferredGroupIds = previous;
          _selectedPreferredGroupId = previous.firstOrNull;
          _error = 'Unable to update the preferred class.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Edit student profile',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _requiredField(_firstName, 'First name'),
          _requiredField(_lastName, 'Last name'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(_formatDate(_dateOfBirth)),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<String>(
            initialValue: _belt,
            decoration: const InputDecoration(
              labelText: 'Belt rank',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final belt in curriculumBeltOrder)
                DropdownMenuItem(value: belt, child: Text(belt)),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _belt = value);
                  },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _guardianEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: widget.guardianEmailRequired
                  ? 'Guardian email'
                  : 'Guardian email (optional)',
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                _emailValidator(value, required: widget.guardianEmailRequired),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stickerField(_current, 'Current stickers')),
              const SizedBox(width: 12),
              Expanded(
                child: _stickerField(
                  _required,
                  'Stickers required for next rank',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Preferred Class',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          for (final option in preferredClassOptions(
            widget.schedule,
            widget.student.locationId,
          ))
            ListTile(
              title: Text(option.session.className),
              subtitle: Text(option.scheduleSummary),
              leading: Icon(
                _selectedPreferredGroupId == option.session.bulkGroupId
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              trailing: _selectedPreferredGroupId == option.session.bulkGroupId
                  ? const Text('Selected')
                  : TextButton(
                      onPressed: _savingPreference
                          ? null
                          : () => _savePreferredClass(option.session),
                      child: Text(
                        _selectedPreferredGroupId == null
                            ? 'Set preferred class'
                            : 'Replace preferred class',
                      ),
                    ),
            ),
          if (_selectedPreferredGroupId != null)
            OutlinedButton.icon(
              onPressed: _savingPreference
                  ? null
                  : () => _savePreferredClass(null),
              icon: const Icon(Icons.heart_broken_rounded),
              label: const Text('Remove preferred class'),
            ),
        ],
      ),
    ),
  );
}

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet({required this.account, this.service, this.createChild})
    : assert(service != null || createChild != null);

  final UserAccount account;
  final FirestoreProfileService? service;
  final ChildProfileCreator? createChild;

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  late final TextEditingController _guardianEmail;
  DateTime? _dateOfBirth;
  String _belt = curriculumBeltOrder.first;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _guardianEmail = TextEditingController(text: widget.account.email);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2015),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _dateOfBirth = date);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      setState(() => _error = 'Select the child\'s date of birth.');
      return;
    }
    final navigator = Navigator.of(context);
    final addChildRoute = ModalRoute.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final input = StudentProfileInput(
        firstName: _firstName.text,
        lastName: _lastName.text,
        dateOfBirth: _dateOfBirth!,
        beltRank: _belt,
        guardianEmail: _guardianEmail.text,
      );
      await (widget.createChild?.call(input) ??
          widget.service!.addChild(input));
      if (!mounted || addChildRoute?.isCurrent != true || !navigator.canPop()) {
        return;
      }
      navigator.pop(true);
      return;
    } on ProfileServiceException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to add this child.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Add child',
    saving: _saving,
    error: _error,
    onSave: _save,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _requiredField(_firstName, 'First name'),
          _requiredField(_lastName, 'Last name'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(
              _dateOfBirth == null ? 'Required' : _formatDate(_dateOfBirth!),
            ),
            trailing: const Icon(Icons.calendar_month_rounded),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<String>(
            initialValue: _belt,
            decoration: const InputDecoration(
              labelText: 'Belt rank',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final belt in curriculumBeltOrder)
                DropdownMenuItem(value: belt, child: Text(belt)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _belt = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _guardianEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Guardian/contact email',
              helperText: 'Defaults to the parent account email.',
              border: OutlineInputBorder(),
            ),
            validator: (value) => _emailValidator(value, required: true),
          ),
        ],
      ),
    ),
  );
}

class _ParentSelfProfileForm extends StatefulWidget {
  const _ParentSelfProfileForm({
    required this.account,
    this.service,
    this.createProfile,
  });

  final UserAccount account;
  final FirestoreProfileService? service;
  final Future<String> Function(ParentSelfProfileInput input)? createProfile;

  @override
  State<_ParentSelfProfileForm> createState() => _ParentSelfProfileFormState();
}

class _ParentSelfProfileFormState extends State<_ParentSelfProfileForm> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _dateOfBirth;
  String? _belt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = widget.account.studentProfileDefaults?.dateOfBirth;
    final savedBelt = widget.account.studentProfileDefaults?.beltRank;
    _belt = curriculumBeltOrder.contains(savedBelt) ? savedBelt : null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _dateOfBirth = date);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null || _belt == null) {
      setState(
        () => _error = _dateOfBirth == null
            ? 'Select your date of birth.'
            : 'Select your belt rank.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final defaults = widget.account.studentProfileDefaults;
      await (widget.createProfile ?? widget.service!.addParentSelfProfile)(
        ParentSelfProfileInput(
          dateOfBirth: _dateOfBirth!,
          beltRank: _belt!,
          guardianEmail: defaults?.guardianEmail,
          stickerCurrent: defaults?.stickerCurrent ?? 0,
          stickerRequired: defaults?.stickerRequired ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ProfileServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to add your student profile.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: 'Student profile information',
    saving: _saving,
    error: _error,
    onSave: _save,
    actionLabel: 'Create My Student Profile',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          Text('Name: ${widget.account.displayName}'),
          Text('Account email: ${widget.account.email}'),
          Text('Phone: ${widget.account.phoneNumber ?? 'Not provided'}'),
          Text('Academy location: ${widget.account.locationId}'),
          if (_dateOfBirth != null)
            Text('Date of birth: ${_formatDate(_dateOfBirth!)}'),
          if (_belt != null) Text('Belt rank: $_belt'),
          if (widget.account.studentProfileDefaults?.guardianEmail != null)
            Text(
              'Contact email: ${widget.account.studentProfileDefaults!.guardianEmail}',
            ),
          Text(
            'Sticker progress: '
            '${widget.account.studentProfileDefaults?.stickerCurrent ?? 0} / '
            '${widget.account.studentProfileDefaults?.stickerRequired ?? 0}',
          ),
          if (_belt != null) Text('Next rank: ${nextRankForBelt(_belt!)}'),
          const SizedBox(height: 16),
          if (_dateOfBirth == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              subtitle: const Text('Required'),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDate,
            ),
          if (_belt == null)
            DropdownButtonFormField<String>(
              initialValue: _belt,
              decoration: const InputDecoration(
                labelText: 'Belt rank',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final belt in curriculumBeltOrder)
                  DropdownMenuItem(value: belt, child: Text(belt)),
              ],
              validator: (value) =>
                  value == null ? 'Belt rank is required.' : null,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _belt = value),
            ),
        ],
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    required this.saving,
    required this.error,
    required this.onSave,
    this.actionLabel = 'Save changes',
  });

  final String title;
  final Widget child;
  final bool saving;
  final String? error;
  final VoidCallback onSave;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          child,
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: OtaColors.actionRed)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

Widget _requiredField(TextEditingController controller, String label) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required.'
            : null,
      ),
    );

Widget _stickerField(TextEditingController controller, String label) =>
    TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        return parsed == null || parsed < 0
            ? 'Enter a whole number of zero or more.'
            : null;
      },
    );

String? _emailValidator(String? value, {required bool required}) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return required ? 'Email is required.' : null;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Enter a valid email.';
}

class PreferredClassOption {
  const PreferredClassOption({
    required this.session,
    required this.scheduleSummary,
  });

  final ClassSession session;
  final String scheduleSummary;
}

List<PreferredClassOption> preferredClassOptions(
  Map<int, List<ClassSession>> schedule,
  String locationId,
) {
  final occurrences = <String, List<(int, ClassSession)>>{};
  for (final entry in schedule.entries) {
    for (final session in entry.value) {
      if (!session.isPublished ||
          session.locationId != locationId ||
          session.bulkGroupId.trim().isEmpty) {
        continue;
      }
      occurrences
          .putIfAbsent(session.bulkGroupId, () => <(int, ClassSession)>[])
          .add((entry.key, session));
    }
  }
  final options = occurrences.values.map((items) {
    items.sort((a, b) {
      final day = a.$1.compareTo(b.$1);
      return day != 0 ? day : a.$2.startMinutes.compareTo(b.$2.startMinutes);
    });
    return PreferredClassOption(
      session: items.first.$2,
      scheduleSummary: items
          .map((item) => '${_weekdayLabel(item.$1)} ${item.$2.timeRangeLabel}')
          .join(' • '),
    );
  }).toList();
  options.sort((a, b) => a.session.className.compareTo(b.session.className));
  return options;
}

String _weekdayLabel(int weekday) =>
    const {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    }[weekday] ??
    'Day $weekday';

String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
