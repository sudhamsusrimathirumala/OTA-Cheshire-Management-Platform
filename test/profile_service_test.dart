import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
