import 'package:flutter/material.dart';

import '../../models/notification_item.dart';
import '../../services/app_data_service_provider.dart';
import '../../theme/ota_colors.dart';
import '../../utils/notification_formatters.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

enum _AnnouncementFilter { all, draft, sent, important, critical }

enum _AnnouncementStatus { draft, sent }

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  var _selectedFilter = _AnnouncementFilter.all;

  List<_AdminAnnouncement> get _announcements {
    return [
      ..._draftAnnouncements,
      for (final notification in appDataService.notifications)
        _AdminAnnouncement.fromNotification(notification),
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
      _AnnouncementFilter.sent =>
        _announcements
            .where(
              (announcement) => announcement.status == _AnnouncementStatus.sent,
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
    final action = await showModalBottomSheet<_AnnouncementSaveAction>(
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

    if (!mounted || action == null) {
      return;
    }

    final message = switch (action) {
      _AnnouncementSaveAction.draft => 'Mock draft saved.',
      _AnnouncementSaveAction.sent => 'Mock announcement sent.',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _confirmDelete(_AdminAnnouncement announcement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete announcement?'),
          content: Text(
            'This mock action will not remove "${announcement.title}" yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // TODO: Delete this announcement through Firebase writes.
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.maroon,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Delete Mock Announcement'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${announcement.title} mock delete confirmed.')),
    );
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
    required this.onDelete,
  });

  final List<_AdminAnnouncement> announcements;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<_AdminAnnouncement> onEdit;
  final ValueChanged<_AdminAnnouncement> onPreview;
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
    required this.onDelete,
  });

  final _AdminAnnouncement announcement;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityTone = _priorityTone(announcement.priority);
    final statusTone = announcement.status == _AnnouncementStatus.draft
        ? _BadgeTone.warning
        : _BadgeTone.success;

    return Container(
      decoration: BoxDecoration(
        color: announcement.priority == NotificationPriority.critical
            ? const Color(0xFFFFF4F4)
            : announcement.status == _AnnouncementStatus.draft
            ? const Color(0xFFFFFAEB)
            : OtaColors.white,
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
  late final TextEditingController _dateTimeController;
  late NotificationCategory _category;
  late NotificationPriority _priority;
  late _AnnouncementStatus _status;
  var _audience = _Audience.allFamilies;

  @override
  void initState() {
    super.initState();
    final announcement = widget.announcement;
    _titleController = TextEditingController(text: announcement?.title ?? '');
    _summaryController = TextEditingController(
      text: announcement?.summary ?? '',
    );
    _bodyController = TextEditingController(text: announcement?.body ?? '');
    _dateTimeController = TextEditingController(
      text: announcement == null ? '' : _formatDateTime(announcement.timestamp),
    );
    _category = announcement?.category ?? NotificationCategory.general;
    _priority = announcement?.priority ?? NotificationPriority.general;
    _status = announcement?.status ?? _AnnouncementStatus.draft;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.announcement != null;

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
              subtitle: 'Mock form only. Changes are not saved yet.',
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
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final fields = [
                  DropdownButtonFormField<_AnnouncementStatus>(
                    initialValue: _status,
                    decoration: _fieldDecoration('Status'),
                    items: [
                      for (final status in _AnnouncementStatus.values)
                        DropdownMenuItem<_AnnouncementStatus>(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                  _AdminTextField(
                    controller: _dateTimeController,
                    label: 'Date/time placeholder',
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
            Text(
              'Audience',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final audience in _Audience.values)
                  ChoiceChip(
                    label: Text(audience.label),
                    selected: audience == _audience,
                    showCheckmark: false,
                    selectedColor: OtaColors.navy,
                    backgroundColor: OtaColors.white,
                    side: BorderSide(
                      color: audience == _audience
                          ? OtaColors.navy
                          : const Color(0xFFD0D5DD),
                    ),
                    labelStyle: TextStyle(
                      color: audience == _audience
                          ? OtaColors.white
                          : OtaColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) {
                      setState(() => _audience = audience);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () {
                    // TODO: Persist draft announcement through Firebase.
                    Navigator.of(context).pop(_AnnouncementSaveAction.draft);
                  },
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
                  onPressed: () {
                    // TODO: Send announcement through Firebase and fan out.
                    Navigator.of(context).pop(_AnnouncementSaveAction.sent);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: OtaColors.maroon,
                    foregroundColor: OtaColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Send Mock Announcement'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAnnouncement {
  const _AdminAnnouncement({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    required this.priority,
    required this.status,
    required this.timestamp,
  });

  factory _AdminAnnouncement.fromNotification(NotificationItem notification) {
    return _AdminAnnouncement(
      id: notification.id,
      title: notification.title,
      summary: notification.summary,
      body: notification.body,
      category: notification.category,
      priority: notification.priority,
      status: _AnnouncementStatus.sent,
      timestamp: notification.timestamp,
    );
  }

  final String id;
  final String title;
  final String summary;
  final String body;
  final NotificationCategory category;
  final NotificationPriority priority;
  final _AnnouncementStatus status;
  final DateTime timestamp;
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

enum _AnnouncementSaveAction { draft, sent }

enum _Audience {
  allFamilies('All Families'),
  specificBeltLevels('Specific Belt Levels'),
  specificClass('Specific Class'),
  individualStudent('Individual Student');

  const _Audience(this.label);

  final String label;
}

extension on _AnnouncementFilter {
  String get label {
    return switch (this) {
      _AnnouncementFilter.all => 'All',
      _AnnouncementFilter.draft => 'Draft',
      _AnnouncementFilter.sent => 'Sent',
      _AnnouncementFilter.important => 'Important',
      _AnnouncementFilter.critical => 'Critical',
    };
  }
}

extension on _AnnouncementStatus {
  String get label {
    return switch (this) {
      _AnnouncementStatus.draft => 'Draft',
      _AnnouncementStatus.sent => 'Sent',
    };
  }
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

final _draftAnnouncements = [
  _AdminAnnouncement(
    id: 'draft_parent_night_out',
    title: 'Parent Night Out Registration',
    summary: 'Draft registration reminder for the next academy event.',
    body:
        'Parent Night Out registration details are being prepared. This announcement will include the event time, registration link, and pickup reminders.',
    category: NotificationCategory.reminder,
    priority: NotificationPriority.general,
    status: _AnnouncementStatus.draft,
    timestamp: DateTime(2026, 6, 25, 10),
  ),
  _AdminAnnouncement(
    id: 'draft_schedule_note',
    title: 'July Schedule Note',
    summary: 'Draft note for families about upcoming July schedule changes.',
    body:
        'July schedule adjustments are being reviewed. Families will receive the final version after class times are confirmed.',
    category: NotificationCategory.scheduleChange,
    priority: NotificationPriority.important,
    status: _AnnouncementStatus.draft,
    timestamp: DateTime(2026, 6, 24, 15),
  ),
];

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
