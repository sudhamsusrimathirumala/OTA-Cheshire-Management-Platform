import '../models/student_profile.dart';
import '../models/user_account.dart';

const canonicalAnnouncementClassGroups = <String, String>{
  'little-tiger-standard': 'Little Tigers',
  'level-1-standard': 'Level 1',
  'level-2-standard': 'Level 2',
  'level-3-standard': 'Level 3',
  'level-4-standard': 'Level 4',
  'black-belt-standard': 'Black Belt',
  'teen-black-belt-standard': 'Teen & Black Belt',
  'adult-standard': 'Adult',
  'teen-adult-sparring-standard': 'Teen/Adult Sparring',
  'level-1-2-sparring-standard': 'Level 1/2 Sparring',
};

Set<String> compatibleAnnouncementClassGroups(String value) => switch (value) {
  'little-tigers' => {'little-tiger-standard'},
  'level-1' => {'level-1-standard'},
  'level-2' => {'level-2-standard'},
  'level-3' => {'level-3-standard'},
  'level-4' => {'level-4-standard'},
  'teen-adult-sparring' => {'teen-adult-sparring-standard'},
  'level-1-2-sparring' || 'sparring-class' => {'level-1-2-sparring-standard'},
  'teen-adult' => {
    'black-belt-standard',
    'teen-black-belt-standard',
    'adult-standard',
  },
  _ => {value},
};

bool announcementClassGroupsMatch(
  Iterable<String> announcementTargets,
  Iterable<String> profileGroups,
) {
  final targets = announcementTargets
      .expand(compatibleAnnouncementClassGroups)
      .toSet();
  final groups = profileGroups.expand(compatibleAnnouncementClassGroups);
  return groups.any(targets.contains);
}

bool announcementMatchesAccount({
  required String audienceType,
  required List<String> targetBelts,
  required List<String> targetClassTypeIds,
  required List<String> targetStudentProfileIds,
  required List<String> targetUserIds,
  required UserAccount account,
  required List<StudentProfile> profiles,
}) {
  if (targetUserIds.contains(account.id)) return true;
  bool matches(String type) => switch (type) {
    'everyone' => true,
    'belt' => profiles.any((profile) => targetBelts.contains(profile.belt)),
    'classType' => profiles.any(
      (profile) => announcementClassGroupsMatch(
        targetClassTypeIds,
        profile.preferredClassGroupIds,
      ),
    ),
    'students' =>
      targetStudentProfileIds.isEmpty
          ? account.role == UserAccountRole.student
          : profiles.any(
              (profile) => targetStudentProfileIds.contains(profile.id),
            ),
    'parents' => account.role == UserAccountRole.parent,
    'specificUsers' => targetUserIds.contains(account.id),
    _ => false,
  };
  return audienceType == 'mixed'
      ? matches('belt') || matches('classType') || matches('students')
      : matches(audienceType);
}
