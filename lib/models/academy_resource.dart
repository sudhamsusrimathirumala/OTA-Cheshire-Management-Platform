class AcademyResource {
  const AcademyResource({
    required this.id,
    required this.title,
    required this.description,
    this.resourceSection = 'general',
    required this.resourceType,
    required this.category,
    required this.locationId,
    required this.createdAt,
    required this.updatedAt,
    this.linkUrl,
    this.isPublished = false,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String description;
  final String resourceSection;
  final String resourceType;
  final String category;
  final String? linkUrl;
  final String locationId;
  final bool isPublished;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get resourceTypeLabel {
    return switch (resourceType) {
      'form' => 'Form',
      'curriculum' => 'Curriculum',
      'testing' => 'Testing',
      'registration' => 'Registration',
      'document' => 'Document',
      'video' => 'Video',
      'externalLink' || 'external-link' => 'External Link',
      _ => 'General',
    };
  }

  String get categoryLabel {
    return switch (category) {
      'registration' => 'Registration',
      'curriculum' => 'Curriculum',
      'testing' || 'beltTesting' || 'belt-testing' => 'Testing',
      'forms' || 'form' => 'Forms',
      'events' || 'event' => 'Events',
      'academy-information' => 'Academy Information',
      _ => 'General',
    };
  }

  String get statusLabel {
    if (isArchived) {
      return 'Archived';
    }
    return isPublished ? 'Published' : 'Draft';
  }
}
