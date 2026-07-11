import 'package:flutter/material.dart';

import '../services/location_time_service.dart';

class LocationDateTimeField extends StatelessWidget {
  const LocationDateTimeField({
    required this.label,
    required this.locationId,
    required this.value,
    required this.onChanged,
    this.optional = false,
    super.key,
  });

  final String label;
  final String locationId;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    const timeService = LocationTimeService();
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: optional ? 'Optional' : null,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (optional && value != null)
                IconButton(
                  onPressed: () => onChanged(null),
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.clear_rounded),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.event_rounded),
              ),
            ],
          ),
        ),
        child: Text(
          value == null
              ? 'Select date and time'
              : timeService.formatDateTime(value!, locationId),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    const timeService = LocationTimeService();
    final current = value == null
        ? timeService.toLocationTime(DateTime.now(), locationId)
        : timeService.toLocationTime(value!, locationId);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
    );
    if (selectedDate == null || !context.mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (selectedTime == null) return;

    onChanged(
      timeService.combineDateAndTime(
        locationId: locationId,
        date: selectedDate,
        time: selectedTime,
      ),
    );
  }
}
