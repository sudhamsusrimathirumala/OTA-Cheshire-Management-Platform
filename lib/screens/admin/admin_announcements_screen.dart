import 'package:flutter/material.dart';

import '../../models/academy_announcement.dart';
import '../../models/notification_item.dart';
import '../../models/student_profile.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/firebase_admin_write_service.dart';
import '../../theme/ota_colors.dart';
import '../../utils/notification_formatters.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

enum _AnnouncementFilter {
  all,
  draft,
  published,
  archived,
  important,
  critical,
}

enum _AnnouncementStatus { draft, published, archived }

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _writeService = FirebaseAdminWriteService();
  var _selectedFilter = _AnnouncementFilter.all;

  List<_AdminAnnouncement> get _announcements {
    return [
      for (final announcement in appDataService.adminAnnouncements)
        _AdminAnnouncement.fromAcademyAnnouncement(announcement),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<_AdminAnnouncement> get _filteredAnnouncements {
    return switch (_selectedFilter) {
      _AnnouncementFilter.all => _announcements,
      _AnnouncementFilter.draft =>
        _announcements
            .where(
              (announcement) =>
                  announcement.status == _AnnouncementStatus.draft,
            )
            .toList(growable: false),
      _AnnouncementFilter.published =>
        _announcements
            .where(
              (announcement) =>
                  announcement.status == _AnnouncementStatus.published,
            )
            .toList(growable: false),
      _AnnouncementFilter.archived =>
        _announcements
            .where(
              (announcement) =>
                  announcement.status == _AnnouncementStatus.archived,
            )
            .toList(growable: false),
      _AnnouncementFilter.important =>
        _announcements
            .where(
              (announcement) =>
                  announcement.priority == NotificationPriority.important,
            )
            .toList(growable: false),
      _AnnouncementFilter.critical =>
        _announcements
            .where(
              (announcement) =>
                  announcement.priority == NotificationPriority.critical,
            )
            .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final announcements = _filteredAnnouncements;

        return AdminPageShell(
          selectedDestination: AdminNavDestination.announcements,
          title: 'Announcements',
          subtitle: 'Create announcements and notifications for families.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnnouncementsToolbar(
                onCreateAnnouncement: () => _openAnnouncementSheet(),
              ),
              const SizedBox(height: 14),
              _FilterRow(
                selectedFilter: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 14),
              _AnnouncementsPanel(
                announcements: announcements,
                isLoading: appDataService.isAnnouncementsLoading,
                errorMessage: appDataService.announcementsErrorMessage,
                onEdit: _openAnnouncementSheet,
                onPreview: _previewAnnouncement,
                onArchive: _confirmArchive,
                onDelete: _confirmDelete,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAnnouncementSheet([
    _AdminAnnouncement? announcement,
  ]) async {
    final result = await showModalBottomSheet<_AnnouncementFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return _AnnouncementFormSheet(announcement: announcement);
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (!useFirebase) {
      final mockMessage = switch (result.action) {
        _AnnouncementSaveAction.draft => 'Mock draft saved.',
        _AnnouncementSaveAction.publish => 'Mock announcement published.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mockMessage)));
      return;
    }

    try {
      await _writeService.saveAnnouncement(result.data);

      if (!mounted) {
        return;
      }

      final message = result.isEditing
          ? 'Announcement updated.'
          : switch (result.action) {
              _AnnouncementSaveAction.draft => 'Announcement draft saved.',
              _AnnouncementSaveAction.publish => 'Announcement published.',
            };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save announcement.')),
      );
    }
  }

  Future<void> _previewAnnouncement(_AdminAnnouncement announcement) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(announcement.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(announcement.body),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: announcement.category.label,
                    tone: _BadgeTone.navy,
                  ),
                  _Badge(
                    label: announcement.priority.label,
                    tone: _priorityTone(announcement.priority),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmArchive(_AdminAnnouncement announcement) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive announcement?'),
          content: Text(
            'This will remove "${announcement.title}" from family-facing announcement lists.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.maroon,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Archive Announcement'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldArchive != true) {
      return;
    }

    if (!useFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${announcement.title} mock archived.')),
      );
      return;
    }

    try {
      await _writeService.archiveAnnouncement(announcement.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${announcement.title} archived.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to archive announcement.')),
      );
    }
  }

  Future<void> _confirmDelete(_AdminAnnouncement announcement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently delete announcement?'),
          content: Text(
            'This will permanently delete "${announcement.title}" from Firestore. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.actionRed,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    if (!useFirebase) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${announcement.title} mock deleted.')),
      );
      return;
    }

    try {
      await _writeService.deleteAnnouncement(announcement.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${announcement.title} deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete announcement.')),
      );
    }
  }
}

class _AnnouncementsToolbar extends StatelessWidget {
  const _AnnouncementsToolbar({required this.onCreateAnnouncement});

  final VoidCallback onCreateAnnouncement;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Row(
        children: [
          Container(width: 4, height: 34, color: OtaColors.maroon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Family-facing announcement management',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onCreateAnnouncement,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Announcement'),
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selectedFilter, required this.onSelected});

  final _AnnouncementFilter selectedFilter;
  final ValueChanged<_AnnouncementFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _AnnouncementFilter.values) ...[
            _FilterButton(
              label: filter.label,
              selected: filter == selectedFilter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _AnnouncementFilter.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _AnnouncementsPanel extends StatelessWidget {
  const _AnnouncementsPanel({
    required this.announcements,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
    required this.onPreview,
    required this.onArchive,
    required this.onDelete,
  });

  final List<_AdminAnnouncement> announcements;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<_AdminAnnouncement> onEdit;
  final ValueChanged<_AdminAnnouncement> onPreview;
  final ValueChanged<_AdminAnnouncement> onArchive;
  final ValueChanged<_AdminAnnouncement> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.campaign_outlined,
            title: 'Announcements',
            detail: isLoading
                ? 'Loading announcements'
                : '${announcements.length} shown',
          ),
          if (isLoading)
            const _LoadingState(
              message: 'Loading announcements from Firestore.',
            )
          else if (errorMessage != null)
            _EmptyState(message: errorMessage!)
          else if (announcements.isEmpty)
            const _EmptyState(message: 'No announcements match this filter.')
          else
            for (final announcement in announcements) ...[
              _AnnouncementRow(
                announcement: announcement,
                onEdit: () => onEdit(announcement),
                onPreview: () => onPreview(announcement),
                onArchive: () => onArchive(announcement),
                onDelete: () => onDelete(announcement),
              ),
              if (announcement != announcements.last)
                const Divider(height: 1, color: Color(0xFFE1E4EA)),
            ],
        ],
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.announcement,
    required this.onEdit,
    required this.onPreview,
    required this.onArchive,
    required this.onDelete,
  });

  final _AdminAnnouncement announcement;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityTone = _priorityTone(announcement.priority);
    final statusTone = switch (announcement.status) {
      _AnnouncementStatus.draft => _BadgeTone.warning,
      _AnnouncementStatus.published => _BadgeTone.success,
      _AnnouncementStatus.archived => _BadgeTone.navy,
    };
    final accentColor = switch (announcement.priority) {
      NotificationPriority.critical => OtaColors.actionRed,
      NotificationPriority.important => OtaColors.maroon,
      NotificationPriority.general => switch (announcement.status) {
        _AnnouncementStatus.draft => const Color(0xFFD79A16),
        _AnnouncementStatus.archived => const Color(0xFF98A2B3),
        _AnnouncementStatus.published => OtaColors.navy,
      },
    };

    return Container(
      decoration: BoxDecoration(
        color: announcement.priority == NotificationPriority.critical
            ? const Color(0xFFFFF4F4)
            : OtaColors.white,
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 780;
          final badges = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(label: announcement.category.label, tone: _BadgeTone.navy),
              _Badge(label: announcement.priority.label, tone: priorityTone),
              _Badge(label: announcement.status.label, tone: statusTone),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionLink(label: 'Edit', onPressed: onEdit),
              const SizedBox(width: 2),
              _ActionLink(label: 'Preview', onPressed: onPreview),
              const SizedBox(width: 2),
              _ActionLink(label: 'Archive', onPressed: onArchive),
              const SizedBox(width: 2),
              _ActionLink(label: 'Delete', onPressed: onDelete, isDanger: true),
            ],
          );

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                announcement.summary,
                maxLines: isNarrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          final dateText = Text(
            _formatDateTime(announcement.timestamp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                badges,
                const SizedBox(height: 8),
                dateText,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: titleBlock),
              Expanded(flex: 4, child: badges),
              SizedBox(width: 116, child: dateText),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementFormSheet extends StatefulWidget {
  const _AnnouncementFormSheet({this.announcement});

  final _AdminAnnouncement? announcement;

  @override
  State<_AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends State<_AnnouncementFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _bodyController;
  late final TextEditingController _studentSearchController;
  late NotificationCategory _category;
  late NotificationPriority _priority;
  late _Audience _audience;
  late bool _requiresAction;
  final _targetBelts = <String>{};
  final _targetClassTypeIds = <String>{};
  final _targetStudentProfileIds = <String>{};
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final announcement = widget.announcement;
    _titleController = TextEditingController(text: announcement?.title ?? '');
    _summaryController = TextEditingController(
      text: announcement?.summary ?? '',
    );
    _bodyController = TextEditingController(text: announcement?.body ?? '');
    _studentSearchController = TextEditingController();
    _category = announcement?.category ?? NotificationCategory.general;
    _priority = announcement?.priority ?? NotificationPriority.general;
    _requiresAction = announcement?.source.requiresAction ?? false;
    _audience = _audienceForFirestoreValue(announcement?.source.audienceType);
    _targetBelts.addAll(announcement?.source.targetBelts ?? const <String>[]);
    _targetClassTypeIds.addAll(
      announcement?.source.targetClassTypeIds ?? const <String>[],
    );
    _targetStudentProfileIds.addAll(
      announcement?.source.targetStudentProfileIds ?? const <String>[],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.announcement != null;
    final announcementStatus = widget.announcement?.status;
    final canSaveDraft =
        !isEditing || announcementStatus == _AnnouncementStatus.draft;
    final publishButtonLabel =
        isEditing && announcementStatus == _AnnouncementStatus.published
        ? 'Update Published Announcement'
        : 'Publish Announcement';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: isEditing ? 'Edit Announcement' : 'Create Announcement',
              subtitle:
                  'Drafts and published announcements write to Firestore.',
            ),
            const SizedBox(height: 14),
            _AdminTextField(controller: _titleController, label: 'Title'),
            const SizedBox(height: 10),
            _AdminTextField(controller: _summaryController, label: 'Summary'),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: _bodyController,
              label: 'Full message/body',
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final fields = [
                  DropdownButtonFormField<NotificationCategory>(
                    initialValue: _category,
                    decoration: _fieldDecoration('Category'),
                    items: [
                      for (final category in NotificationCategory.values)
                        DropdownMenuItem<NotificationCategory>(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),
                  DropdownButtonFormField<NotificationPriority>(
                    initialValue: _priority,
                    decoration: _fieldDecoration('Priority'),
                    items: [
                      for (final priority in NotificationPriority.values)
                        DropdownMenuItem<NotificationPriority>(
                          value: priority,
                          child: Text(priority.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _priority = value);
                      }
                    },
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
            const SizedBox(height: 14),
            DropdownButtonFormField<_Audience>(
              initialValue: _audience,
              decoration: _fieldDecoration('Audience'),
              items: [
                for (final audience in _Audience.values)
                  DropdownMenuItem<_Audience>(
                    value: audience,
                    child: Text(audience.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _audience = value);
                }
              },
            ),
            const SizedBox(height: 10),
            _buildAudienceTargeting(),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _requiresAction,
              onChanged: (value) => setState(() => _requiresAction = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: OtaColors.maroon,
              title: Text(
                'Requires action',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Shows an action-needed badge on family notification details.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (canSaveDraft)
                  OutlinedButton(
                    onPressed: () => _submit(_AnnouncementSaveAction.draft),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OtaColors.maroon,
                      side: const BorderSide(color: OtaColors.maroon),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Save Draft'),
                  ),
                FilledButton(
                  onPressed: () => _submit(_AnnouncementSaveAction.publish),
                  style: FilledButton.styleFrom(
                    backgroundColor: OtaColors.maroon,
                    foregroundColor: OtaColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(publishButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceTargeting() {
    return switch (_audience) {
      _Audience.everyone => const _AudienceHint(
        message: 'Everyone at this location will see this announcement.',
      ),
      _Audience.belt => _buildBeltTargeting(),
      _Audience.classType => _buildClassTypeTargeting(),
      _Audience.students => _buildStudentTargeting(),
    };
  }

  Widget _buildBeltTargeting() {
    final belts = _beltOptions();
    if (belts.isEmpty) {
      return const _AudienceHint(message: 'No belt levels are available yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: null,
          decoration: _fieldDecoration('Add belt rank'),
          hint: const Text('Select a belt rank'),
          items: [
            for (final belt in belts)
              DropdownMenuItem<String>(value: belt, child: Text(belt)),
          ],
          onChanged: (belt) {
            if (belt != null) {
              setState(() {
                _targetBelts.add(belt);
              });
            }
          },
        ),
        const SizedBox(height: 8),
        _SelectedTargetList(
          emptyMessage: 'No belt ranks selected.',
          selectedLabels: _sortedValues(_targetBelts),
          onRemove: (label) => setState(() => _targetBelts.remove(label)),
        ),
      ],
    );
  }

  Widget _buildClassTypeTargeting() {
    final classTypes = _classTypeOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: null,
          decoration: _fieldDecoration('Add class group'),
          hint: const Text('Select a class group'),
          items: [
            for (final classType in classTypes)
              DropdownMenuItem<String>(
                value: classType.id,
                child: Text(classType.label),
              ),
          ],
          onChanged: (classTypeId) {
            if (classTypeId != null) {
              setState(() {
                _targetClassTypeIds.add(classTypeId);
              });
            }
          },
        ),
        const SizedBox(height: 8),
        _SelectedTargetList(
          emptyMessage: 'No class groups selected.',
          selectedLabels: [
            for (final classTypeId in _sortedValues(_targetClassTypeIds))
              _classGroupLabelFor(classTypeId),
          ],
          onRemove: (label) {
            final classType = classTypes.firstWhere(
              (option) => option.label == label,
              orElse: () => _TargetOption(id: label, label: label),
            );
            setState(() => _targetClassTypeIds.remove(classType.id));
          },
        ),
      ],
    );
  }

  Widget _buildStudentTargeting() {
    final query = _studentSearchController.text.trim().toLowerCase();
    final students = _studentOptions()
        .where((student) {
          if (query.isEmpty) {
            return true;
          }

          return student.name.toLowerCase().contains(query) ||
              student.belt.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _studentSearchController,
          decoration: _fieldDecoration('Search students'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: students.isEmpty
              ? const _AudienceHint(message: 'No students match that search.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return CheckboxListTile(
                      value: _targetStudentProfileIds.contains(student.id),
                      onChanged: (selected) {
                        setState(() {
                          selected == true
                              ? _targetStudentProfileIds.add(student.id)
                              : _targetStudentProfileIds.remove(student.id);
                        });
                      },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: OtaColors.maroon,
                      title: Text(student.name),
                      subtitle: Text(student.belt),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        _SelectedTargetList(
          emptyMessage: 'No students selected.',
          selectedLabels: [
            for (final student in _studentOptions())
              if (_targetStudentProfileIds.contains(student.id)) student.name,
          ],
          onRemove: (name) {
            final student = _studentOptions().firstWhere(
              (student) => student.name == name,
            );
            setState(() => _targetStudentProfileIds.remove(student.id));
          },
        ),
      ],
    );
  }

  List<String> _beltOptions() {
    final belts = <String>{
      for (final student in appDataService.adminStudentProfiles)
        if (student.belt.trim().isNotEmpty) student.belt.trim(),
      ..._targetBelts,
    };
    final ordered = <String>[];

    for (final belt in appDataService.curriculumBeltOrder) {
      if (belts.remove(belt)) {
        ordered.add(belt);
      }
    }

    final remaining = belts.toList()..sort();
    return [...ordered, ...remaining];
  }

  List<_TargetOption> _classTypeOptions() {
    final classTypes = {
      for (final classGroup in _announcementClassGroups)
        classGroup.id: classGroup.label,
    };
    for (final classTypeId in _targetClassTypeIds) {
      classTypes.putIfAbsent(classTypeId, () => _labelForId(classTypeId));
    }

    final options = [
      for (final entry in classTypes.entries)
        _TargetOption(id: entry.key, label: entry.value),
    ]..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  List<StudentProfile> _studentOptions() {
    return [...appDataService.adminStudentProfiles]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String? _targetingValidationMessage() {
    return switch (_audience) {
      _Audience.everyone => null,
      _Audience.belt =>
        _targetBelts.isEmpty ? 'Select at least one belt level.' : null,
      _Audience.classType =>
        _targetClassTypeIds.isEmpty ? 'Select at least one class type.' : null,
      _Audience.students =>
        _targetStudentProfileIds.isEmpty
            ? 'Select at least one student.'
            : null,
    };
  }

  String _adminLocationId() {
    final accountLocationId = appDataService.currentUserAccount.locationId;
    if (accountLocationId.trim().isNotEmpty) {
      return accountLocationId;
    }

    return appDataService.selectedStudentProfile.locationId;
  }

  void _submit(_AnnouncementSaveAction action) {
    final title = _titleController.text.trim();
    final summary = _summaryController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      setState(() => _validationMessage = 'Title is required.');
      return;
    }

    if (summary.isEmpty) {
      setState(() => _validationMessage = 'Summary is required.');
      return;
    }

    if (body.isEmpty) {
      setState(() => _validationMessage = 'Full message/body is required.');
      return;
    }

    final targetingMessage = _targetingValidationMessage();
    if (targetingMessage != null) {
      setState(() => _validationMessage = targetingMessage);
      return;
    }

    final targetBelts = _audience == _Audience.belt
        ? _sortedValues(_targetBelts)
        : <String>[];
    final targetClassTypeIds = _audience == _Audience.classType
        ? _sortedValues(_targetClassTypeIds)
        : <String>[];
    final targetStudentProfileIds = _audience == _Audience.students
        ? _sortedValues(_targetStudentProfileIds)
        : <String>[];
    final status = action == _AnnouncementSaveAction.publish
        ? 'published'
        : 'draft';
    final announcement = widget.announcement;
    final locationId = announcement?.locationId ?? _adminLocationId();

    final data = announcement == null
        ? AnnouncementWriteData(
            title: title,
            summary: summary,
            body: body,
            announcementType: _category.name,
            priority: _priority.name,
            status: status,
            locationId: locationId,
            requiresAction: _requiresAction,
            audienceType: _audience.firestoreValue,
            targetBelts: targetBelts,
            targetClassTypeIds: targetClassTypeIds,
            targetStudentProfileIds: targetStudentProfileIds,
            targetUserIds: const <String>[],
          )
        : AnnouncementWriteData.fromAnnouncement(
            announcement.source,
            title: title,
            summary: summary,
            body: body,
            announcementType: _category.name,
            priority: _priority.name,
            status: status,
            locationId: locationId,
            requiresAction: _requiresAction,
            audienceType: _audience.firestoreValue,
            targetBelts: targetBelts,
            targetClassTypeIds: targetClassTypeIds,
            targetStudentProfileIds: targetStudentProfileIds,
            targetUserIds: const <String>[],
          );

    Navigator.of(context).pop(
      _AnnouncementFormResult(
        action: action,
        data: data,
        isEditing: announcement != null,
      ),
    );
  }
}

class _AdminAnnouncement {
  const _AdminAnnouncement({
    required this.source,
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    required this.priority,
    required this.status,
    required this.timestamp,
  });

  factory _AdminAnnouncement.fromAcademyAnnouncement(
    AcademyAnnouncement announcement,
  ) {
    return _AdminAnnouncement(
      source: announcement,
      id: announcement.id,
      title: announcement.title,
      summary: announcement.summary,
      body: announcement.body,
      category: announcement.category,
      priority: announcement.notificationPriority,
      status: _statusForAnnouncement(announcement.status),
      timestamp: announcement.displayDate,
    );
  }

  final AcademyAnnouncement source;
  final String id;
  final String title;
  final String summary;
  final String body;
  final NotificationCategory category;
  final NotificationPriority priority;
  final _AnnouncementStatus status;
  final DateTime timestamp;

  String get locationId => source.locationId;
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

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

class _AudienceHint extends StatelessWidget {
  const _AudienceHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: OtaColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectedTargetList extends StatelessWidget {
  const _SelectedTargetList({
    required this.emptyMessage,
    required this.selectedLabels,
    required this.onRemove,
  });

  final String emptyMessage;
  final List<String> selectedLabels;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selectedLabels.isEmpty) {
      return _AudienceHint(message: emptyMessage);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (final label in selectedLabels) ...[
            ListTile(
              dense: true,
              title: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: IconButton(
                onPressed: () => onRemove(label),
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            if (label != selectedLabels.last)
              const Divider(height: 1, color: Color(0xFFE4E7EC)),
          ],
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

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _fieldDecoration(label),
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

enum _BadgeTone { navy, success, warning, important, critical }

enum _AnnouncementSaveAction { draft, publish }

class _AnnouncementFormResult {
  const _AnnouncementFormResult({
    required this.action,
    required this.data,
    required this.isEditing,
  });

  final _AnnouncementSaveAction action;
  final AnnouncementWriteData data;
  final bool isEditing;
}

class _TargetOption {
  const _TargetOption({required this.id, required this.label});

  final String id;
  final String label;
}

const _announcementClassGroups = [
  _TargetOption(id: 'little-tigers', label: 'Little Tigers'),
  _TargetOption(id: 'teen-adult', label: 'Teen and Adult'),
  _TargetOption(id: 'level-1', label: 'Level 1'),
  _TargetOption(id: 'level-2', label: 'Level 2'),
  _TargetOption(id: 'level-3', label: 'Level 3'),
  _TargetOption(id: 'level-4', label: 'Level 4'),
  _TargetOption(id: 'level-1-2-sparring', label: 'Level 1/2 Sparring'),
];

enum _Audience {
  everyone('Everyone', 'everyone'),
  belt('Specific belt', 'belt'),
  classType('Specific class group', 'classType'),
  students('Specific student', 'students');

  const _Audience(this.label, this.firestoreValue);

  final String label;
  final String firestoreValue;
}

extension on _AnnouncementFilter {
  String get label {
    return switch (this) {
      _AnnouncementFilter.all => 'All',
      _AnnouncementFilter.draft => 'Draft',
      _AnnouncementFilter.published => 'Published',
      _AnnouncementFilter.archived => 'Archived',
      _AnnouncementFilter.important => 'Important',
      _AnnouncementFilter.critical => 'Critical',
    };
  }
}

extension on _AnnouncementStatus {
  String get label {
    return switch (this) {
      _AnnouncementStatus.draft => 'Draft',
      _AnnouncementStatus.published => 'Published',
      _AnnouncementStatus.archived => 'Archived',
    };
  }
}

_AnnouncementStatus _statusForAnnouncement(String status) {
  return switch (status) {
    'published' || 'sent' => _AnnouncementStatus.published,
    'archived' => _AnnouncementStatus.archived,
    _ => _AnnouncementStatus.draft,
  };
}

_Audience _audienceForFirestoreValue(String? audienceType) {
  return switch (audienceType) {
    'belt' => _Audience.belt,
    'classType' => _Audience.classType,
    'students' => _Audience.students,
    _ => _Audience.everyone,
  };
}

List<String> _sortedValues(Set<String> values) {
  return values.toList()..sort();
}

String _labelForId(String id) {
  final words = id
      .split(RegExp(r'[-_\s]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return id;
  }

  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _classGroupLabelFor(String id) {
  return _announcementClassGroups
      .firstWhere(
        (classGroup) => classGroup.id == id,
        orElse: () => _TargetOption(id: id, label: _labelForId(id)),
      )
      .label;
}

_BadgeTone _priorityTone(NotificationPriority priority) {
  return switch (priority) {
    NotificationPriority.general => _BadgeTone.navy,
    NotificationPriority.important => _BadgeTone.important,
    NotificationPriority.critical => _BadgeTone.critical,
  };
}

_BadgeColors _badgeColors(_BadgeTone tone) {
  return switch (tone) {
    _BadgeTone.navy => const _BadgeColors(
      background: Color(0xFFEFF2F7),
      border: Color(0xFFC9D1E4),
      foreground: OtaColors.navy,
    ),
    _BadgeTone.success => const _BadgeColors(
      background: Color(0xFFEAF7EF),
      border: Color(0xFFB9DEC6),
      foreground: Color(0xFF23633B),
    ),
    _BadgeTone.warning => const _BadgeColors(
      background: Color(0xFFFFF3CD),
      border: Color(0xFFE9D28E),
      foreground: Color(0xFF7A5200),
    ),
    _BadgeTone.important => const _BadgeColors(
      background: OtaColors.softRed,
      border: Color(0xFFE7C8CE),
      foreground: OtaColors.maroon,
    ),
    _BadgeTone.critical => const _BadgeColors(
      background: Color(0xFFFFE4E8),
      border: Color(0xFFF0A0AA),
      foreground: OtaColors.actionRed,
    ),
  };
}

InputDecoration _fieldDecoration(String label) {
  return InputDecoration(
    labelText: label,
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

String _formatDateTime(DateTime dateTime) {
  final month = _monthNames[dateTime.month - 1];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$month ${dateTime.day}, $hour:$minute $period';
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
