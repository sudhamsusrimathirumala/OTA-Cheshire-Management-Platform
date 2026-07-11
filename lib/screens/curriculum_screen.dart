import 'package:flutter/material.dart';

import '../models/curriculum_requirement.dart';
import '../services/app_data_service_provider.dart';
import '../theme/ota_colors.dart';
import '../widgets/admin/admin_bottom_nav_bar.dart';
import '../widgets/ota_bottom_nav_bar.dart';

class CurriculumScreen extends StatefulWidget {
  const CurriculumScreen({this.isAdmin = false, super.key});

  final bool isAdmin;

  @override
  State<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends State<CurriculumScreen> {
  String _selectedBelt = 'White';

  @override
  Widget build(BuildContext context) {
    final curriculum = appDataService.curriculumForBelt(_selectedBelt);
    final content = _CurriculumContent(
      curriculum: curriculum,
      selectedBelt: _selectedBelt,
      onBeltChanged: (belt) {
        if (belt != null) setState(() => _selectedBelt = belt);
      },
    );

    if (widget.isAdmin) {
      return AdminPageShell(
        selectedDestination: AdminNavDestination.resources,
        title: 'Curriculum',
        subtitle: 'Read-only curriculum content used by students and families.',
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: OtaColors.blush,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: content,
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

class _CurriculumContent extends StatelessWidget {
  const _CurriculumContent({
    required this.curriculum,
    required this.selectedBelt,
    required this.onBeltChanged,
  });

  final CurriculumRequirement curriculum;
  final String selectedBelt;
  final ValueChanged<String?> onBeltChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurriculumHeader(
          selectedBelt: selectedBelt,
          onBeltChanged: onBeltChanged,
        ),
        const SizedBox(height: 18),
        for (final section in curriculum.sortedSections) ...[
          CurriculumSectionCard(section: section),
          if (section != curriculum.sortedSections.last)
            const SizedBox(height: 14),
        ],
      ],
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
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curriculum',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review belt requirements and training material.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedBelt,
            decoration: const InputDecoration(
              labelText: 'Select Belt Level',
              border: OutlineInputBorder(),
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
  const CurriculumSectionCard({required this.section, super.key});

  final CurriculumSection section;

  @override
  Widget build(BuildContext context) {
    final items = section.sortedItems;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('No requirements listed.')
          else
            for (var index = 0; index < items.length; index++) ...[
              _CurriculumItemView(item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CurriculumItemView extends StatelessWidget {
  const _CurriculumItemView({required this.item});

  final CurriculumItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.contentType == CurriculumContentType.video
            ? OtaColors.softRed
            : const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.contentType == CurriculumContentType.video
                ? Icons.play_circle_outline_rounded
                : Icons.notes_rounded,
            color: OtaColors.maroon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: OtaColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.textContent != null && item.textContent != item.title)
                  Text(item.textContent!),
                if (item.videoUrl != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    item.videoUrl!,
                    style: const TextStyle(color: OtaColors.maroon),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OtaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E4EA)),
        boxShadow: [
          BoxShadow(
            color: OtaColors.navy.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
