import 'package:flutter/material.dart';

import '../../models/class_session.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/firebase_admin_write_service.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';
import '../../widgets/admin/admin_location_selector.dart';
import '../../widgets/schedule_time_field.dart';
import '../../services/location_time_service.dart';
import '../../widgets/unsaved_changes_guard.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final _writeService = FirebaseAdminWriteService();
  var _selectedWeekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appDataService, adminLocationController]),
      builder: (context, child) {
        final selectedLocationId = adminLocationController.selectedLocationId;
        final sessions =
            appDataService
                .scheduleForWeekday(_selectedWeekday)
                .where(
                  (session) =>
                      !adminLocationController.isSuperAdmin ||
                      selectedLocationId == null ||
                      session.locationId == selectedLocationId,
                )
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

        return AdminPageShell(
          selectedDestination: AdminNavDestination.schedule,
          title: 'Schedule',
          subtitle: 'Update class schedules shown to students and parents.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminLocationSelector(),
              _ScheduleToolbar(
                onAddClass: () => _openClassSheet(),
                onBulkAction: _openBulkActionSheet,
              ),
              const SizedBox(height: 14),
              _DaySelector(
                selectedWeekday: _selectedWeekday,
                onSelected: (weekday) {
                  setState(() => _selectedWeekday = weekday);
                },
              ),
              const SizedBox(height: 14),
              _SchedulePanel(
                weekdayLabel: _weekdayLabel(_selectedWeekday),
                sessions: sessions,
                isLoading: appDataService.isScheduleLoading,
                errorMessage: appDataService.scheduleErrorMessage,
                onEdit: _openClassSheet,
                onDelete: _confirmDelete,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openClassSheet([ClassSession? session]) async {
    final result = await showModalBottomSheet<ClassSessionWriteData>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return _ClassFormSheet(
          selectedWeekday: _selectedWeekday,
          session: session,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      await _writeService.saveClassSession(result);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session == null ? 'Class saved.' : 'Class updated.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save class.')));
    }
  }

  Future<void> _openBulkActionSheet() async {
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return const _BulkScheduleActionSheet();
      },
    );

    if (!mounted || applied != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk schedule actions are not live yet.')),
    );
  }

  Future<void> _confirmDelete(ClassSession session) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete class?'),
          content: Text(
            'This will permanently delete ${session.className} from the schedule.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.maroon,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Delete Class'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    try {
      await _writeService.deleteClassSession(session.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete class.')));
    }
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.onAddClass,
    required this.onBulkAction,
  });

  final VoidCallback onAddClass;
  final VoidCallback onBulkAction;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(width: 4, height: 34, color: OtaColors.maroon),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
            child: Text(
              'Class schedule management',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onBulkAction,
            icon: const Icon(Icons.playlist_remove_outlined, size: 18),
            label: const Text('Bulk Actions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: OtaColors.maroon,
              side: const BorderSide(color: OtaColors.maroon),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: onAddClass,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Class'),
            style: FilledButton.styleFrom(
              backgroundColor: OtaColors.maroon,
              foregroundColor: OtaColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedWeekday, required this.onSelected});

  final int selectedWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final weekday in _weekdaysSundayFirst) ...[
            _DayButton(
              label: _weekdayLabel(weekday),
              isSelected: weekday == selectedWeekday,
              onTap: () => onSelected(weekday),
            ),
            if (weekday != _weekdaysSundayFirst.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? OtaColors.white : OtaColors.ink,
        backgroundColor: isSelected ? OtaColors.navy : OtaColors.white,
        side: BorderSide(
          color: isSelected ? OtaColors.navy : const Color(0xFFD0D5DD),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.weekdayLabel,
    required this.sessions,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
    required this.onDelete,
  });

  final String weekdayLabel;
  final List<ClassSession> sessions;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<ClassSession> onEdit;
  final ValueChanged<ClassSession> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.calendar_month_outlined,
            title: weekdayLabel,
            detail: isLoading
                ? 'Loading classes'
                : '${sessions.length} active classes',
          ),
          if (isLoading)
            const _LoadingState(message: 'Loading schedule from Firestore.')
          else if (errorMessage != null)
            _EmptyState(message: errorMessage!)
          else if (sessions.isEmpty)
            const _EmptyState(message: 'No classes scheduled for this day.')
          else
            for (final session in sessions) ...[
              _ScheduleRow(
                session: session,
                onEdit: () => onEdit(session),
                onDelete: () => onDelete(session),
              ),
              if (session != sessions.last)
                const Divider(height: 1, color: Color(0xFFE1E4EA)),
            ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassSession session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final details = Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InlineMeta(
                icon: Icons.schedule_outlined,
                label: session.timeRangeLabel,
              ),
              _InlineMeta(
                icon: Icons.workspace_premium_outlined,
                label: session.eligibilityLabel,
              ),
              const _StatusBadge(label: 'Active', tone: _BadgeTone.success),
              if (session.eligibilityNote != null)
                _StatusBadge(
                  label: session.eligibilityNote!,
                  tone: _BadgeTone.neutral,
                ),
            ],
          );

          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionLink(label: 'Edit', onPressed: onEdit),
              const SizedBox(width: 4),
              _ActionLink(label: 'Delete', onPressed: onDelete, isDanger: true),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.className, style: _rowTitleStyle(context)),
                const SizedBox(height: 8),
                details,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(session.className, style: _rowTitleStyle(context)),
              ),
              Expanded(flex: 5, child: details),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ClassFormSheet extends StatefulWidget {
  const _ClassFormSheet({required this.selectedWeekday, this.session});

  final int selectedWeekday;
  final ClassSession? session;

  @override
  State<_ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<_ClassFormSheet> {
  late final TextEditingController _classNameController;
  late final TextEditingController _beltsController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _eligibilityNoteController;
  late int _weekday;
  int? _startMinutes;
  int? _endMinutes;
  late bool _isActive;
  String? _validationMessage;
  late final String _initialFingerprint;
  final _closeController = UnsavedChangesController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _weekday = widget.selectedWeekday;
    _classNameController = TextEditingController(
      text: session?.className ?? '',
    );
    _startMinutes = session?.startMinutes;
    _endMinutes = session?.endMinutes;
    _beltsController = TextEditingController(
      text: session?.eligibleBelts.join(', ') ?? '',
    );
    _descriptionController = TextEditingController(
      text: session?.description ?? '',
    );
    _eligibilityNoteController = TextEditingController(
      text: session?.eligibilityNote ?? '',
    );
    _isActive = session?.isPublished ?? true;
    _initialFingerprint = _formFingerprint;
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _beltsController.dispose();
    _descriptionController.dispose();
    _eligibilityNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.session != null;

    return UnsavedChangesGuard(
      controller: _closeController,
      isDirty: () => _formFingerprint != _initialFingerprint,
      isSaving: _submitting,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHeader(
                title: isEditing ? 'Edit Class' : 'Add Class',
                subtitle: 'Class sessions save to the Firestore schedule.',
              ),
              const SizedBox(height: 14),
              _AdminTextField(
                controller: _classNameController,
                label: 'Class name',
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _weekday,
                decoration: _fieldDecoration('Day'),
                items: [
                  for (final weekday in _weekdaysSundayFirst)
                    DropdownMenuItem<int>(
                      value: weekday,
                      child: Text(_weekdayLabel(weekday)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _weekday = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 560;
                  final fields = [
                    ScheduleTimeField(
                      label: 'Start time',
                      minutes: _startMinutes,
                      onChanged: (value) =>
                          setState(() => _startMinutes = value),
                    ),
                    ScheduleTimeField(
                      label: 'End time',
                      minutes: _endMinutes,
                      onChanged: (value) => setState(() => _endMinutes = value),
                    ),
                  ];

                  if (!twoColumns) {
                    return Column(
                      children: [
                        fields.first,
                        const SizedBox(height: 10),
                        fields.last,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: fields.first),
                      const SizedBox(width: 10),
                      Expanded(child: fields.last),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Class times are entered in ${const LocationTimeService().friendlyTimeZoneLabelFor(_adminLocationId())}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _AdminTextField(
                controller: _beltsController,
                label: 'Eligible belts',
                helperText: 'Comma-separated belt ranks.',
              ),
              const SizedBox(height: 10),
              _AdminTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _AdminTextField(
                controller: _eligibilityNoteController,
                label: 'Eligibility note',
              ),
              const SizedBox(height: 10),
              _SwitchRow(
                title: 'Active class',
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              if (_validationMessage != null) ...[
                _ValidationMessage(message: _validationMessage!),
                const SizedBox(height: 10),
              ],
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _closeController.requestClose,
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: OtaColors.maroon,
                      foregroundColor: OtaColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(isEditing ? 'Update Class' : 'Save Class'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_submitting) return;
    final className = _classNameController.text.trim();
    final startMinutes = _startMinutes;
    final endMinutes = _endMinutes;

    if (className.isEmpty) {
      setState(() => _validationMessage = 'Class name is required.');
      return;
    }

    if (startMinutes == null) {
      setState(() => _validationMessage = 'Start time is required.');
      return;
    }

    if (endMinutes == null) {
      setState(() => _validationMessage = 'End time is required.');
      return;
    }

    if (endMinutes <= startMinutes) {
      setState(() => _validationMessage = 'End time must be after start time.');
      return;
    }

    final session = widget.session;
    final classTypeId = session != null && session.className.trim() == className
        ? session.classTypeId
        : _classTypeIdForClassName(className);
    final data = ClassSessionWriteData(
      id: session?.id,
      className: className,
      classTypeId: classTypeId,
      bulkGroupId: preferredClassGroupIdForClassName(className),
      locationId: _adminLocationId(),
      weekday: _weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      eligibleBelts: _parseCommaSeparated(_beltsController.text),
      description: _descriptionController.text.trim(),
      eligibilityNote: _eligibilityNoteController.text.trim().isEmpty
          ? null
          : _eligibilityNoteController.text.trim(),
      isActive: _isActive,
      resumesOn: session?.resumesOn,
      createdAt: session?.createdAt,
    );

    _submitting = true;
    Navigator.of(context).pop(data);
  }

  String get _formFingerprint => [
    _classNameController.text,
    _beltsController.text,
    _descriptionController.text,
    _eligibilityNoteController.text,
    _weekday,
    _startMinutes ?? '',
    _endMinutes ?? '',
    _isActive,
  ].join('\u0000');

  String _adminLocationId() {
    return adminWriteLocationId();
  }
}

class _BulkScheduleActionSheet extends StatefulWidget {
  const _BulkScheduleActionSheet();

  @override
  State<_BulkScheduleActionSheet> createState() =>
      _BulkScheduleActionSheetState();
}

class _BulkScheduleActionSheetState extends State<_BulkScheduleActionSheet> {
  var _action = _BulkScheduleAction.deleteAllClassesInRange;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _selectedClassName;
  late final TextEditingController _reasonController;

  List<String> get _classNames {
    final names = {
      for (final sessions in appDataService.schedule.values)
        for (final session in sessions) session.className,
    }.toList()..sort();

    return names;
  }

  List<_BulkAffectedSession> get _affectedSessions {
    final dateRange = _normalizedDateRange(_startDate, _endDate);
    final affected = <_BulkAffectedSession>[];

    for (
      var date = dateRange.start;
      !date.isAfter(dateRange.end);
      date = date.add(const Duration(days: 1))
    ) {
      final sessions = appDataService.scheduleForWeekday(date.weekday);
      for (final session in sessions) {
        final matchesClass =
            _action == _BulkScheduleAction.deleteAllClassesInRange ||
            session.className == _selectedClassName;

        if (matchesClass) {
          affected.add(_BulkAffectedSession(date: date, session: session));
        }
      }
    }

    return affected;
  }

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    final classNames = _classNames;
    _startDate = today;
    _endDate = today.add(const Duration(days: 2));
    _selectedClassName = classNames.isEmpty ? '' : classNames.first;
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final affectedSessions = _affectedSessions;
        final showClassSelector =
            _action == _BulkScheduleAction.deleteClassInRange;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHeader(
                  title: 'Bulk Schedule Action',
                  subtitle:
                      'Preview only. Bulk schedule deletes are not implemented yet.',
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OtaColors.softRed,
                    border: Border.all(color: const Color(0xFFE7C8CE)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Use this for closures, vacation days, or removing one recurring class from a date range.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OtaColors.maroon,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_BulkScheduleAction>(
                  initialValue: _action,
                  decoration: _fieldDecoration('Bulk action'),
                  items: [
                    for (final action in _BulkScheduleAction.values)
                      DropdownMenuItem<_BulkScheduleAction>(
                        value: action,
                        child: Text(action.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _action = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 560;
                    final fields = [
                      _DatePickerField(
                        label: 'Start date',
                        date: _startDate,
                        onChanged: (date) => setState(() => _startDate = date),
                      ),
                      _DatePickerField(
                        label: 'End date',
                        date: _endDate,
                        onChanged: (date) => setState(() => _endDate = date),
                      ),
                    ];

                    if (!twoColumns) {
                      return Column(
                        children: [
                          fields.first,
                          const SizedBox(height: 10),
                          fields.last,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: 10),
                        Expanded(child: fields.last),
                      ],
                    );
                  },
                ),
                if (showClassSelector) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClassName.isEmpty
                        ? null
                        : _selectedClassName,
                    decoration: _fieldDecoration('Class to remove'),
                    items: [
                      for (final className in _classNames)
                        DropdownMenuItem<String>(
                          value: className,
                          child: Text(className),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedClassName = value);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: _fieldDecoration('Internal reason / note'),
                ),
                const SizedBox(height: 14),
                _BulkImpactPreview(affectedSessions: affectedSessions),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      icon: const Icon(
                        Icons.playlist_remove_outlined,
                        size: 18,
                      ),
                      label: const Text('Close Preview'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OtaColors.maroon,
                        foregroundColor: OtaColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2026),
          lastDate: DateTime(2027, 12, 31),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: OtaColors.maroon,
                  onPrimary: OtaColors.white,
                  surface: OtaColors.white,
                  onSurface: OtaColors.ink,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          onChanged(DateUtils.dateOnly(picked));
        }
      },
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: OtaColors.ink,
        side: const BorderSide(color: Color(0xFFD0D5DD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined, color: OtaColors.maroon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(date),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkImpactPreview extends StatelessWidget {
  const _BulkImpactPreview({required this.affectedSessions});

  final List<_BulkAffectedSession> affectedSessions;

  @override
  Widget build(BuildContext context) {
    final previewRows = affectedSessions.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFD0D5DD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.manage_search_outlined,
                color: OtaColors.navy,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preview impact',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(
                label: '${affectedSessions.length} classes',
                tone: _BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (affectedSessions.isEmpty)
            Text(
              'No matching classes in this date range.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            )
          else ...[
            for (final affected in previewRows) ...[
              _BulkPreviewRow(affected: affected),
              if (affected != previewRows.last)
                const Divider(height: 12, color: Color(0xFFE1E4EA)),
            ],
            if (affectedSessions.length > previewRows.length) ...[
              const SizedBox(height: 8),
              Text(
                '+${affectedSessions.length - previewRows.length} more matching classes',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: OtaColors.maroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BulkPreviewRow extends StatelessWidget {
  const _BulkPreviewRow({required this.affected});

  final _BulkAffectedSession affected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 94,
          child: Text(
            _formatShortDate(affected.date),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OtaColors.maroon,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            affected.session.className,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          affected.session.timeRangeLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: OtaColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: OtaColors.mutedText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isDanger ? OtaColors.actionRed : OtaColors.maroon,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFF0A0AA)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: OtaColors.actionRed,
          fontWeight: FontWeight.w800,
        ),
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

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.helperText,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _fieldDecoration(label, helperText: helperText),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: OtaColors.maroon,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OtaColors.ink,
          fontWeight: FontWeight.w800,
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

enum _BulkScheduleAction {
  deleteAllClassesInRange('Delete all classes in date range'),
  deleteClassInRange('Delete one class in date range');

  const _BulkScheduleAction(this.label);

  final String label;
}

class _BulkAffectedSession {
  const _BulkAffectedSession({required this.date, required this.session});

  final DateTime date;
  final ClassSession session;
}

class _DateRange {
  const _DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

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

InputDecoration _fieldDecoration(String label, {String? helperText}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
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

List<String> _parseCommaSeparated(String value) {
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

String _classTypeIdForClassName(String className) {
  final normalized = className.trim();
  return switch (normalized) {
    'Little Tiger (Age 3-5)' || 'Little Tiger' => 'little-tiger',
    'Level 1' => 'level-1',
    'Level 2' => 'level-2',
    'Level 3' => 'level-3',
    'Level 4' => 'level-4',
    'Black Belt' || 'Teen & Black Belt' || 'Adult' => 'teen-adult',
    'Teen/Adult Sparring' => 'teen-adult-sparring',
    'Level 1 / Level 2 Sparring' => 'level-1-2-sparring',
    _ => _slugForClassName(normalized),
  };
}

String _slugForClassName(String className) {
  final slug = className
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'class-session' : slug;
}

String _formatDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatShortDate(DateTime date) {
  return '${_weekdayLabel(date.weekday).substring(0, 3)} ${_monthNames[date.month - 1]} ${date.day}';
}

_DateRange _normalizedDateRange(DateTime first, DateTime second) {
  final start = DateUtils.dateOnly(first);
  final end = DateUtils.dateOnly(second);

  if (end.isBefore(start)) {
    return _DateRange(start: end, end: start);
  }

  return _DateRange(start: start, end: end);
}

const _weekdaysSundayFirst = [
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.sunday => 'Sunday',
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    _ => 'Sunday',
  };
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
