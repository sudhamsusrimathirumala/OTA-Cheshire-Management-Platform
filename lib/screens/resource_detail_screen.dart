import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_resource.dart';
import '../theme/ota_colors.dart';

class ResourceDetailScreen extends StatelessWidget {
  const ResourceDetailScreen({
    required this.resource,
    this.showAdminStatus = false,
    super.key,
  });

  final AcademyResource resource;
  final bool showAdminStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.blush,
      appBar: AppBar(
        backgroundColor: OtaColors.blush,
        foregroundColor: OtaColors.ink,
        elevation: 0,
        title: const Text('Resource Detail'),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ResourceHeroCard(
                          resource: resource,
                          showAdminStatus: showAdminStatus,
                        ),
                        const SizedBox(height: 16),
                        _ResourceContentCard(resource: resource),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceHeroCard extends StatelessWidget {
  const _ResourceHeroCard({
    required this.resource,
    required this.showAdminStatus,
  });

  final AcademyResource resource;
  final bool showAdminStatus;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: OtaColors.navy,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _resourceIcon(resource.resourceType),
              color: OtaColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailBadge(label: resource.categoryLabel),
                    _DetailBadge(
                      label: resource.resourceTypeLabel,
                      accent: true,
                    ),
                    if (showAdminStatus)
                      _DetailBadge(label: resource.statusLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  resource.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.14,
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

class _ResourceContentCard extends StatelessWidget {
  const _ResourceContentCard({required this.resource});

  final AcademyResource resource;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this resource',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            resource.description.isEmpty
                ? 'No description is available.'
                : resource.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w600,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 20),
          if (resource.linkUrl == null)
            Text(
              'No link is available for this resource.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            _ResourceLink(url: resource.linkUrl!),
        ],
      ),
    );
  }
}

class _ResourceLink extends StatelessWidget {
  const _ResourceLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OtaColors.softRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: OtaColors.maroon),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              url,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.maroon,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resource link copied.')),
                );
              }
            },
            tooltip: 'Copy link',
            icon: const Icon(Icons.copy_rounded),
            color: OtaColors.maroon,
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent ? OtaColors.maroon : OtaColors.softRed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent ? OtaColors.white : OtaColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

IconData _resourceIcon(String resourceType) {
  return switch (resourceType) {
    'form' => Icons.description_outlined,
    'registration' => Icons.how_to_reg_outlined,
    'video' => Icons.play_circle_outline_rounded,
    'externalLink' || 'external-link' => Icons.open_in_new_rounded,
    _ => Icons.folder_copy_outlined,
  };
}
