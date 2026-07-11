import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/academy_resource.dart';
import '../../theme/ota_colors.dart';
import 'resources_landing_view.dart';

class GeneralResourcesView extends StatelessWidget {
  const GeneralResourcesView({
    required this.resources,
    required this.presentation,
    this.onOpen,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    super.key,
  });

  final List<AcademyResource> resources;
  final ResourcesPresentation presentation;
  final ValueChanged<AcademyResource>? onOpen;
  final ValueChanged<AcademyResource>? onEdit;
  final ValueChanged<AcademyResource>? onArchive;
  final ValueChanged<AcademyResource>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < resources.length; index++) ...[
          GeneralResourceCard(
            resource: resources[index],
            presentation: presentation,
            onOpen: onOpen == null ? null : () => onOpen!(resources[index]),
            onEdit: onEdit == null ? null : () => onEdit!(resources[index]),
            onArchive: onArchive == null
                ? null
                : () => onArchive!(resources[index]),
            onDelete: onDelete == null
                ? null
                : () => onDelete!(resources[index]),
          ),
          if (index != resources.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class GeneralResourceCard extends StatelessWidget {
  const GeneralResourceCard({
    required this.resource,
    required this.presentation,
    this.onOpen,
    this.onEdit,
    this.onArchive,
    this.onDelete,
    super.key,
  });

  final AcademyResource resource;
  final ResourcesPresentation presentation;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isAdmin = presentation == ResourcesPresentation.admin;
    final borderRadius = BorderRadius.circular(isAdmin ? 6 : 20);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: borderRadius,
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(isAdmin ? 14 : 18),
          decoration: BoxDecoration(
            color: OtaColors.white,
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0xFFE1E4EA)),
            boxShadow: isAdmin
                ? null
                : [
                    BoxShadow(
                      color: OtaColors.navy.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      resource.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Edit resource',
                      icon: const Icon(Icons.edit_outlined),
                      color: OtaColors.maroon,
                    ),
                  if (isAdmin && (onArchive != null || onDelete != null))
                    PopupMenuButton<String>(
                      tooltip: 'Resource actions',
                      onSelected: (value) {
                        if (value == 'archive') onArchive?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (onArchive != null)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                  if (onOpen != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: OtaColors.maroon,
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: resource.categoryLabel),
                  _Badge(label: resource.resourceTypeLabel, accent: true),
                  if (isAdmin) _Badge(label: resource.statusLabel),
                ],
              ),
              if (resource.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  resource.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              if (resource.linkUrl != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: resource.linkUrl!),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Resource link copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? OtaColors.softRed : const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent ? OtaColors.maroon : OtaColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
