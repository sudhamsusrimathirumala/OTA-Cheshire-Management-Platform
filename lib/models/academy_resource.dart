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

const canonicalResourceTypes = <String>{
  'form',
  'testing',
  'registration',
  'document',
  'video',
  'externalLink',
  'general',
};

const canonicalResourceCategories = <String>{
  'registration',
  'testing',
  'forms',
  'events',
  'academy-information',
  'general',
};

Uri? validResourceLinkUri(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.isAbsolute ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}
