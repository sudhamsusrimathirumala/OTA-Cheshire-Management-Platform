import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_membership_service.dart';

void main() {
  const identity = AuthProfileIdentity(
    uid: 'auth-user',
    email: ' Account@Example.com ',
    emailVerified: true,
    googleAccountId: 'google-id',
  );
  final today = DateTime(2026, 7, 14);

  ProfileCreationPlan build(
    ProfileCreationRequest request, {
    List<String> ids = const ['profile-1'],
    String? familyId,
  }) => buildProfileCreationPlan(
    request: request,
    identity: identity,
    profileIds: ids,
    timestamp: 'server-time',
    today: today,
    familyApplicationId: familyId,
  );

  test('independent student starts incomplete and without a location', () {
    final plan = build(
      ProfileCreationRequest(
        firstName: ' Student ',
        lastName: ' Member ',
        dateOfBirth: DateTime(2000, 1, 2),
        applicantBeltRank: 'Blue',
        role: ProfileAccountRole.student,
        guardianEmail: ' Guardian@Example.com ',
      ),
    );

    expect(plan.user['email'], 'account@example.com');
    expect(plan.user['approvalStatus'], 'incomplete');
    expect(plan.user['linkedStudentProfileIds'], ['profile-1']);
    expect(plan.user['selectedStudentProfileId'], 'profile-1');
    expect(plan.user, isNot(contains('locationId')));
    expect(
      plan.profiles['profile-1'],
      containsPair('linkedUserId', 'auth-user'),
    );
    expect(
      plan.profiles['profile-1']!['guardianEmail'],
      'guardian@example.com',
    );
    expect(plan.profiles['profile-1']!['approvalStatus'], 'incomplete');
    expect(plan.profiles['profile-1'], isNot(contains('locationId')));
  });

  test(
    'parent and children share one family and default guardian identity',
    () {
      final plan = build(
        ProfileCreationRequest(
          firstName: 'Parent',
          lastName: 'Member',
          dateOfBirth: DateTime(1985, 2, 3),
          applicantBeltRank: 'No Belt',
          role: ProfileAccountRole.parent,
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
        familyId: 'family-1',
      );

      expect(plan.familyApplicationId, 'family-1');
      expect(plan.user['familyApplicationId'], 'family-1');
      expect(
        plan.profiles.values.every(
          (profile) => profile['familyApplicationId'] == 'family-1',
        ),
        isTrue,
      );
      expect(plan.profiles['parent-profile']!['guardianUserIds'], isEmpty);
      expect(plan.profiles['child-profile']!['guardianUserIds'], ['auth-user']);
      expect(plan.profiles['child-profile'], isNot(contains('linkedUserId')));
    },
  );

  test('parent-only account selects its first child profile', () {
    final plan = build(
      ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1985, 2, 3),
        applicantBeltRank: 'No Belt',
        role: ProfileAccountRole.parent,
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
      familyId: 'family-1',
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
      additionalStudents: List.generate(count, child),
    );
    expect(
      build(
        request(10),
        ids: List.generate(10, (index) => 'child-$index'),
        familyId: 'family-1',
      ).profiles,
      hasLength(10),
    );
    expect(
      () => build(
        request(11),
        ids: List.generate(11, (index) => 'child-$index'),
        familyId: 'family-1',
      ),
      throwsA(isA<MembershipServiceException>()),
    );
  });

  test('rejects an under-16 applicant', () {
    expect(
      () => build(
        ProfileCreationRequest(
          firstName: 'Young',
          lastName: 'Applicant',
          dateOfBirth: DateTime(2012, 1, 1),
          applicantBeltRank: 'White',
          role: ProfileAccountRole.student,
          guardianEmail: 'guardian@example.com',
        ),
      ),
      throwsA(
        isA<MembershipServiceException>().having(
          (error) => error.error,
          'error',
          MembershipServiceError.invalidAge,
        ),
      ),
    );
  });

  test('rejects invalid profile counts, belts, and unverified identities', () {
    final request = ProfileCreationRequest(
      firstName: 'Student',
      lastName: 'Member',
      dateOfBirth: DateTime(2000, 1, 1),
      applicantBeltRank: 'Purple',
      role: ProfileAccountRole.student,
      guardianEmail: 'guardian@example.com',
    );
    expect(() => build(request), throwsA(isA<MembershipServiceException>()));
    expect(
      () => buildProfileCreationPlan(
        request: ProfileCreationRequest(
          firstName: 'Student',
          lastName: 'Member',
          dateOfBirth: DateTime(2000, 1, 1),
          applicantBeltRank: 'White',
          role: ProfileAccountRole.student,
          guardianEmail: 'guardian@example.com',
        ),
        identity: const AuthProfileIdentity(
          uid: 'auth-user',
          email: 'account@example.com',
          emailVerified: false,
        ),
        profileIds: const ['profile-1'],
        timestamp: 'server-time',
        today: today,
      ),
      throwsA(
        isA<MembershipServiceException>().having(
          (error) => error.error,
          'error',
          MembershipServiceError.unverifiedEmail,
        ),
      ),
    );
  });

  test('Firestore failures map to safe membership messages', () {
    final error = mapMembershipFirebaseException(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    expect(error.error, MembershipServiceError.permissionDenied);
    expect(error.message, isNot(contains('permission-denied')));
  });
}
