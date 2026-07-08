import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/academy_resource.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appDataService,
      builder: (context, child) {
        final locationId = appDataService.selectedStudentProfile.locationId;
        final resources =
            appDataService.resources
                .where(
                  (resource) =>
                      resource.locationId == locationId &&
                      resource.isPublished &&
                      !resource.isArchived,
                )
                .toList()
              ..sort((a, b) {
                final category = a.categoryLabel.compareTo(b.categoryLabel);
                if (category != 0) {
                  return category;
                }
                return a.title.compareTo(b.title);
              });
        final groupedResources = _groupResourcesByCategory(resources);

        return Scaffold(
          backgroundColor: OtaColors.blush,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _ResourcesHeader(),
                            const SizedBox(height: 16),
                            if (appDataService.isResourcesLoading)
                              const _StatusCard(
                                icon: Icons.sync_rounded,
                                title: 'Loading resources',
                                detail: 'Checking the latest academy links.',
                                showProgress: true,
                              )
                            else if (appDataService.resourcesErrorMessage !=
                                null)
                              _StatusCard(
                                icon: Icons.cloud_off_rounded,
                                title: 'Resources unavailable',
                                detail: appDataService.resourcesErrorMessage!,
                              )
                            else if (resources.isEmpty)
                              const _StatusCard(
                                icon: Icons.folder_off_rounded,
                                title: 'No resources right now',
                                detail:
                                    'Published academy resources will appear here.',
                              )
                            else
                              for (final group in groupedResources.entries) ...[
                                _ResourceGroupHeader(label: group.key),
                                const SizedBox(height: 8),
                                for (final resource in group.value) ...[
                                  _ResourceCard(resource: resource),
                                  if (resource != group.value.last)
                                    const SizedBox(height: 12),
                                ],
                                if (group.key != groupedResources.keys.last)
                                  const SizedBox(height: 16),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const OtaBottomNavBar(
            selectedDestination: OtaBottomNavDestination.resources,
          ),
        );
      },
    );
  }
}

class _ResourcesHeader extends StatelessWidget {
  const _ResourcesHeader();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: OtaColors.softRed,
              foregroundColor: OtaColors.maroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resources',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Academy forms, curriculum links, testing information, and registration links.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtaColors.mutedText,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
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

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource});

  final AcademyResource resource;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(label: resource.categoryLabel),
              _Badge(label: resource.resourceTypeLabel, isAccent: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resource.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (resource.description.isNotEmpty) ...[
            const SizedBox(height: 8),
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
            _CopyableLink(url: resource.linkUrl!),
          ],
        ],
      ),
    );
  }
}

class _CopyableLink extends StatelessWidget {
  const _CopyableLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OtaColors.softRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: OtaColors.maroon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              url,
              maxLines: 2,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OtaColors.maroon,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resource link copied.')),
              );
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

class _ResourceGroupHeader extends StatelessWidget {
  const _ResourceGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: OtaColors.ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress)
            const CircularProgressIndicator()
          else
            Icon(icon, color: OtaColors.maroon, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(24),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.isAccent = false});

  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent ? OtaColors.softRed : const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isAccent ? OtaColors.maroon : OtaColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Map<String, List<AcademyResource>> _groupResourcesByCategory(
  List<AcademyResource> resources,
) {
  final groupedResources = <String, List<AcademyResource>>{};

  for (final resource in resources) {
    groupedResources
        .putIfAbsent(resource.categoryLabel, () => <AcademyResource>[])
        .add(resource);
  }

  return groupedResources;
}
