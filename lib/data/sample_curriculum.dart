import '../models/curriculum_requirement.dart';
import 'sample_constants.dart';

const curriculumBeltOrder = [
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

const sampleCurriculum = <String, CurriculumRequirement>{
  'White': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'White',
    formItems: [
      'Taegeuk form placeholder',
      'Basic stance sequence placeholder',
    ],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: [
      'Front kick board break placeholder',
      'Hammer fist board break placeholder',
    ],
    physicalChallengeItems: [],
  ),
  'White-Yellow': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'White-Yellow',
    formItems: ['Taegeuk form placeholder', 'Low block practice sequence'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Front kick board break placeholder'],
    physicalChallengeItems: [],
  ),
  'Yellow': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Yellow',
    formItems: ['Taegeuk form placeholder', 'Practice sequence placeholder'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Front kick board break placeholder'],
    physicalChallengeItems: ['Push-up challenge placeholder'],
  ),
  'Yellow-Green': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Yellow-Green',
    formItems: [
      'Taegeuk form placeholder',
      'Turning kick sequence placeholder',
    ],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Distance control partner drill',
    ],
    breakingItems: [
      'Front kick board break placeholder',
      'Side kick board break placeholder',
    ],
    physicalChallengeItems: ['Push-up challenge placeholder'],
  ),
  'Green': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Green',
    formItems: ['Taegeuk form placeholder', 'Practice sequence placeholder'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Side kick board break placeholder'],
    physicalChallengeItems: [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Green-Blue': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Green-Blue',
    formItems: ['Taegeuk form placeholder', 'Combination kicking sequence'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Side kick board break placeholder'],
    physicalChallengeItems: ['Endurance challenge placeholder'],
  ),
  'Blue': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Blue',
    formItems: ['Taegeuk form placeholder', 'Practice sequence placeholder'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Counter-kick partner drill',
    ],
    breakingItems: [
      'Side kick board break placeholder',
      'Round kick board break placeholder',
    ],
    physicalChallengeItems: [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Blue-Red': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Blue-Red',
    formItems: ['Taegeuk form placeholder', 'Advanced transition sequence'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Side kick board break placeholder'],
    physicalChallengeItems: ['Endurance challenge placeholder'],
  ),
  'Red': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Red',
    formItems: ['Taegeuk form placeholder', 'Practice sequence placeholder'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: [
      'Side kick board break placeholder',
      'Jump front kick board break placeholder',
    ],
    physicalChallengeItems: [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Red-Yellow': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Red-Yellow',
    formItems: [
      'Taegeuk form placeholder',
      'Black belt prep sequence placeholder',
    ],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Side kick board break placeholder'],
    physicalChallengeItems: ['Endurance challenge placeholder'],
  ),
  'Red-Green': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Red-Green',
    formItems: ['Taegeuk form placeholder', 'Precision sequence placeholder'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: [
      'Side kick board break placeholder',
      'Back kick board break placeholder',
    ],
    physicalChallengeItems: [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Red-Blue': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Red-Blue',
    formItems: [
      'Taegeuk form placeholder',
      'Advanced practice sequence placeholder',
    ],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Partner drill placeholder',
    ],
    breakingItems: ['Back kick board break placeholder'],
    physicalChallengeItems: ['Endurance challenge placeholder'],
  ),
  'Red-Black': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Red-Black',
    formItems: ['Taegeuk form placeholder', 'Black belt readiness sequence'],
    oneStepItems: [
      'One-step sparring combination placeholder',
      'Advanced partner drill placeholder',
    ],
    breakingItems: [
      'Side kick board break placeholder',
      'Back kick board break placeholder',
    ],
    physicalChallengeItems: [
      'Push-up challenge placeholder',
      'Endurance challenge placeholder',
    ],
  ),
  'Black': CurriculumRequirement(
    locationId: otaCheshireLocationId,
    belt: 'Black',
    formItems: [
      'Black belt form placeholder',
      'Degree curriculum sequence placeholder',
    ],
    oneStepItems: [
      'Advanced one-step sparring placeholder',
      'Leadership partner drill placeholder',
    ],
    breakingItems: ['Advanced board break placeholder'],
    physicalChallengeItems: ['Endurance challenge placeholder'],
  ),
};

String beltDisplayLabel(String belt) => '$belt Belt';
