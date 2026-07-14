import 'package:flutter/material.dart';

import '../../models/user_account.dart';
import '../../services/app_data_service_provider.dart';

final ValueNotifier<String?> superAdminLocationSelection = ValueNotifier(null);

String adminWriteLocationId() {
  final account = appDataService.currentUserAccount;
  if (account.role != UserAccountRole.superAdmin) return account.locationId;
  return superAdminLocationSelection.value ?? '';
}

class AdminLocationSelector extends StatelessWidget {
  const AdminLocationSelector({required this.locationIds, super.key});

  final Iterable<String> locationIds;

  @override
  Widget build(BuildContext context) {
    if (appDataService.currentUserAccount.role != UserAccountRole.superAdmin) {
      return const SizedBox.shrink();
    }
    final options = locationIds.where((id) => id.trim().isNotEmpty).toSet()
      ..addAll(
        superAdminLocationSelection.value == null
            ? const <String>[]
            : <String>[superAdminLocationSelection.value!],
      );
    final sorted = options.toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ValueListenableBuilder<String?>(
        valueListenable: superAdminLocationSelection,
        builder: (context, selected, _) => DropdownButtonFormField<String>(
          initialValue: sorted.contains(selected) ? selected : null,
          decoration: const InputDecoration(
            labelText: 'Academy location for edits',
            helperText:
                'Choose a location before creating or changing academy content.',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final locationId in sorted)
              DropdownMenuItem(value: locationId, child: Text(locationId)),
          ],
          onChanged: sorted.isEmpty
              ? null
              : (value) => superAdminLocationSelection.value = value,
        ),
      ),
    );
  }
}
