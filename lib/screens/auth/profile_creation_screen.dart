import 'package:flutter/material.dart';

import '../../data/sample_curriculum.dart';
import '../../services/firebase/firebase_session_controller.dart';
import '../../services/firebase/profile_membership_service.dart';
import '../../theme/ota_colors.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({
    super.key,
    this.accountEmail,
    this.createProfiles,
    this.onProfilesCreated,
    this.onSignOut,
  });

  final String? accountEmail;
  final Future<void> Function(ProfileCreationRequest request)? createProfiles;
  final VoidCallback? onProfilesCreated;
  final VoidCallback? onSignOut;

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _guardianEmail = TextEditingController();
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  final _children = <_ChildFields>[];
  DateTime? _dateOfBirth;
  String _beltRank = curriculumBeltOrder.first;
  ProfileAccountRole _role = ProfileAccountRole.student;
  bool _parentIsStudent = false;
  bool _confirmed = false;
  bool _saving = false;
  int _step = 0;
  String? _error;

  String get _accountEmail =>
      widget.accountEmail ?? firebaseSessionController.authUser?.email ?? '';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _guardianEmail.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  Future<void> _pickApplicantBirthDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (value != null && mounted) setState(() => _dateOfBirth = value);
  }

  void _addChild() {
    if (_children.length >= 10) return;
    setState(() => _children.add(_ChildFields(guardianEmail: _accountEmail)));
  }

  void _removeChild(int index) {
    setState(() => _children.removeAt(index).dispose());
  }

  bool _validateStep() {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return false;
    if (_step == 0 && _dateOfBirth == null) {
      setState(() => _error = 'Select your date of birth.');
      return false;
    }
    if (_step == 0) {
      final birthDate = _dateOfBirth;
      if (birthDate == null) return false;
      final today = DateTime.now();
      var age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      if (age < 16) {
        setState(
          () => _error =
              'You must be at least 16. A parent must create your profile.',
        );
        return false;
      }
    }
    if (_step == 1 &&
        _role == ProfileAccountRole.parent &&
        !_parentIsStudent &&
        _children.isEmpty) {
      setState(() => _error = 'Add at least one student profile.');
      return false;
    }
    if (_step == 1 && _children.any((child) => child.dateOfBirth == null)) {
      setState(() => _error = 'Every student needs a date of birth.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  Future<void> _continue() async {
    if (!_validateStep()) return;
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    if (!_confirmed) {
      setState(() => _error = 'Confirm that the profile details are correct.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final applicantBirthDate = _dateOfBirth;
    if (applicantBirthDate == null) {
      setState(() {
        _saving = false;
        _error = 'Select your date of birth.';
      });
      return;
    }
    final additionalStudents = <StudentProfileInput>[];
    for (final child in _children) {
      final childBirthDate = child.dateOfBirth;
      if (childBirthDate == null) {
        setState(() {
          _saving = false;
          _error = 'Every student needs a date of birth.';
        });
        return;
      }
      additionalStudents.add(
        StudentProfileInput(
          firstName: child.firstName.text,
          lastName: child.lastName.text,
          dateOfBirth: childBirthDate,
          beltRank: child.beltRank,
          guardianEmail: child.guardianEmail.text,
        ),
      );
    }
    try {
      final request = ProfileCreationRequest(
        firstName: _firstName.text,
        lastName: _lastName.text,
        dateOfBirth: applicantBirthDate,
        applicantBeltRank: _beltRank,
        phoneNumber: _phone.text,
        role: _role,
        guardianEmail: _guardianEmail.text,
        parentIsStudent: _parentIsStudent,
        additionalStudents: additionalStudents,
      );
      await (widget.createProfiles?.call(request) ??
          firebaseSessionController.membership.createProfiles(request));
      final onProfilesCreated = widget.onProfilesCreated;
      if (onProfilesCreated != null) {
        onProfilesCreated();
      } else {
        firebaseSessionController.markProfilesCreated();
      }
    } on MembershipServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.blush,
      appBar: AppBar(
        title: const Text('Create OTA profiles'),
        actions: [
          TextButton(
            onPressed: widget.onSignOut ?? firebaseSessionController.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Stepper(
              currentStep: _step,
              onStepTapped: (value) {
                if (value < _step) setState(() => _step = value);
              },
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    FilledButton(
                      key: ValueKey('profile-continue-${details.stepIndex}'),
                      onPressed: _saving ? null : _continue,
                      child: Text(_step == 2 ? 'Create profiles' : 'Continue'),
                    ),
                    if (_step > 0) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        key: ValueKey('profile-back-${details.stepIndex}'),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ],
                  ],
                ),
              ),
              steps: [
                Step(
                  title: const Text('Applicant information'),
                  isActive: _step >= 0,
                  content: Form(
                    key: _formKeys[0],
                    child: Column(
                      children: [
                        _field(_firstName, 'First name'),
                        _field(_lastName, 'Last name'),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Date of birth'),
                          subtitle: Text(
                            _formatOptionalDate(
                              _dateOfBirth,
                              placeholder: 'Required',
                            ),
                          ),
                          trailing: const Icon(Icons.calendar_month_rounded),
                          onTap: _pickApplicantBirthDate,
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _beltRank,
                          decoration: const InputDecoration(
                            labelText: 'Belt rank',
                          ),
                          items: curriculumBeltOrder
                              .map(
                                (belt) => DropdownMenuItem(
                                  value: belt,
                                  child: Text(belt),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _beltRank = value);
                            }
                          },
                        ),
                        _field(
                          _phone,
                          'Phone number (optional)',
                          required: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Role and family'),
                  isActive: _step >= 1,
                  content: Form(
                    key: _formKeys[1],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<ProfileAccountRole>(
                          segments: const [
                            ButtonSegment(
                              value: ProfileAccountRole.student,
                              label: Text('Student'),
                              icon: Icon(Icons.person),
                            ),
                            ButtonSegment(
                              value: ProfileAccountRole.parent,
                              label: Text('Parent'),
                              icon: Icon(Icons.family_restroom),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (value) {
                            final role = value.firstOrNull;
                            if (role != null) setState(() => _role = role);
                          },
                        ),
                        if (_role == ProfileAccountRole.student)
                          _field(_guardianEmail, 'Guardian email', email: true),
                        if (_role == ProfileAccountRole.parent) ...[
                          SwitchListTile(
                            value: _parentIsStudent,
                            title: const Text('I am also an OTA student'),
                            onChanged: (value) =>
                                setState(() => _parentIsStudent = value),
                          ),
                          for (var i = 0; i < _children.length; i++)
                            _ChildEditor(
                              key: ValueKey(_children[i]),
                              fields: _children[i],
                              index: i,
                              onRemove: () => _removeChild(i),
                            ),
                          OutlinedButton.icon(
                            key: const ValueKey('add-student'),
                            onPressed: _children.length >= 10
                                ? null
                                : _addChild,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text('Add student (${_children.length}/10)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Review and create'),
                  isActive: _step >= 2,
                  content: Form(
                    key: _formKeys[2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _review(
                          'Applicant',
                          '${_firstName.text} ${_lastName.text}',
                        ),
                        _review('Account email', _accountEmail),
                        _review('Role', _role.name),
                        _review(
                          'Date of birth',
                          _formatOptionalDate(_dateOfBirth),
                        ),
                        if (_role == ProfileAccountRole.student ||
                            _parentIsStudent)
                          _review('Applicant belt', _beltRank),
                        if (_role == ProfileAccountRole.student)
                          _review('Guardian email', _guardianEmail.text),
                        for (var i = 0; i < _children.length; i++)
                          _review('Student ${i + 1}', _children[i].summary),
                        CheckboxListTile(
                          value: _confirmed,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'I confirm these permanent profile details are correct.',
                          ),
                          onChanged: (value) =>
                              setState(() => _confirmed = value ?? false),
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: OtaColors.actionRed),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    bool email = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: email ? TextInputType.emailAddress : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return '$label is required.';
          }
          if (email &&
              value != null &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
            return 'Enter a valid email address.';
          }
          return null;
        },
      ),
    );
  }

  Widget _review(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value.trim().isEmpty ? 'Not provided' : value.trim()),
  );
}

class _ChildFields {
  _ChildFields({required String guardianEmail}) {
    this.guardianEmail.text = guardianEmail;
  }
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final guardianEmail = TextEditingController();
  DateTime? dateOfBirth;
  String beltRank = curriculumBeltOrder.first;

  String get summary {
    final name = '${firstName.text} ${lastName.text}'.trim();
    final birthDate = dateOfBirth;
    final birthDateLabel = birthDate == null
        ? 'Date of birth not selected'
        : _formatDate(birthDate);
    return '${name.isEmpty ? 'Name not provided' : name}, $birthDateLabel, $beltRank, ${guardianEmail.text.trim().isEmpty ? 'Guardian email not provided' : guardianEmail.text.trim()}';
  }

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    guardianEmail.dispose();
  }
}

class _ChildEditor extends StatefulWidget {
  const _ChildEditor({
    required this.fields,
    required this.index,
    required this.onRemove,
    super.key,
  });
  final _ChildFields fields;
  final int index;
  final VoidCallback onRemove;

  @override
  State<_ChildEditor> createState() => _ChildEditorState();
}

class _ChildEditorState extends State<_ChildEditor> {
  @override
  Widget build(BuildContext context) {
    final fields = widget.fields;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Student ${widget.index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  tooltip: 'Remove student',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: fields.firstName,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: _required,
            ),
            TextFormField(
              controller: fields.lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
              validator: _required,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              subtitle: Text(
                _formatOptionalDate(
                  fields.dateOfBirth,
                  placeholder: 'Required',
                ),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: fields.dateOfBirth ?? DateTime(2015, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => fields.dateOfBirth = date);
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: fields.beltRank,
              decoration: const InputDecoration(labelText: 'Belt rank'),
              items: curriculumBeltOrder
                  .map(
                    (belt) => DropdownMenuItem(value: belt, child: Text(belt)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) fields.beltRank = value;
              },
            ),
            TextFormField(
              controller: fields.guardianEmail,
              decoration: const InputDecoration(labelText: 'Guardian email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) =>
                  value != null &&
                      RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value.trim())
                  ? null
                  : 'Enter a valid guardian email.',
            ),
            if (fields.dateOfBirth == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Date of birth is required.',
                  style: TextStyle(color: OtaColors.actionRed),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required.' : null;
}

String _formatDate(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';

String _formatOptionalDate(DateTime? value, {String placeholder = ''}) =>
    value == null ? placeholder : _formatDate(value);
