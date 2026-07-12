class CurriculumRequirement {
  const CurriculumRequirement({
    required this.locationId,
    required this.belt,
    required this.sections,
  });

  final String locationId;
  final String belt;
  final List<CurriculumSection> sections;

  List<CurriculumSection> get sortedSections =>
      [...sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

enum CurriculumContentType { video, text }

class CurriculumSection {
  const CurriculumSection({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.items = const <CurriculumItem>[],
  });

  final String id;
  final String title;
  final int sortOrder;
  final List<CurriculumItem> items;

  List<CurriculumItem> get sortedItems =>
      [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

class CurriculumItem {
  const CurriculumItem({
    required this.id,
    required this.title,
    required this.contentType,
    required this.sortOrder,
    this.textContent,
    this.videoUrl,
  });

  final String id;
  final String title;
  final CurriculumContentType contentType;
  final int sortOrder;
  final String? textContent;
  final String? videoUrl;
}
