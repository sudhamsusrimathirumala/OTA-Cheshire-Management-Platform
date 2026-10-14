import 'package:flutter/material.dart';
import '../../models/academy_event.dart';
import '../../models/event_schedule.dart';
import '../../services/location_time_service.dart';
import '../../services/event_occurrence_changes.dart';
import '../location_date_time_field.dart';

Future<EventSchedule?> editEventOccurrences(
  BuildContext context,
  AcademyEvent event,
) async {
  final schedule = event.schedule;
  if (schedule == null) return null;
  var occurrences = List<EventOccurrence>.of(schedule.occurrences);
  return showDialog<EventSchedule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Series sessions'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit the entire series from the event editor. Completed sessions are kept as history.',
                ),
                for (final o in occurrences)
                  ListTile(
                    dense: true,
                    title: Text(
                      const LocationTimeService().formatDateTime(
                        o.start,
                        event.locationId,
                      ),
                    ),
                    subtitle: Text(
                      '${const LocationTimeService().formatDateTime(o.end, event.locationId)}${o.canceled ? ' • Canceled' : ''}',
                    ),
                    trailing: !o.start.isAfter(DateTime.now())
                        ? const Text('History')
                        : IconButton(
                            tooltip: 'Edit session',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final changed = await _editOccurrence(
                                context,
                                event,
                                occurrences,
                                o,
                              );
                              if (changed != null) {
                                setDialogState(() => occurrences = changed);
                              }
                            },
                          ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              schedule.replaceOccurrences(occurrences),
            ),
            child: const Text('Save sessions'),
          ),
        ],
      ),
    ),
  );
}

Future<List<EventOccurrence>?> _editOccurrence(
  BuildContext context,
  AcademyEvent event,
  List<EventOccurrence> occurrences,
  EventOccurrence selected,
) async {
  var start = selected.start;
  var end = selected.end;
  var future = false;
  String? error;
  return showDialog<List<EventOccurrence>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void apply(bool cancel) {
          try {
            final changed = changeEventOccurrences(
              occurrences,
              selected.id,
              start: start,
              end: end,
              following: future,
              cancel: cancel,
              locationId: event.locationId,
            );
            Navigator.pop(context, changed);
          } catch (e) {
            setDialogState(
              () => error = e is ArgumentError
                  ? '${e.message}'
                  : 'Unable to change sessions.',
            );
          }
        }

        return AlertDialog(
          title: const Text('Edit session'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This and following occurrences'),
                    subtitle: const Text('Off: this occurrence only'),
                    value: future,
                    onChanged: (v) => setDialogState(() => future = v),
                  ),
                  LocationDateTimeField(
                    label: 'Session start',
                    locationId: event.locationId,
                    value: start,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => start = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  LocationDateTimeField(
                    label: 'Session end',
                    locationId: event.locationId,
                    value: end,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => end = v);
                    },
                  ),
                  if (error != null) Text(error!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cancel sessions?'),
                    content: Text(
                      future
                          ? 'Cancel this and all future sessions? Pending reminders will be canceled.'
                          : 'Cancel this session? Pending reminders will be canceled.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep sessions'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Confirm cancellation'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) apply(true);
              },
              child: const Text('Cancel sessions'),
            ),
            FilledButton(
              onPressed: () => apply(false),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}
