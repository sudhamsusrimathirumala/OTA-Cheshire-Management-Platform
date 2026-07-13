import '../models/curriculum_requirement.dart';
import 'sample_constants.dart';

const curriculumBeltOrder = <String>[
  'No Belt',
  'White',
  'White-Yellow',
  'Yellow',
  'Yellow-Green',
  'Green',
  'Green-Blue',
  'Blue',
  'Blue-Red',
  'Red',
  'Red-Yellow',
  'Red-Green',
  'Red-Blue',
  'Red-Black',
  'Black',
];

final sampleCurriculum = <String, CurriculumRequirement>{
  'No Belt': _curriculum('No Belt'),
  'White': _curriculum(
    'White',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Basic stance sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const [
      'Front kick board break placeholder',
      'Hammer fist board break placeholder',
    ],
  ),
  'White-Yellow': _curriculum(
    'White-Yellow',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Low block practice sequence'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Front kick board break placeholder'],
  ),
  'Yellow': _curriculum(
    'Yellow',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Practice sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Front kick board break placeholder'],
    physicalChallenges: const ['Push-up challenge placeholder'],
  ),
  'Yellow-Green': _curriculum(
    'Yellow-Green',
    forms: const [LocalCurriculumFormData(title: 'Taegeuk form placeholder')],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Distance control partner drill',
    ],
    breakingTechniques: const [
      'Front kick board break placeholder',
      'Side kick board break placeholder',
    ],
    kickingCombinations: const ['Turning kick sequence placeholder'],
    physicalChallenges: const ['Push-up challenge placeholder'],
  ),
  'Green': _curriculum(
    'Green',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Practice sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Side kick board break placeholder'],
    physicalChallenges: const [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Green-Blue': _curriculum(
    'Green-Blue',
    forms: const [LocalCurriculumFormData(title: 'Taegeuk form placeholder')],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Side kick board break placeholder'],
    kickingCombinations: const ['Combination kicking sequence'],
    physicalChallenges: const ['Endurance challenge placeholder'],
  ),
  'Blue': _curriculum(
    'Blue',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Practice sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Counter-kick partner drill',
    ],
    breakingTechniques: const [
      'Side kick board break placeholder',
      'Round kick board break placeholder',
    ],
    physicalChallenges: const [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Blue-Red': _curriculum(
    'Blue-Red',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Advanced transition sequence'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Side kick board break placeholder'],
    physicalChallenges: const ['Endurance challenge placeholder'],
  ),
  'Red': _curriculum(
    'Red',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Practice sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const [
      'Side kick board break placeholder',
      'Jump front kick board break placeholder',
    ],
    physicalChallenges: const [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Red-Yellow': _curriculum(
    'Red-Yellow',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Black belt prep sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Side kick board break placeholder'],
    physicalChallenges: const ['Endurance challenge placeholder'],
  ),
  'Red-Green': _curriculum(
    'Red-Green',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Precision sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const [
      'Side kick board break placeholder',
      'Back kick board break placeholder',
    ],
    physicalChallenges: const [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Red-Blue': _curriculum(
    'Red-Blue',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Advanced practice sequence placeholder'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingTechniques: const ['Back kick board break placeholder'],
    physicalChallenges: const ['Endurance challenge placeholder'],
  ),
  'Red-Black': _curriculum(
    'Red-Black',
    forms: const [
      LocalCurriculumFormData(title: 'Taegeuk form placeholder'),
      LocalCurriculumFormData(title: 'Black belt readiness sequence'),
    ],
    oneStepSparring: const [
      'One-step sparring combination placeholder',
      'Advanced partner drill placeholder',
    ],
    breakingTechniques: const [
      'Side kick board break placeholder',
      'Back kick board break placeholder',
    ],
    physicalChallenges: const [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Black': _curriculum(
    'Black',
    forms: const [
      LocalCurriculumFormData(title: 'Black belt form placeholder'),
      LocalCurriculumFormData(title: 'Degree curriculum sequence placeholder'),
    ],
    oneStepSparring: const [
      'Advanced one-step sparring placeholder',
      'Leadership partner drill placeholder',
    ],
    breakingTechniques: const ['Advanced board break placeholder'],
    physicalChallenges: const ['Endurance challenge placeholder'],
  ),
};

class LocalCurriculumFormData {
  const LocalCurriculumFormData({required this.title, this.videoUrl});

  final String title;
  final String? videoUrl;
}

CurriculumRequirement _curriculum(
  String belt, {
  List<LocalCurriculumFormData> forms = const <LocalCurriculumFormData>[],
  List<String> oneStepSparring = const <String>[],
  List<String> breakingTechniques = const <String>[],
  List<String> kickingCombinations = const <String>[],
  List<String> physicalChallenges = const <String>[],
}) {
  return CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: belt,
    sections: <CurriculumSection>[
      buildLocalCurriculumFormsSection(forms),
      _section(
        id: 'one-step-sparring',
        title: 'One-Step Sparring',
        sortOrder: 1,
        values: oneStepSparring,
      ),
      _section(
        id: 'breaking-techniques',
        title: 'Breaking Techniques',
        sortOrder: 2,
        values: breakingTechniques,
      ),
      _section(
        id: 'kicking-combinations',
        title: 'Kicking Combinations',
        sortOrder: 3,
        values: kickingCombinations,
      ),
      _section(
        id: 'physical-challenges',
        title: 'Physical Challenges',
        sortOrder: 4,
        values: physicalChallenges,
      ),
    ],
  );
}

CurriculumSection buildLocalCurriculumFormsSection(
  List<LocalCurriculumFormData> forms,
) {
  return CurriculumSection(
    id: 'forms',
    title: 'Forms',
    sortOrder: 0,
    items: <CurriculumItem>[
      for (var index = 0; index < forms.length; index++)
        CurriculumItem(
          id: 'forms-${index + 1}',
          title: forms[index].title,
          videoUrl: forms[index].videoUrl,
          contentType: CurriculumContentType.video,
          sortOrder: index,
        ),
    ],
  );
}

CurriculumSection _section({
  required String id,
  required String title,
  required int sortOrder,
  required List<String> values,
}) {
  return CurriculumSection(
    id: id,
    title: title,
    sortOrder: sortOrder,
    items: <CurriculumItem>[
      for (var index = 0; index < values.length; index++)
        CurriculumItem(
          id: '$id-${index + 1}',
          title: values[index],
          contentType: CurriculumContentType.text,
          sortOrder: index,
        ),
    ],
  );
}

String beltDisplayLabel(String belt) => belt == 'No Belt' ? belt : '$belt Belt';
