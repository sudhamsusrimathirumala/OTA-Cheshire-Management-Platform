import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/onboarding_application_service.dart';

void main() {
  final adultDate = DateTime(2000, 1, 2);
  final academyDate = DateTime(2026, 7, 13);

  OnboardingApplicationRequest studentRequest({
    String? phoneNumber,
    String guardianEmail = ' Guardian@Example.com ',
  }) {
    return OnboardingApplicationRequest(
      firstName: ' Student ',
      lastName: ' Applicant ',
      dateOfBirth: adultDate,
      applicantBeltRank: ' Blue ',
      phoneNumber: phoneNumber,
      role: OnboardingRole.student,
      locationId: ' cheshire ',
      guardianEmail: guardianEmail,
    );
  }

  OnboardingDocumentPayloads build(
    OnboardingApplicationRequest request, {
    OnboardingAuthIdentity identity = const OnboardingAuthIdentity(
      uid: 'firebase-uid',
      email: ' Applicant@Example.com ',
    ),
  }) {
    return buildOnboardingDocumentPayloads(
      request: request,
      identity: identity,
      academyLocalDate: academyDate,
      timestamp: 'server-timestamp',
    );
  }

  test('student payload creates exactly canonical initial documents', () {
    final payloads = build(studentRequest(phoneNumber: ' '));

    expect(payloads.user, {
      'firstName': 'Student',
      'lastName': 'Applicant',
      'email': 'applicant@example.com',
      'role': 'student',
      'approvalStatus': 'pending',
      'locationId': 'cheshire',
      'linkedStudentProfileIds': <String>[],
      'createdAt': 'server-timestamp',
      'updatedAt': 'server-timestamp',
    });
    expect(payloads.application['applicantUid'], 'firebase-uid');
    expect(payloads.application['guardianEmail'], 'guardian@example.com');
    expect(payloads.application['additionalStudents'], isEmpty);
    expect(payloads.application, isNot(contains('linkedStudentProfileIds')));
    expect(payloads.application, isNot(contains('approvalRoleOverride')));
  });

  test('optional phone is trimmed or omitted', () {
    expect(
      build(studentRequest(phoneNumber: ' 555-0100 ')).user['phoneNumber'],
      '555-0100',
    );
    expect(
      build(studentRequest(phoneNumber: ' ')).user,
      isNot(contains('phoneNumber')),
    );
  });

  test(
    'parent with one or multiple children serializes canonical students',
    () {
      OnboardingStudentInput child(String name) => OnboardingStudentInput(
        firstName: ' $name ',
        lastName: ' Applicant ',
        dateOfBirth: DateTime(2015, 4, 5),
        beltRank: ' Yellow ',
        guardianEmail: ' Parent@Example.com ',
      );
      final payloads = build(
        OnboardingApplicationRequest(
          firstName: 'Parent',
          lastName: 'Applicant',
          dateOfBirth: adultDate,
          role: OnboardingRole.parent,
          locationId: 'cheshire',
          additionalStudents: [child('One'), child('Two')],
        ),
      );
      final students = payloads.application['additionalStudents']! as List;
      expect(students, hasLength(2));
      expect((students.first as Map)['firstName'], 'One');
      expect((students.first as Map)['guardianEmail'], 'parent@example.com');
    },
  );

  test('parent who is a student requires and stores applicant belt', () {
    final payloads = build(
      OnboardingApplicationRequest(
        firstName: 'Parent',
        lastName: 'Student',
        dateOfBirth: adultDate,
        role: OnboardingRole.parent,
        locationId: 'cheshire',
        parentIsStudent: true,
        applicantBeltRank: 'Green',
      ),
    );
    expect(payloads.application['parentIsStudent'], true);
    expect(payloads.application['applicantBeltRank'], 'Green');
  });

  test('under-16, empty parent, and invalid guardian email are rejected', () {
    expect(
      () => build(
        OnboardingApplicationRequest(
          firstName: 'Young',
          lastName: 'Applicant',
          dateOfBirth: DateTime(2015, 1, 1),
          role: OnboardingRole.student,
          locationId: 'cheshire',
          applicantBeltRank: 'White',
          guardianEmail: 'guardian@example.com',
        ),
      ),
      throwsA(
        isA<OnboardingSubmissionException>().having(
          (error) => error.error,
          'error',
          OnboardingSubmissionError.invalidAge,
        ),
      ),
    );
    expect(
      () => build(
        OnboardingApplicationRequest(
          firstName: 'Parent',
          lastName: 'Applicant',
          dateOfBirth: adultDate,
          role: OnboardingRole.parent,
          locationId: 'cheshire',
        ),
      ),
      throwsA(isA<OnboardingSubmissionException>()),
    );
    expect(
      () => build(studentRequest(guardianEmail: 'not-an-email')),
      throwsA(isA<OnboardingSubmissionException>()),
    );
  });

  test('Google provider ID comes only from google.com provider data', () {
    final identity = buildOnboardingAuthIdentity(
      uid: 'uid',
      email: 'User@Example.com',
      providers: const [
        OnboardingProviderIdentity(
          providerId: 'password',
          uid: 'user@example.com',
        ),
        OnboardingProviderIdentity(
          providerId: 'google.com',
          uid: 'google-subject-id',
        ),
      ],
    );
    expect(identity.email, 'user@example.com');
    expect(identity.googleAccountId, 'google-subject-id');
    final passwordOnly = buildOnboardingAuthIdentity(
      uid: 'uid',
      email: 'user@example.com',
      providers: const [
        OnboardingProviderIdentity(
          providerId: 'password',
          uid: 'user@example.com',
        ),
      ],
    );
    expect(passwordOnly.googleAccountId, isNull);
  });

  test('pending application parser creates correct parent profile order', () {
    final payloads = build(
      OnboardingApplicationRequest(
        firstName: 'Parent',
        lastName: 'Applicant',
        dateOfBirth: adultDate,
        role: OnboardingRole.parent,
        locationId: 'cheshire',
        parentIsStudent: true,
        applicantBeltRank: 'Blue',
        additionalStudents: [
          OnboardingStudentInput(
            firstName: 'Child',
            lastName: 'Applicant',
            dateOfBirth: DateTime(2015, 4, 5),
            beltRank: 'Yellow',
            guardianEmail: 'parent@example.com',
          ),
        ],
      ),
    );
    final parsed = parsePendingApplication(
      'firebase-uid',
      Map<String, dynamic>.from(payloads.application),
    );
    expect(parsed.profileInputs, hasLength(2));
    expect(parsed.applicantProfileIndex, 0);
    expect(parsed.profileInputs.first.firstName, 'Parent');
  });

  test('approved child profile uses parent guardian and shared family ID', () {
    final parsed = ParsedPendingApplication(
      role: OnboardingRole.parent,
      locationId: 'cheshire',
      parentIsStudent: false,
      profileInputs: const [],
      applicantProfileIndex: null,
    );
    final profile = buildApprovedStudentProfile(
      applicantUid: 'parent-uid',
      application: parsed,
      student: OnboardingStudentInput(
        firstName: 'Child',
        lastName: 'Applicant',
        dateOfBirth: DateTime(2015, 4, 5),
        beltRank: 'Yellow',
        guardianEmail: 'parent@example.com',
      ),
      isApplicantProfile: false,
      familyApplicationId: 'family-id',
      timestamp: 'server-timestamp',
    );
    expect(profile['guardianUserIds'], ['parent-uid']);
    expect(profile, isNot(contains('linkedUserId')));
    expect(profile['familyApplicationId'], 'family-id');
  });

  test('Firebase errors map to stable app-level categories', () {
    OnboardingSubmissionError mapped(String code) =>
        mapOnboardingFirebaseException(
          FirebaseException(plugin: 'cloud_firestore', code: code),
        ).error;

    expect(
      mapped('permission-denied'),
      OnboardingSubmissionError.permissionDenied,
    );
    expect(mapped('unavailable'), OnboardingSubmissionError.networkFailure);
    expect(
      mapped('already-exists'),
      OnboardingSubmissionError.applicationAlreadyExists,
    );
    expect(
      mapped('unauthenticated'),
      OnboardingSubmissionError.unauthenticated,
    );
    expect(mapped('internal'), OnboardingSubmissionError.unknownFailure);
  });

  test(
    'missing onboarding records route a returning Auth user to onboarding',
    () {
      expect(
        resolveOnboardingAccountState(user: null, application: null),
        OnboardingAccountState.needsOnboarding,
      );
      expect(
        resolveOnboardingAccountState(
          user: {'approvalStatus': 'pending'},
          application: {'status': 'pending'},
        ),
        OnboardingAccountState.pending,
      );
      expect(
        () => resolveOnboardingAccountState(
          user: {'approvalStatus': 'pending'},
          application: null,
        ),
        throwsA(isA<OnboardingSubmissionException>()),
      );
    },
  );
}
