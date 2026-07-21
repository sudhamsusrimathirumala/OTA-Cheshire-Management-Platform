import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/announcement_audience.dart';

void main() {
  const parent = UserAccount(
    id: 'parent',
    firstName: 'Pat',
    lastName: 'Parent',
    email: 'parent@example.com',
    role: UserAccountRole.parent,
    locationId: 'cheshire',
    linkedStudentProfileIds: ['adult', 'level-one'],
    selectedStudentProfileId: 'level-one',
  );
  final adult = _profile('adult', 'adult-standard');
  final levelOne = _profile('level-one', 'level-1-standard');

  test('exact and legacy adult targets use the same canonical contract', () {
    expect(
      announcementClassGroupsMatch([
        'adult-standard',
      ], adult.preferredClassGroupIds),
      isTrue,
    );
    expect(
      announcementClassGroupsMatch([
        'teen-adult',
      ], adult.preferredClassGroupIds),
      isTrue,
    );
    expect(
      announcementClassGroupsMatch([
        'adult-standard',
      ], levelOne.preferredClassGroupIds),
      isFalse,
    );
  });

  test(
    'parent audience includes both active linked profiles and direct notices',
    () {
      bool matches({
        required String type,
        List<String> groups = const [],
        List<String> students = const [],
        List<String> users = const [],
      }) => announcementMatchesAccount(
        audienceType: type,
        targetBelts: const [],
        targetClassTypeIds: groups,
        targetStudentProfileIds: students,
        targetUserIds: users,
        account: parent,
        profiles: [adult, levelOne],
      );
      expect(matches(type: 'classType', groups: ['adult-standard']), isTrue);
      expect(matches(type: 'students', students: ['level-one']), isTrue);
      expect(matches(type: 'students', students: ['unrelated']), isFalse);
      expect(matches(type: 'parents'), isTrue);
      expect(matches(type: 'specificUsers', users: ['parent']), isTrue);
    },
  );
}

Student _profile(String id, String group) => Student(
  id: id,
  name: id,
  locationId: 'cheshire',
  belt: 'Black',
  legacyAge: 18,
  stickerCount: 0,
  stickersRequired: 0,
  nextRank: 'Black',
  preferredClassGroupIds: [group],
  isActive: true,
);
