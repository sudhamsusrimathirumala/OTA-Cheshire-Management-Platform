import '../models/academy_resource.dart';

List<AcademyResource> eventGeneralResourceOptions(
  Iterable<AcademyResource> resources, {
  required String locationId,
}) {
  return resources
      .where(
        (resource) =>
            resource.resourceSection == 'general' &&
            resource.locationId == locationId &&
            !resource.isArchived,
      )
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));
}

String? validatePublishedEventResource(
  AcademyResource? resource, {
  required String eventLocationId,
}) {
  if (resource == null) return null;
  if (resource.resourceSection != 'general') {
    return 'Event registration must use a General Resource.';
  }
  if (resource.locationId != eventLocationId) {
    return 'The registration resource must match the event location.';
  }
  if (resource.isArchived) {
    return 'Archived resources cannot be linked to published events.';
  }
  if (!resource.isPublished) {
    return 'Publish the selected General Resource before publishing this event.';
  }
  return null;
}
