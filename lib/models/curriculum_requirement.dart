class CurriculumRequirement {
  CurriculumRequirement({
    required this.locationId,
    required this.belt,
    required this.formItems,
    required this.oneStepItems,
    required this.breakingItems,
    required this.physicalChallengeItems,
    List<CurriculumSection>? sections,
  }) : sections = List.unmodifiable(
         sections ??
             _legacySections(
               formItems: formItems,
               oneStepItems: oneStepItems,
               breakingItems: breakingItems,
               physicalChallengeItems: physicalChallengeItems,
             ),
       );

  final String locationId;
  final String belt;
  final List<String> formItems;
  final List<String> oneStepItems;
  final List<String> breakingItems;
  final List<String> physicalChallengeItems;
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
  final String? textContent;
  final String? videoUrl;
  final int sortOrder;
}

List<CurriculumSection> _legacySections({
  required List<String> formItems,
  required List<String> oneStepItems,
  required List<String> breakingItems,
  required List<String> physicalChallengeItems,
}) {
  return [
    CurriculumSection(
      id: 'forms',
      title: 'Forms',
      sortOrder: 0,
      items: _items(
        formItems,
        CurriculumContentType.video,
        videoUrl: 'https://www.youtube.com/@OlympicTaekwondoAcademy',
      ),
    ),
    CurriculumSection(
      id: 'one-step-sparring',
      title: 'One-Step Sparring',
      sortOrder: 1,
      items: _items(oneStepItems, CurriculumContentType.text),
    ),
    CurriculumSection(
      id: 'breaking',
      title: 'Breaking',
      sortOrder: 2,
      items: _items(breakingItems, CurriculumContentType.text),
    ),
    CurriculumSection(
      id: 'requirements',
      title: 'Requirements',
      sortOrder: 3,
      items: _items(physicalChallengeItems, CurriculumContentType.text),
    ),
  ];
}

List<CurriculumItem> _items(
  List<String> values,
  CurriculumContentType contentType, {
  String? videoUrl,
}) {
  return [
    for (var index = 0; index < values.length; index++)
      CurriculumItem(
        id: 'item-${index + 1}',
        title: values[index],
        contentType: contentType,
        sortOrder: index,
        textContent: contentType == CurriculumContentType.text
            ? values[index]
            : null,
        videoUrl: contentType == CurriculumContentType.video ? videoUrl : null,
      ),
  ];
}
