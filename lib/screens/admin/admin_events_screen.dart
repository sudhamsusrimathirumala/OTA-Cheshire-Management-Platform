import 'package:flutter/material.dart';

import '../../models/academy_event.dart';
import '../../models/academy_resource.dart';
import '../../services/app_data_service_provider.dart';
import '../../services/firebase/firebase_admin_write_service.dart';
import '../../services/event_resource_rules.dart';
import '../../services/location_time_service.dart';
import '../../theme/ota_colors.dart';
import '../../widgets/admin/admin_bottom_nav_bar.dart';
import '../../widgets/admin/admin_location_selector.dart';
import '../../widgets/location_date_time_field.dart';

enum _EventFilter { draft, published, past }

enum _EventType {
  parentNightOut('Parent Night Out'),
  tournament('Tournament'),
  summerCamp('Summer Camp'),
  beltTesting('Belt Testing'),
  seminar('Seminar'),
  specialEvent('Special Event');

  const _EventType(this.label);

  final String label;
}

String? initialEventResourceId(
  AcademyEvent? event,
  Iterable<AcademyResource> availableResources,
) {
  if (event == null) return null;
  final availableIds = availableResources
      .map((resource) => resource.id)
      .toSet();
  if (availableIds.contains(event.primaryRegistrationResourceId)) {
    return event.primaryRegistrationResourceId;
  }
  return event.linkedResourceIds.where(availableIds.contains).firstOrNull;
}

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  final _writeService = FirebaseAdminWriteService();
  var _selectedFilter = _EventFilter.published;

  List<AcademyEvent> _filteredEvents(List<AcademyEvent> events) {
    final now = DateTime.now();

    return events.where((event) {
      final selectedLocationId = adminLocationController.selectedLocationId;
      if (adminLocationController.isSuperAdmin &&
          selectedLocationId != null &&
          event.locationId != selectedLocationId) {
        return false;
      }
      if (event.eventType == 'closure') {
        return false;
      }

      if (event.isArchived) {
        return false;
      }

      return switch (_selectedFilter) {
        _EventFilter.draft => !event.isPublished,
        _EventFilter.published =>
          event.isPublished && !event.endDateTime.isBefore(now),
        _EventFilter.past => event.endDateTime.isBefore(now),
      };
    }).toList()..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appDataService, adminLocationController]),
      builder: (context, child) {
        final events = _filteredEvents(appDataService.events);

        return AdminPageShell(
          selectedDestination: AdminNavDestination.resources,
          title: 'Events',
          subtitle: 'Create and update academy events and registration links.',
          onSelectedDestinationTap: () =>
              returnToAdminResourcesLanding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: () => returnToAdminResourcesLanding(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Events & Resources'),
              ),
              const SizedBox(height: 14),
              const AdminLocationSelector(),
              _EventsToolbar(onCreateEvent: () => _openEventSheet()),
              const SizedBox(height: 14),
              _FilterRow(
                selectedFilter: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 14),
              _EventsPanel(
                events: events,
                isLoading: appDataService.isEventsLoading,
                errorMessage: appDataService.eventsErrorMessage,
                onEdit: _openEventSheet,
                onPreview: _previewEvent,
                onArchive: _confirmArchive,
                onDelete: _confirmDelete,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEventSheet([AcademyEvent? event]) async {
    final result = await showModalBottomSheet<_EventFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: OtaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) => _EventFormSheet(event: event),
    );

    if (!mounted || result == null) {
      return;
    }

    if (!useFirebase) {
      final mockMessage = switch (result.action) {
        _EventSaveAction.draft => 'Mock event draft saved.',
        _EventSaveAction.publish => 'Mock event published.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mockMessage)));
      return;
    }

    try {
      await _writeService.saveEvent(result.data);

      if (!mounted) {
        return;
      }

      final message = result.isEditing
          ? 'Event updated.'
          : switch (result.action) {
              _EventSaveAction.draft => 'Event draft saved.',
              _EventSaveAction.publish => 'Event published.',
            };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save event.')));
    }
  }

  Future<void> _previewEvent(AcademyEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OtaColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _PreviewLine(label: 'When', value: _formatEventDateTime(event)),
              _PreviewLine(label: 'Type', value: event.eventTypeLabel),
              _PreviewLine(label: 'Location', value: event.locationId),
              _PreviewLine(
                label: 'Registration',
                value: event.primaryRegistrationResourceId == null
                    ? 'No registration link'
                    : event.primaryRegistrationResourceId!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmArchive(AcademyEvent event) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archive event?'),
          content: Text('This will hide "${event.title}" from active lists.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.maroon,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Archive Event'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldArchive != true) {
      return;
    }

    if (!useFirebase) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${event.title} mock archived.')));
      return;
    }

    try {
      await _writeService.archiveEvent(event.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${event.title} archived.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to archive event.')));
    }
  }

  Future<void> _confirmDelete(AcademyEvent event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently delete event?'),
          content: Text(
            'This will permanently delete "${event.title}" from Firestore. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: OtaColors.actionRed,
                foregroundColor: OtaColors.white,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    if (!useFirebase) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${event.title} mock deleted.')));
      return;
    }

    try {
      await _writeService.deleteEvent(event.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${event.title} deleted.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to delete event.')));
    }
  }
}

class _EventsToolbar extends StatelessWidget {
  const _EventsToolbar({required this.onCreateEvent});

  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    return _AdminPanel(
      child: Row(
        children: [
          Container(width: 4, height: 34, color: OtaColors.maroon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Academy event management',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onCreateEvent,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Event'),
            style: FilledButton.styleFrom(
              backgroundColor: OtaColors.maroon,
              foregroundColor: OtaColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selectedFilter, required this.onSelected});

  final _EventFilter selectedFilter;
  final ValueChanged<_EventFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _EventFilter.values) ...[
            _FilterButton(
              label: filter.label,
              selected: filter == selectedFilter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _EventFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.events,
    required this.isLoading,
    required this.errorMessage,
    required this.onEdit,
    required this.onPreview,
    required this.onArchive,
    required this.onDelete,
  });

  final List<AcademyEvent> events;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<AcademyEvent> onEdit;
  final ValueChanged<AcademyEvent> onPreview;
  final ValueChanged<AcademyEvent> onArchive;
  final ValueChanged<AcademyEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    final groupedEvents = _groupEventsByMonth(events);

    return _AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.event_outlined,
            title: 'Events',
            detail: '${events.length} shown',
          ),
          if (isLoading)
            const _LoadingState(message: 'Loading events...')
          else if (errorMessage != null)
            _EmptyState(message: errorMessage!)
          else if (events.isEmpty)
            const _EmptyState(message: 'No events found.')
          else
            for (final group in groupedEvents.entries) ...[
              _EventGroupHeader(label: group.key),
              for (final event in group.value) ...[
                _EventRow(
                  event: event,
                  onEdit: () => onEdit(event),
                  onPreview: () => onPreview(event),
                  onArchive: () => onArchive(event),
                  onDelete: () => onDelete(event),
                ),
                if (event != group.value.last)
                  const Divider(height: 1, color: Color(0xFFE1E4EA)),
              ],
            ],
        ],
      ),
    );
  }
}

class _EventGroupHeader extends StatelessWidget {
  const _EventGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: const Color(0xFFF8FAFC),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: OtaColors.navy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.onEdit,
    required this.onPreview,
    required this.onArchive,
    required this.onDelete,
  });

  final AcademyEvent event;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 860;
          final badges = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Badge(label: event.eventTypeLabel, tone: _BadgeTone.navy),
              _Badge(
                label: event.isPublished ? 'Published' : 'Draft',
                tone: event.isPublished
                    ? _BadgeTone.success
                    : _BadgeTone.warning,
              ),
              _Badge(
                label: event.registrationLabel,
                tone: event.primaryRegistrationResourceId == null
                    ? _BadgeTone.neutral
                    : _BadgeTone.important,
              ),
              if (event.primaryRegistrationResourceId != null)
                const _Badge(label: 'Link', tone: _BadgeTone.success),
            ],
          );
          final actions = Wrap(
            children: [
              _ActionLink(label: 'Edit', onPressed: onEdit),
              _ActionLink(label: 'Preview', onPressed: onPreview),
              _ActionLink(
                label: 'Archive',
                onPressed: onArchive,
                isDanger: true,
              ),
              _ActionLink(label: 'Delete', onPressed: onDelete, isDanger: true),
            ],
          );

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _rowTitleStyle(context),
              ),
              const SizedBox(height: 4),
              Text(
                event.description,
                maxLines: isNarrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OtaColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateBadge(date: _eventLocalStart(event)),
                const SizedBox(height: 8),
                titleBlock,
                const SizedBox(height: 8),
                Text(_formatEventDateTime(event), style: _metaStyle(context)),
                const SizedBox(height: 8),
                badges,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            children: [
              _DateBadge(date: _eventLocalStart(event)),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: titleBlock),
              SizedBox(
                width: 148,
                child: Text(
                  _formatEventDateTime(event),
                  style: _metaStyle(context),
                ),
              ),
              Expanded(flex: 4, child: badges),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  const _EventFormSheet({this.event});

  final AcademyEvent? event;

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: OtaColors.softRed,
        border: Border.all(color: const Color(0xFFE7C8CE)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            _monthNames[date.month - 1].toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OtaColors.maroon,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            date.day.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late _EventType _eventType;
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  DateTime? _registrationDeadline;
  String? _primaryRegistrationResourceId;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _startDateTime = event?.startDateTime;
    _endDateTime = event?.endDateTime;
    _registrationDeadline = event?.registrationDeadline;
    _notesController = TextEditingController();
    _eventType = _eventTypeForId(event?.eventType);
    _primaryRegistrationResourceId = initialEventResourceId(
      event,
      _resourceOptions(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final isEditingPublished = isEditing && widget.event!.isPublished;
    final publishButtonLabel = isEditing && widget.event!.isPublished
        ? 'Update Published Event'
        : 'Publish Event';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: isEditing ? 'Edit Event' : 'Create Event',
              subtitle: 'Drafts and published events write to Firestore.',
            ),
            const SizedBox(height: 14),
            _AdminTextField(controller: _titleController, label: 'Title'),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: _descriptionController,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_EventType>(
              initialValue: _eventType,
              decoration: _fieldDecoration('Event type'),
              items: [
                for (final type in _EventType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _eventType = value);
                }
              },
            ),
            const SizedBox(height: 10),
            _TwoColumnFields(
              first: LocationDateTimeField(
                label: 'Start date and time',
                locationId: _adminLocationId(),
                value: _startDateTime,
                onChanged: (value) => setState(() => _startDateTime = value),
              ),
              second: LocationDateTimeField(
                label: 'End date and time',
                locationId: _adminLocationId(),
                value: _endDateTime,
                onChanged: (value) => setState(() => _endDateTime = value),
              ),
            ),
            const SizedBox(height: 10),
            LocationDateTimeField(
              label: 'Registration deadline',
              locationId: _adminLocationId(),
              value: _registrationDeadline,
              optional: true,
              onChanged: (value) =>
                  setState(() => _registrationDeadline = value),
            ),
            const SizedBox(height: 10),
            _buildResourceLinkingSection(),
            const SizedBox(height: 10),
            _AdminTextField(
              controller: _notesController,
              label: 'Optional notes',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            if (_validationMessage != null) ...[
              _ValidationMessage(message: _validationMessage!),
              const SizedBox(height: 10),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                if (!isEditingPublished)
                  OutlinedButton(
                    onPressed: () => _submit(_EventSaveAction.draft),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OtaColors.maroon,
                      side: const BorderSide(color: OtaColors.maroon),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Save Draft'),
                  ),
                FilledButton(
                  onPressed: () => _submit(_EventSaveAction.publish),
                  style: FilledButton.styleFrom(
                    backgroundColor: OtaColors.maroon,
                    foregroundColor: OtaColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(publishButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit(_EventSaveAction action) {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final locationId = _adminLocationId();
    final startDateTime = _startDateTime;
    final endDateTime = _endDateTime;
    final registrationDeadline = _registrationDeadline;

    if (title.isEmpty) {
      setState(() => _validationMessage = 'Title is required.');
      return;
    }

    if (description.isEmpty) {
      setState(() => _validationMessage = 'Description is required.');
      return;
    }

    if (startDateTime == null) {
      setState(() => _validationMessage = 'Start date/time is required.');
      return;
    }

    if (endDateTime == null) {
      setState(() => _validationMessage = 'End date/time is invalid.');
      return;
    }

    if (!endDateTime.isAfter(startDateTime)) {
      setState(
        () => _validationMessage = 'End date/time must be after start time.',
      );
      return;
    }

    final selectedResource = _primaryRegistrationResourceId == null
        ? null
        : appDataService.resources
              .where(
                (resource) => resource.id == _primaryRegistrationResourceId,
              )
              .firstOrNull;
    if (action == _EventSaveAction.publish &&
        validatePublishedEventResource(
              selectedResource,
              eventLocationId: locationId,
            ) !=
            null) {
      setState(
        () => _validationMessage = validatePublishedEventResource(
          selectedResource,
          eventLocationId: locationId,
        ),
      );
      return;
    }

    final event = widget.event;
    final isPublished = action == _EventSaveAction.publish;
    final data = event == null
        ? EventWriteData(
            title: title,
            description: description,
            locationId: locationId,
            eventType: _eventType.id,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            registrationDeadline: registrationDeadline,
            linkedResourceIds: _primaryRegistrationResourceId == null
                ? const <String>[]
                : <String>[_primaryRegistrationResourceId!],
            primaryRegistrationResourceId: _primaryRegistrationResourceId,
            isPublished: isPublished,
          )
        : EventWriteData.fromEvent(
            event,
            title: title,
            description: description,
            locationId: locationId,
            eventType: _eventType.id,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            registrationDeadline: registrationDeadline,
            linkedResourceIds: _primaryRegistrationResourceId == null
                ? const <String>[]
                : <String>[_primaryRegistrationResourceId!],
            primaryRegistrationResourceId: _primaryRegistrationResourceId,
            isPublished: isPublished,
          );

    Navigator.of(context).pop(
      _EventFormResult(action: action, data: data, isEditing: event != null),
    );
  }

  String _adminLocationId() {
    return adminWriteLocationId();
  }

  Widget _buildResourceLinkingSection() {
    final resources = _resourceOptions();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFD0D5DD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Resource',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OtaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_primaryRegistrationResourceId),
            initialValue:
                resources.any(
                  (resource) => resource.id == _primaryRegistrationResourceId,
                )
                ? _primaryRegistrationResourceId
                : null,
            decoration: _fieldDecoration('Primary linked resource'),
            hint: const Text('No linked resource'),
            items: [
              for (final resource in resources)
                DropdownMenuItem(
                  value: resource.id,
                  child: Text(
                    resource.isPublished
                        ? resource.title
                        : '${resource.title} (Draft)',
                  ),
                ),
            ],
            onChanged: (resourceId) {
              setState(() {
                _primaryRegistrationResourceId = resourceId;
              });
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Linking a General Resource is optional. If selected, published events can only link to a published General Resource.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_primaryRegistrationResourceId != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => _primaryRegistrationResourceId = null);
              },
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Remove linked resource'),
            ),
          ],
        ],
      ),
    );
  }

  List<AcademyResource> _resourceOptions() {
    return eventGeneralResourceOptions(
      appDataService.resources,
      locationId: _adminLocationId(),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? OtaColors.white : OtaColors.ink,
        backgroundColor: selected ? OtaColors.navy : OtaColors.white,
        side: BorderSide(
          color: selected ? OtaColors.navy : const Color(0xFFD0D5DD),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        border: Border.all(color: const Color(0xFFE9D2D7)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x168B1E2D),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [OtaColors.navy, OtaColors.maroon],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: OtaColors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: OtaColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            detail,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: OtaColors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _badgeColors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: isDanger ? OtaColors.actionRed : OtaColors.maroon,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: OtaColors.mutedText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OtaColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        border: Border.all(color: const Color(0xFFF0A0AA)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: OtaColors.actionRed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: OtaColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OtaColors.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _fieldDecoration(label),
    );
  }
}

class _TwoColumnFields extends StatelessWidget {
  const _TwoColumnFields({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 10), second]);
        }

        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OtaColors.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

enum _BadgeTone { navy, success, warning, important, neutral }

enum _EventSaveAction { draft, publish }

class _EventFormResult {
  const _EventFormResult({
    required this.action,
    required this.data,
    required this.isEditing,
  });

  final _EventSaveAction action;
  final EventWriteData data;
  final bool isEditing;
}

extension on _EventFilter {
  String get label {
    return switch (this) {
      _EventFilter.draft => 'Draft',
      _EventFilter.published => 'Published',
      _EventFilter.past => 'Past',
    };
  }
}

extension on _EventType {
  String get id {
    return switch (this) {
      _EventType.parentNightOut => 'parentNightOut',
      _EventType.tournament => 'tournament',
      _EventType.summerCamp => 'summerCamp',
      _EventType.beltTesting => 'beltTesting',
      _EventType.seminar => 'seminar',
      _EventType.specialEvent => 'specialEvent',
    };
  }
}

_EventType _eventTypeForId(String? eventType) {
  final normalizedEventType = switch (eventType) {
    'parent-night-out' => 'parentNightOut',
    'summer-camp' => 'summerCamp',
    'belt-testing' => 'beltTesting',
    _ => eventType,
  };

  return _EventType.values.firstWhere(
    (type) => type.id == normalizedEventType,
    orElse: () => _EventType.specialEvent,
  );
}

Map<String, List<AcademyEvent>> _groupEventsByMonth(List<AcademyEvent> events) {
  final groupedEvents = <String, List<AcademyEvent>>{};

  for (final event in events) {
    final localStart = _eventLocalStart(event);
    final key =
        '${_fullMonthNames[localStart.month - 1]} '
        '${localStart.year}';
    groupedEvents.putIfAbsent(key, () => <AcademyEvent>[]).add(event);
  }

  return groupedEvents;
}

_BadgeColors _badgeColors(_BadgeTone tone) {
  return switch (tone) {
    _BadgeTone.navy => const _BadgeColors(
      background: Color(0xFFEFF2F7),
      border: Color(0xFFC9D1E4),
      foreground: OtaColors.navy,
    ),
    _BadgeTone.success => const _BadgeColors(
      background: Color(0xFFEAF7EF),
      border: Color(0xFFB9DEC6),
      foreground: Color(0xFF23633B),
    ),
    _BadgeTone.warning => const _BadgeColors(
      background: Color(0xFFFFF3CD),
      border: Color(0xFFE9D28E),
      foreground: Color(0xFF7A5200),
    ),
    _BadgeTone.important => const _BadgeColors(
      background: OtaColors.softRed,
      border: Color(0xFFE7C8CE),
      foreground: OtaColors.maroon,
    ),
    _BadgeTone.neutral => const _BadgeColors(
      background: Color(0xFFF2F4F7),
      border: Color(0xFFD0D5DD),
      foreground: OtaColors.ink,
    ),
  };
}

InputDecoration _fieldDecoration(String label, {String? helperText}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: Color(0xFFD0D5DD)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: OtaColors.maroon, width: 1.4),
    ),
  );
}

TextStyle? _rowTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: OtaColors.ink,
    fontWeight: FontWeight.w900,
  );
}

TextStyle? _metaStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium?.copyWith(
    color: OtaColors.mutedText,
    fontWeight: FontWeight.w700,
  );
}

String _formatDateTime(DateTime dateTime) {
  final month = _monthNames[dateTime.month - 1];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$month ${dateTime.day}, $hour:$minute $period';
}

DateTime _eventLocalStart(AcademyEvent event) => const LocationTimeService()
    .toLocationTime(event.startDateTime, event.locationId);

String _formatEventDateTime(AcademyEvent event) {
  final service = const LocationTimeService();
  final start = service.toLocationTime(event.startDateTime, event.locationId);
  final end = service.toLocationTime(event.endDateTime, event.locationId);
  return '${_formatDateTime(start)} - ${_formatClockTime(end)} ${end.timeZoneName}';
}

String _formatClockTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _fullMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
