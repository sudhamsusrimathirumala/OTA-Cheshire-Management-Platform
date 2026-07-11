import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';
import '../widgets/resources/general_resources_view.dart';
import '../widgets/resources/resources_landing_view.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StudentResourcesShell(
      title: 'Resources',
      subtitle: 'Choose curriculum or academy forms and links.',
      child: ResourcesLandingView(
        presentation: ResourcesPresentation.student,
        onOpenCurriculum: () =>
            Navigator.pushNamed(context, OtaRoutes.curriculum),
        onOpenGeneralResources: () =>
            Navigator.pushNamed(context, OtaRoutes.generalResources),
      ),
    );
  }
}

class GeneralResourcesScreen extends StatelessWidget {
  const GeneralResourcesScreen({super.key});

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
                      resource.resourceSection == 'general' &&
                      resource.locationId == locationId &&
                      resource.isPublished &&
                      !resource.isArchived,
                )
                .toList()
              ..sort((a, b) => a.title.compareTo(b.title));

        Widget content;
        if (appDataService.isResourcesLoading) {
          content = const Center(child: CircularProgressIndicator());
        } else if (appDataService.resourcesErrorMessage != null) {
          content = Text(appDataService.resourcesErrorMessage!);
        } else if (resources.isEmpty) {
          content = const Text('No general resources right now.');
        } else {
          content = GeneralResourcesView(
            resources: resources,
            presentation: ResourcesPresentation.student,
          );
        }

        return _StudentResourcesShell(
          title: 'General Resources',
          subtitle: 'Academy forms, links, and reference material.',
          child: content,
        );
      },
    );
  }
}

class _StudentResourcesShell extends StatelessWidget {
  const _StudentResourcesShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OtaColors.blush,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: OtaColors.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: OtaColors.mutedText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const OtaBottomNavBar(
        selectedDestination: OtaBottomNavDestination.resources,
      ),
    );
  }
}
