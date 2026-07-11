import 'package:flutter/material.dart';

import '../../theme/ota_colors.dart';

enum ResourcesPresentation { student, admin }

class ResourcesLandingView extends StatelessWidget {
  const ResourcesLandingView({
    required this.presentation,
    required this.onOpenCurriculum,
    required this.onOpenGeneralResources,
    super.key,
  });

  final ResourcesPresentation presentation;
  final VoidCallback onOpenCurriculum;
  final VoidCallback onOpenGeneralResources;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          ResourcesLandingCard(
            presentation: presentation,
            icon: Icons.menu_book_rounded,
            title: 'Curriculum',
            description: 'Review belt requirements, forms, and techniques.',
            onTap: onOpenCurriculum,
          ),
          ResourcesLandingCard(
            presentation: presentation,
            icon: Icons.folder_copy_rounded,
            title: 'General Resources',
            description: 'Open academy forms, links, and reference material.',
            onTap: onOpenGeneralResources,
          ),
        ];

        if (constraints.maxWidth < 620) {
          return Column(
            children: [cards.first, const SizedBox(height: 14), cards.last],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards.first),
            const SizedBox(width: 14),
            Expanded(child: cards.last),
          ],
        );
      },
    );
  }
}

class ResourcesLandingCard extends StatelessWidget {
  const ResourcesLandingCard({
    required this.presentation,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final ResourcesPresentation presentation;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAdmin = presentation == ResourcesPresentation.admin;
    return Material(
      color: OtaColors.white,
      elevation: isAdmin ? 1 : 3,
      shadowColor: OtaColors.navy.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isAdmin ? 6 : 20),
        side: BorderSide(
          color: isAdmin ? const Color(0xFFE1E4EA) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isAdmin ? 6 : 20),
        child: Padding(
          padding: EdgeInsets.all(isAdmin ? 16 : 20),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: OtaColors.softRed,
                  borderRadius: BorderRadius.circular(isAdmin ? 5 : 14),
                ),
                child: Icon(icon, color: OtaColors.maroon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OtaColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: OtaColors.maroon),
            ],
          ),
        ),
      ),
    );
  }
}
