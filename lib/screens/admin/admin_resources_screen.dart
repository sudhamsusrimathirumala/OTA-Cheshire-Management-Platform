import 'package:flutter/material.dart';

import '../../models/academy_resource.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/firebase_admin_write_service.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';

enum _ResourceFilter { published, draft, archived }

enum _ResourceSaveAction { draft, publish }

class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({super.key});

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  final _writeService = FirebaseAdminWriteService();
  var _selectedFilter = _ResourceFilter.published;

  List<AcademyResource> _filteredResources(List<AcademyResource> resources) {
    return resources.where((resource) {
      return switch (_selectedFilter) {
        _ResourceFilter.published =>
          resource.isPublished && !resource.isArchived,
        _ResourceFilter.draft => !resource.isPublished && !resource.isArchived,
        _ResourceFilter.archived => resource.isArchived,
      };
    }).toList()..sort((a, b) {
      final category = a.categoryLabel.compareTo(b.categoryLabel);
      if (category != 0) {
        return category;
      }
      return a.title.compareTo(b.title);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final resources = _filteredResources(appDataService.resources);

        return AdminPageShell(
          selectedDestination: AdminNavDestination.resources,
          title: 'Resources',
          subtitle: 'Manage family forms, links, and academy references.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResourcesToolbar(onCreateResource: () => _openResourceSheet()),
              const SizedBox(height: 14),
              _FilterRow(
                selectedFilter: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 14),
              _ResourcesPanel(
                resources: resources,
                isLoading: appDataService.isResourcesLoading,
                errorMessage: appDataService.resourcesErrorMessage,
                onEdit: _openResourceSheet,
                onArchive: _confirmArchive,
                onDelete: _confirmDelete,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openResourceSheet([AcademyResource? resource]) async {
    final result = await showModalBottomSheet<_ResourceFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) => _ResourceFormSheet(resource: resource),
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      await _writeService.saveResource(result.data);

      if (!mounted) {
        return;
      }

      final message = result.isEditing
          ? 'Resource updated.'
          : switch (result.action) {
              _ResourceSaveAction.draft => 'Resource draft saved.',
              _ResourceSaveAction.publish => 'Resource published.',
            };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save resource.')));
    }
  }

  Future<void> _confirmArchive(AcademyResource resource) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive resource?'),
          content: Text('This will hide "${resource.title}" from families.'),
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
              child: const Text('Archive Resource'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldArchive != true) {
      return;
    }

    try {
      await _writeService.archiveResource(resource.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Resource archived.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to archive resource.')),
      );
    }
  }

  Future<void> _confirmDelete(AcademyResource resource) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently delete resource?'),
          content: Text(
            'This will permanently delete "${resource.title}" from Firestore. This cannot be undone.',
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

    try {
      await _writeService.deleteResource(resource.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Resource deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete resource.')),
      );
    }
  }
}

class _ResourcesToolbar extends StatelessWidget {
  const _ResourcesToolbar({required this.onCreateResource});

  final VoidCallback onCreateResource;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Row(
        children: [
          Container(width: 4, height: 34, color: OtaColors.maroon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Academy resource management',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onCreateResource,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Resource'),
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

  final _ResourceFilter selectedFilter;
  final ValueChanged<_ResourceFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _ResourceFilter.values) ...[
            _FilterButton(
              label: filter.label,
              selected: filter == selectedFilter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _ResourceFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ResourcesPanel extends StatelessWidget {
  const _ResourcesPanel({
    required this.resources,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final List<AcademyResource> resources;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<AcademyResource> onEdit;
  final ValueChanged<AcademyResource> onArchive;
  final ValueChanged<AcademyResource> onDelete;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.folder_copy_outlined,
            title: 'Resources',
            detail: '${resources.length} shown',
          ),
          if (isLoading)
            const _LoadingState(message: 'Loading resources...')
          else if (errorMessage != null)
            _EmptyState(message: errorMessage!)
          else if (resources.isEmpty)
            const _EmptyState(message: 'No resources found.')
          else
            for (final resource in resources) ...[
              _ResourceRow(
                resource: resource,
                onEdit: () => onEdit(resource),
                onArchive: () => onArchive(resource),
                onDelete: () => onDelete(resource),
              ),
              if (resource != resources.last)
                const Divider(height: 1, color: Color(0xFFE1E4EA)),
            ],
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final AcademyResource resource;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusTone = resource.isArchived
        ? _BadgeTone.navy
        : resource.isPublished
        ? _BadgeTone.success
        : _BadgeTone.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          final badges = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(label: resource.categoryLabel, tone: _BadgeTone.navy),
              _Badge(
                label: resource.resourceTypeLabel,
                tone: _BadgeTone.neutral,
              ),
              _Badge(label: resource.statusLabel, tone: statusTone),
            ],
          );
          final actions = Wrap(
            children: [
              _ActionLink(label: 'Edit', onPressed: onEdit),
              _ActionLink(label: 'Archive', onPressed: onArchive),
              _ActionLink(label: 'Delete', onPressed: onDelete, isDanger: true),
            ],
          );

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resource.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _rowTitleStyle(context),
              ),
              const SizedBox(height: 4),
              Text(
                resource.description.isEmpty
                    ? 'No description'
                    : resource.description,
                maxLines: isNarrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (resource.linkUrl != null) ...[
                const SizedBox(height: 4),
                Text(
                  resource.linkUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OtaColors.maroon,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 8),
                badges,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: titleBlock),
              Expanded(flex: 4, child: badges),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ResourceFormSheet extends StatefulWidget {
  const _ResourceFormSheet({this.resource});

  final AcademyResource? resource;

  @override
  State<_ResourceFormSheet> createState() => _ResourceFormSheetState();
}

class _ResourceFormSheetState extends State<_ResourceFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _linkController;
  late String _resourceType;
  late String _category;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final resource = widget.resource;
    _titleController = TextEditingController(text: resource?.title ?? '');
    _descriptionController = TextEditingController(
      text: resource?.description ?? '',
    );
    _linkController = TextEditingController(text: resource?.linkUrl ?? '');
    _resourceType = resource?.resourceType ?? 'general';
    _category = resource?.category ?? 'general';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.resource != null;
    final isEditingPublished = isEditing && widget.resource!.isPublished;
    final publishLabel = isEditingPublished
        ? 'Update Published Resource'
        : 'Publish Resource';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: isEditing ? 'Edit Resource' : 'Create Resource',
              subtitle: 'Drafts and published resources write to Firestore.',
            ),
            const SizedBox(height: 14),
            _AdminTextField(controller: _titleController, label: 'Title'),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _TwoColumnFields(
              first: DropdownButtonFormField<String>(
                initialValue: _resourceType,
                decoration: _fieldDecoration('Resource type'),
                items: [
                  for (final option in _resourceTypeOptions)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _resourceType = value);
                  }
                },
              ),
              second: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _fieldDecoration('Category'),
                items: [
                  for (final option in _categoryOptions)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: _linkController,
              label: 'Link URL',
              helperText: 'Optional.',
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
                if (!isEditingPublished)
                  OutlinedButton(
                    onPressed: () => _submit(_ResourceSaveAction.draft),
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
                  onPressed: () => _submit(_ResourceSaveAction.publish),
                  style: FilledButton.styleFrom(
                    backgroundColor: OtaColors.maroon,
                    foregroundColor: OtaColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(publishLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit(_ResourceSaveAction action) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationMessage = 'Title is required.');
      return;
    }

    final resource = widget.resource;
    final isPublished = action == _ResourceSaveAction.publish;
    final data = resource == null
        ? ResourceWriteData(
            title: title,
            description: _descriptionController.text.trim(),
            resourceType: _resourceType,
            category: _category,
            linkUrl: _linkController.text.trim().isEmpty
                ? null
                : _linkController.text.trim(),
            locationId: _adminLocationId(),
            isPublished: isPublished,
          )
        : ResourceWriteData.fromResource(
            resource,
            title: title,
            description: _descriptionController.text.trim(),
            resourceType: _resourceType,
            category: _category,
            linkUrl: _linkController.text.trim().isEmpty
                ? null
                : _linkController.text.trim(),
            locationId: resource.locationId,
            isPublished: isPublished,
          );

    Navigator.of(context).pop(
      _ResourceFormResult(
        action: action,
        data: data,
        isEditing: resource != null,
      ),
    );
  }

  String _adminLocationId() {
    final accountLocationId = appDataService.currentUserAccount.locationId;
    if (accountLocationId.trim().isNotEmpty) {
      return accountLocationId;
    }

    return appDataService.selectedStudentProfile.locationId;
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
          const SizedBox(
            width: 18,
            height: 18,
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

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 10), second]);
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
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

class _FormOption {
  const _FormOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _ResourceFormResult {
  const _ResourceFormResult({
    required this.action,
    required this.data,
    required this.isEditing,
  });

  final _ResourceSaveAction action;
  final ResourceWriteData data;
  final bool isEditing;
}

enum _BadgeTone { navy, success, warning, neutral }

extension on _ResourceFilter {
  String get label {
    return switch (this) {
      _ResourceFilter.published => 'Published',
      _ResourceFilter.draft => 'Draft',
      _ResourceFilter.archived => 'Archived',
    };
  }
}

TextStyle? _rowTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: OtaColors.ink,
    fontWeight: FontWeight.w900,
  );
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
    _BadgeTone.neutral => const _BadgeColors(
      background: Color(0xFFF2F4F7),
      border: Color(0xFFD0D5DD),
      foreground: OtaColors.ink,
    ),
  };
}

const _resourceTypeOptions = [
  _FormOption(id: 'form', label: 'Form'),
  _FormOption(id: 'curriculum', label: 'Curriculum'),
  _FormOption(id: 'testing', label: 'Testing'),
  _FormOption(id: 'registration', label: 'Registration'),
  _FormOption(id: 'document', label: 'Document'),
  _FormOption(id: 'video', label: 'Video'),
  _FormOption(id: 'externalLink', label: 'External Link'),
  _FormOption(id: 'general', label: 'General'),
];

const _categoryOptions = [
  _FormOption(id: 'registration', label: 'Registration'),
  _FormOption(id: 'curriculum', label: 'Curriculum'),
  _FormOption(id: 'testing', label: 'Testing'),
  _FormOption(id: 'forms', label: 'Forms'),
  _FormOption(id: 'events', label: 'Events'),
  _FormOption(id: 'general', label: 'General'),
];
