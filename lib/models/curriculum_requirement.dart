class CurriculumRequirement {
  const CurriculumRequirement({
    required this.belt,
    required this.formItems,
    required this.oneStepItems,
    required this.breakingItems,
    required this.physicalChallengeItems,
  });

  final String belt;
  final List<String> formItems;
  final List<String> oneStepItems;
  final List<String> breakingItems;
  final List<String> physicalChallengeItems;
}
