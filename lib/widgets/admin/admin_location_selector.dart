import 'package:flutter/material.dart';

import '../../services/app_data_service_provider.dart';

String adminWriteLocationId() => adminLocationController.writeLocationId;

const _allLocationsValue = '__all_locations__';

class AdminLocationSelector extends StatelessWidget {
  const AdminLocationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: adminLocationController,
      builder: (context, _) {
        if (!adminLocationController.isSuperAdmin) {
          return const SizedBox.shrink();
        }
        final locations = adminLocationController.activeLocations;
        final selected = adminLocationController.selectedLocationId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
            key: ValueKey('admin-location-$selected-${locations.length}'),
            initialValue: locations.any((location) => location.id == selected)
                ? selected
                : _allLocationsValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academy location',
              helperText:
                  'All locations shows the overview. Select one to edit content.',
              border: OutlineInputBorder(),
            ),
            selectedItemBuilder: (context) => [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('All locations'),
              ),
              for (final location in locations)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(location.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            items: [
              const DropdownMenuItem(
                value: _allLocationsValue,
                child: Text('All locations'),
              ),
              for (final location in locations)
                DropdownMenuItem(
                  value: location.id,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.name),
                      if (location.formattedAddress.isNotEmpty)
                        Text(
                          location.formattedAddress.replaceAll('\n', ', '),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
            ],
            onChanged: (value) => adminLocationController.selectLocation(
              value == _allLocationsValue ? null : value,
            ),
          ),
        );
      },
    );
  }
}
