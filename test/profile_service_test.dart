import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_service.dart';

void main() {
  const identity = AuthProfileIdentity(
    uid: 'auth-user',
    email: ' Account@Example.com ',
    googleAccountId: 'google-id',
  );
  final today = DateTime(2026, 7, 14);

  ProfileCreationPlan build(
    ProfileCreationRequest request, {
    List<String> ids = const ['profile-1'],
  }) => buildProfileCreationPlan(
    request: request,
    identity: identity,
    profileIds: ids,
    timestamp: 'server-time',
    today: today,
  );

  ProfileCreationRequest studentRequest({String locationId = 'cheshire'}) =>
      ProfileCreationRequest(
        firstName: ' Student ',
        lastName: ' Member ',
        dateOfBirth: DateTime(2000, 1, 2),
        applicantBeltRank: 'Blue',
        role: ProfileAccountRole.student,
        locationId: locationId,
        guardianEmail: ' Guardian@Example.com ',
      );

  test('independent student receives immediate active location access', () {
    final plan = build(studentRequest());

    expect(plan.user['email'], 'account@example.com');
    expect(plan.user['isActive'], isTrue);
    expect(plan.user['locationId'], 'cheshire');
    expect(plan.user['linkedStudentProfileIds'], ['profile-1']);
    expect(plan.user['selectedStudentProfileId'], 'profile-1');
    final profile = plan.profiles['profile-1']!;
    expect(profile['linkedUserId'], 'auth-user');
    expect(profile['guardianEmail'], 'guardian@example.com');
    expect(profile['isActive'], isTrue);
    expect(profile['locationId'], 'cheshire');
  });

  test(
    'independent student may omit guardian contact without adding access',
    () {
      final plan = build(
        ProfileCreationRequest(
          firstName: 'Student',
          lastName: 'Member',
          dateOfBirth: DateTime(2000, 1, 2),
          applicantBeltRank: 'Blue',
          role: ProfileAccountRole.student,
          locationId: 'cheshire',
        ),
      );

      final profile = plan.profiles['profile-1']!;
      expect(profile, isNot(contains('guardianEmail')));
      expect(profile['guardianUserIds'], isEmpty);
      expect(profile['linkedUserId'], identity.uid);
      expect(plan.profiles, hasLength(1));
    },
  );

  test('parent account and every profile share one location', () {
    final plan = build(
      ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1985, 2, 3),
        applicantBeltRank: 'No Belt',
        role: ProfileAccountRole.parent,
        locationId: 'cheshire',
        parentIsStudent: true,
        additionalStudents: [
          StudentProfileInput(
            firstName: 'Child',
            lastName: 'Member',
            dateOfBirth: DateTime(2014, 4, 5),
            beltRank: 'White',
            guardianEmail: 'account@example.com',
          ),
        ],
      ),
      ids: ['parent-profile', 'child-profile'],
    );

    expect(plan.user['locationId'], 'cheshire');
    expect(
      plan.profiles.values.every(
        (profile) =>
            profile['locationId'] == 'cheshire' && profile['isActive'] == true,
      ),
      isTrue,
    );
    expect(plan.profiles['parent-profile']!['guardianUserIds'], isEmpty);
    expect(plan.profiles['child-profile']!['guardianUserIds'], ['auth-user']);
    expect(plan.profiles['child-profile'], isNot(contains('linkedUserId')));
  });

  test('parent-only account selects its first child profile', () {
    final plan = build(
      ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1985, 2, 3),
        applicantBeltRank: 'No Belt',
        role: ProfileAccountRole.parent,
        locationId: 'cheshire',
        additionalStudents: [
          StudentProfileInput(
            firstName: 'Child',
            lastName: 'Member',
            dateOfBirth: DateTime(2014, 4, 5),
            beltRank: 'Yellow',
            guardianEmail: 'account@example.com',
          ),
        ],
      ),
    );

    expect(plan.selectedProfileId, 'profile-1');
    expect(plan.profiles['profile-1'], isNot(contains('linkedUserId')));
  });

  test('parent may add ten children but not eleven', () {
    StudentProfileInput child(int index) => StudentProfileInput(
      firstName: 'Child $index',
      lastName: 'Member',
      dateOfBirth: DateTime(2014, 4, 5),
      beltRank: 'White',
      guardianEmail: 'account@example.com',
    );
    ProfileCreationRequest request(int count) => ProfileCreationRequest(
      firstName: 'Parent',
      lastName: 'Member',
      dateOfBirth: DateTime(1985, 2, 3),
      applicantBeltRank: 'No Belt',
      role: ProfileAccountRole.parent,
      locationId: 'cheshire',
      additionalStudents: List.generate(count, child),
    );
    expect(
      build(
        request(10),
        ids: List.generate(10, (index) => 'child-$index'),
      ).profiles,
      hasLength(10),
    );
    expect(
      () =>
          build(request(11), ids: List.generate(11, (index) => 'child-$index')),
      throwsA(isA<ProfileServiceException>()),
    );
  });

  test('rejects under-16 applicants, blank locations, and invalid belts', () {
    expect(
      () => build(
        ProfileCreationRequest(
          firstName: 'Young',
          lastName: 'Applicant',
          dateOfBirth: DateTime(2012, 1, 1),
          applicantBeltRank: 'White',
          role: ProfileAccountRole.student,
          locationId: 'cheshire',
          guardianEmail: 'guardian@example.com',
        ),
      ),
      throwsA(
        isA<ProfileServiceException>().having(
          (error) => error.error,
          'error',
          ProfileServiceError.invalidAge,
        ),
      ),
    );
    expect(
      () => build(studentRequest(locationId: ' ')),
      throwsA(isA<ProfileServiceException>()),
    );
    expect(
      () => build(
        ProfileCreationRequest(
          firstName: 'Student',
          lastName: 'Member',
          dateOfBirth: DateTime(2000, 1, 1),
          applicantBeltRank: 'Purple',
          role: ProfileAccountRole.student,
          locationId: 'cheshire',
          guardianEmail: 'guardian@example.com',
        ),
      ),
      throwsA(isA<ProfileServiceException>()),
    );
  });

  test('Firestore failures map to safe profile messages', () {
    final error = mapProfileFirebaseException(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    expect(error.error, ProfileServiceError.permissionDenied);
    expect(error.message, isNot(contains('permission-denied')));
  });

  test('preferred class payload stores zero or one stable group', () {
    expect(
      preferredClassUpdateData('level-3-standard', timestamp: 'server-time'),
      {
        'preferredClassGroupIds': ['level-3-standard'],
        'updatedAt': 'server-time',
      },
    );
    expect(preferredClassUpdateData(null, timestamp: 'server-time'), {
      'preferredClassGroupIds': <String>[],
      'updatedAt': 'server-time',
    });
  });

  test('preferred class requires publication location and eligibility', () {
    final student = Student(
      id: 'student',
      name: 'Student',
      locationId: 'cheshire',
      belt: 'Blue',
      dateOfBirth: DateTime(2000),
      stickerCount: 0,
      stickersRequired: 0,
      nextRank: 'Blue-Red',
    );
    ClassSession session({
      String locationId = 'cheshire',
      bool published = true,
      List<String> belts = const ['Blue'],
    }) => ClassSession(
      id: 'session',
      className: 'Class',
      classTypeId: 'level-3',
      bulkGroupId: 'level-3-standard',
      locationId: locationId,
      startTime: DateTime(2026, 1, 1, 18),
      endTime: DateTime(2026, 1, 1, 19),
      eligibleBelts: belts,
      description: '',
      isPublished: published,
    );

    expect(canSetPreferredClass(student, session()), isTrue);
    expect(
      canSetPreferredClass(student, session(locationId: 'other')),
      isFalse,
    );
    expect(canSetPreferredClass(student, session(published: false)), isFalse);
    expect(
      canSetPreferredClass(student, session(belts: const ['White'])),
      isFalse,
    );
  });

  test(
    'new child payload preserves parent ownership and starts unconfigured',
    () {
      final data = childProfileCreationData(
        input: StudentProfileInput(
          firstName: ' Child ',
          lastName: ' Member ',
          dateOfBirth: DateTime(2015, 1, 2),
          beltRank: 'White',
          guardianEmail: ' Parent@Example.com ',
        ),
        parentUid: 'parent-uid',
        locationId: 'cheshire',
        timestamp: 'server-time',
        today: today,
      );

      expect(data['locationId'], 'cheshire');
      expect(data['guardianUserIds'], ['parent-uid']);
      expect(data, isNot(contains('linkedUserId')));
      expect(data['preferredClassGroupIds'], isEmpty);
      expect(data['isActive'], isTrue);
      expect(data['stickerProgress'], {
        'current': 0,
        'required': 0,
        'nextRank': 'White-Yellow',
      });
    },
  );

  test('profile edits derive next rank and validate sticker counts', () {
    final data = studentProfileUpdateData(
      StudentProfileEditInput(
        profileId: 'profile-1',
        firstName: 'Student',
        lastName: 'Member',
        dateOfBirth: DateTime(2000, 1, 2),
        beltRank: 'Blue',
        stickerCurrent: 7,
        stickerRequired: 3,
      ),
      requireGuardianEmail: false,
      timestamp: 'server-time',
    );
    expect(data['stickerProgress'], {
      'current': 7,
      'required': 3,
      'nextRank': 'Blue-Red',
    });
    expect(
      () => studentProfileUpdateData(
        StudentProfileEditInput(
          profileId: 'profile-1',
          firstName: 'Student',
          lastName: 'Member',
          dateOfBirth: DateTime(2000, 1, 2),
          beltRank: 'Blue',
          stickerCurrent: -1,
          stickerRequired: 0,
        ),
        requireGuardianEmail: false,
        timestamp: 'server-time',
      ),
      throwsA(isA<ProfileServiceException>()),
    );
  });
}
