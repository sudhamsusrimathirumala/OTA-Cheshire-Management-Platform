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

String? validatePublishedEventResource(AcademyResource? resource) {
  if (resource == null) return null;
  if (resource.isArchived) {
    return 'Archived resources cannot be linked to published events.';
  }
  if (!resource.isPublished) {
    return 'Publish the selected General Resource before publishing this event.';
  }
  return null;
}
