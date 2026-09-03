import 'package:flutter/material.dart';

import '../../data/belt_ranks.dart';
import '../../theme/ota_colors.dart';

class BeltMultiSelectDropdown extends StatelessWidget {
  const BeltMultiSelectDropdown({
    required this.selectedBelts,
    required this.onChanged,
    this.label = 'Belts',
    this.helperText,
    this.emptyText = 'Select belt ranks',
    super.key,
  });

  final Set<String> selectedBelts;
  final ValueChanged<Set<String>> onChanged;
  final String label;
  final String? helperText;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final selected = orderedBeltRanks(selectedBelts);
    return InkWell(
      key: ValueKey('belt-multi-select-$label'),
      onTap: () => _openSelector(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: selected.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: Color(0xFFD0D5DD)),
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          selected.isEmpty ? emptyText : selected.join(', '),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected.isEmpty ? OtaColors.mutedText : OtaColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final options = orderedBeltRanks({
      ...curriculumBeltOrder,
      ...selectedBelts,
    });
    final draft = <String>{...selectedBelts};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select $label',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(
                            () => draft.addAll(curriculumBeltOrder),
                          ),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => setModalState(draft.clear),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final belt in options)
                          CheckboxListTile(
                            key: ValueKey('belt-option-$belt'),
                            value: draft.contains(belt),
                            title: Text(belt),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: OtaColors.maroon,
                            onChanged: (selected) {
                              setModalState(() {
                                if (selected ?? false) {
                                  draft.add(belt);
                                } else {
                                  draft.remove(belt);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(draft),
                          style: FilledButton.styleFrom(
                            backgroundColor: OtaColors.maroon,
                            foregroundColor: OtaColors.white,
                          ),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      onChanged(result);
    }
  }
}

List<String> orderedBeltRanks(Iterable<String> belts) {
  final remaining = belts
      .map((belt) => belt.trim())
      .where((belt) => belt.isNotEmpty)
      .toSet();
  final ordered = [
    for (final belt in curriculumBeltOrder)
      if (remaining.remove(belt)) belt,
  ];
  final legacy = remaining.toList()..sort();
  return [...ordered, ...legacy];
}
