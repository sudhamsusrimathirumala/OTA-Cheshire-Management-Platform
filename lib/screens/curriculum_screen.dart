import 'package:flutter/material.dart';

import '../models/curriculum_requirement.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({super.key});

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  String _selectedBelt = 'White';

  CurriculumRequirement get _selectedCurriculum =>
      appDataService.curriculumForBelt(_selectedBelt);

  @override
  Widget build(BuildContext context) {
    final curriculum = _selectedCurriculum;

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
                        _CurriculumHeader(
                          selectedBelt: _selectedBelt,
                          onBeltChanged: (belt) {
                            if (belt == null) {
                              return;
                            }

                            setState(() => _selectedBelt = belt);
                          },
                        ),
                        const SizedBox(height: 18),
                        CurriculumSectionCard(
                          title: 'Forms',
                          icon: Icons.sports_martial_arts_rounded,
                          description:
                              'Review forms, stance transitions, and practice sequences for ${appDataService.beltDisplayLabel(curriculum.belt)}.',
                          items: curriculum.formItems,
                          showVideoPlaceholder: true,
                        ),
                        const SizedBox(height: 14),
                        CurriculumSectionCard(
                          title: 'One-Step Sparring',
                          icon: Icons.people_alt_rounded,
                          description:
                              'Practice timing, distance, and controlled partner responses.',
                          items: curriculum.oneStepItems,
                        ),
                        const SizedBox(height: 14),
                        CurriculumSectionCard(
                          title: 'Wood-Breaking Technique',
                          icon: Icons.fitness_center_rounded,
                          description:
                              'Prepare safe, powerful board-breaking technique with proper chamber and focus.',
                          items: curriculum.breakingItems,
                        ),
                        const SizedBox(height: 14),
                        CurriculumSectionCard(
                          title: 'Physical Challenge',
                          icon: Icons.directions_run_rounded,
                          description:
                              'Build the strength and endurance expected for promotion readiness.',
                          items: curriculum.physicalChallengeItems,
                          emptyMessage:
                              'No physical challenge required for this belt.',
                        ),
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
  }
}

class _CurriculumHeader extends StatelessWidget {
  const _CurriculumHeader({
    required this.selectedBelt,
    required this.onBeltChanged,
  });

  final String selectedBelt;
  final ValueChanged<String?> onBeltChanged;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: OtaColors.softRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: OtaColors.maroon,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curriculum',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: OtaColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review belt requirements and training material',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OtaColors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: selectedBelt,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: InputDecoration(
              labelText: 'Select Belt Level',
              prefixIcon: const Icon(Icons.workspace_premium_rounded),
              filled: true,
              fillColor: OtaColors.blush,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: OtaColors.navy.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: OtaColors.maroon,
                  width: 1.5,
                ),
              ),
            ),
            items: [
              for (final belt in appDataService.curriculumBeltOrder)
                DropdownMenuItem(
                  value: belt,
                  child: Text(appDataService.beltDisplayLabel(belt)),
                ),
            ],
            onChanged: onBeltChanged,
          ),
        ],
      ),
    );
  }
}

class CurriculumSectionCard extends StatelessWidget {
  const CurriculumSectionCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.items,
    this.emptyMessage,
    this.showVideoPlaceholder = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> items;
  final String? emptyMessage;
  final bool showVideoPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OtaColors.softRed,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: OtaColors.maroon, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (showVideoPlaceholder) ...[
            const SizedBox(height: 16),
            const _VideoPlaceholderCard(),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            _RequirementRow(text: emptyMessage ?? 'No requirements listed.')
          else
            for (final item in items) ...[
              _RequirementRow(text: item),
              if (item != items.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _VideoPlaceholderCard extends StatelessWidget {
  const _VideoPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OtaColors.navy, OtaColors.maroon],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Icon(
              Icons.sports_martial_arts_rounded,
              size: 118,
              color: OtaColors.white.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: OtaColors.white.withValues(alpha: 0.96),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: OtaColors.maroon,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Form video placeholder',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OtaColors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instructional video will be added later',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OtaColors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
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

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: OtaColors.actionRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
        ),
      ],
    );
  }
}
