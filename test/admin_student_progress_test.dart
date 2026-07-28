import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_admin_write_service.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';

void main() {
  test('admin progress payload contains only progress fields', () {
    final fields = adminStudentProgressWriteFields(
      const AdminStudentProgressWriteData(
        profileId: 'student',
        beltRank: 'Blue',
        stickerCurrent: 3,
        stickerRequired: 5,
      ),
    );
    expect(fields.keys, unorderedEquals(['beltRank', 'stickerProgress']));
    expect(fields['stickerProgress'], {
      'current': 3,
      'required': 5,
      'nextRank': 'Blue-Red',
    });
  });

  test('admin progress rejects invalid belts and sticker values', () {
    expect(
      () => adminStudentProgressWriteFields(
        const AdminStudentProgressWriteData(
          profileId: 'student',
          beltRank: 'Purple',
          stickerCurrent: 0,
          stickerRequired: 0,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => adminStudentProgressWriteFields(
        const AdminStudentProgressWriteData(
          profileId: 'student',
          beltRank: 'Blue',
          stickerCurrent: -1,
          stickerRequired: 0,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => adminStudentProgressWriteFields(
        const AdminStudentProgressWriteData(
          profileId: 'student',
          beltRank: 'Blue',
          stickerCurrent: 6,
          stickerRequired: 5,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('parent resolution excludes the self-managed student account', () {
    const profile = Student(
      id: 'profile',
      name: 'Student',
      locationId: 'cheshire',
      belt: 'Blue',
      legacyAge: 16,
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Blue-Red',
      linkedUserId: 'student',
    );
    const accounts = [
      UserAccount(
        id: 'student',
        firstName: 'Student',
        lastName: 'User',
        email: 'student@example.com',
        role: UserAccountRole.student,
        linkedStudentProfileIds: ['profile'],
      ),
      UserAccount(
        id: 'parent',
        firstName: 'Parent',
        lastName: 'User',
        email: 'parent@example.com',
        role: UserAccountRole.parent,
        linkedStudentProfileIds: ['profile'],
      ),
    ];
    expect(parentAccountForProfile(profile, accounts)?.id, 'parent');
    expect(parentAccountForProfile(profile, [accounts.first]), isNull);
  });
}
