class AcademyResource {
  const AcademyResource({
    required this.id,
    required this.title,
    required this.description,
    this.resourceSection = 'general',
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
  final String category;
  final String? linkUrl;
  final String locationId;
  final bool isPublished;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get categoryLabel {
    return switch (category) {
      'registration' => 'Registration',
      'curriculum' => 'Curriculum',
      'testing' || 'beltTesting' || 'belt-testing' => 'Testing',
      'forms' || 'form' || 'events' || 'event' => 'General',
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

const canonicalResourceCategories = <String>{
  'registration',
  'testing',
  'academy-information',
  'general',
};

String normalizeLegacyResourceCategory(String value) {
  final compact = value.trim().replaceAll(RegExp(r'[_\s-]+'), '').toLowerCase();
  return switch (compact) {
    'belttesting' || 'testing' => 'testing',
    'registration' => 'registration',
    'academyinformation' => 'academy-information',
    'form' || 'forms' || 'event' || 'events' => 'general',
    'general' => 'general',
    _ => value.trim().toLowerCase().replaceAll(RegExp(r'[_\s]+'), '-'),
  };
}

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
