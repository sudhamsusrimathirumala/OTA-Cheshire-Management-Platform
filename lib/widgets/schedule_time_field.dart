import 'package:flutter/material.dart';

import '../models/class_session.dart';

class ScheduleTimeField extends StatelessWidget {
  const ScheduleTimeField({
    required this.label,
    required this.minutes,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int? minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(
          minutes == null ? 'Select time' : formatMinutesAsTime(minutes!),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final current = minutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected != null) {
      onChanged(minutesForTimeOfDay(selected));
    }
  }
}

int minutesForTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;
