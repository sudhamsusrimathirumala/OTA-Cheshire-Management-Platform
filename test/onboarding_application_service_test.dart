import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/onboarding_application_service.dart';

void main() {
  test(
    'typed request sends onboarding fields but no privileged identity fields',
    () async {
      Map<String, Object?>? captured;
      final service = FirebaseOnboardingApplicationService(
        callable: (payload) async {
          captured = payload;
          return <Object?, Object?>{
            'userId': 'firebase-uid',
            'studentProfileIds': ['profile-1'],
            'selectedStudentProfileId': 'profile-1',
          };
        },
      );
      final result = await service.submit(
        OnboardingApplicationRequest(
          firstName: ' Student ',
          lastName: ' Applicant ',
          dateOfBirth: DateTime(2000, 1, 2),
          beltRank: ' Blue ',
          phoneNumber: ' ',
          role: OnboardingRole.student,
          locationId: 'ota-cheshire',
          guardianEmail: ' Guardian@Example.com ',
        ),
      );

      expect(result.userId, 'firebase-uid');
      expect(captured!['dateOfBirth'], '2000-01-02');
      expect(captured!['guardianEmail'], 'guardian@example.com');
      expect(captured, isNot(contains('phoneNumber')));
      for (final field in const [
        'uid',
        'email',
        'googleAccountId',
        'approvalStatus',
        'familyApplicationId',
        'linkedStudentProfileIds',
        'guardianUserIds',
        'linkedUserId',
      ]) {
        expect(captured, isNot(contains(field)));
      }
    },
  );

  test('parent request serializes typed additional students', () {
    final payload = OnboardingApplicationRequest(
      firstName: 'Parent',
      lastName: 'Applicant',
      dateOfBirth: DateTime(1980, 2, 3),
      role: OnboardingRole.parent,
      locationId: 'ota-cheshire',
      additionalStudents: [
        OnboardingStudentInput(
          firstName: 'Child',
          lastName: 'Applicant',
          dateOfBirth: DateTime(2015, 4, 5),
          beltRank: 'Yellow',
          guardianEmail: 'Parent@Example.com',
        ),
      ],
    ).toJson();

    final students = payload['additionalStudents']! as List;
    expect(students, hasLength(1));
    expect((students.single as Map)['dateOfBirth'], '2015-04-05');
    expect((students.single as Map)['guardianEmail'], 'parent@example.com');
  });

  test('callable errors map to stable onboarding errors', () {
    OnboardingSubmissionError mapped(String code, String reason) {
      return mapOnboardingFunctionsException(
        FirebaseFunctionsException(
          code: code,
          message: 'Backend message',
          details: {'reason': reason},
        ),
      ).error;
    }

    expect(
      mapped('unauthenticated', 'unauthenticated'),
      OnboardingSubmissionError.unauthenticated,
    );
    expect(
      mapped('already-exists', 'already-submitted'),
      OnboardingSubmissionError.alreadySubmitted,
    );
    expect(
      mapped('failed-precondition', 'invalid-age'),
      OnboardingSubmissionError.invalidAge,
    );
    expect(
      mapped('failed-precondition', 'invalid-location'),
      OnboardingSubmissionError.invalidLocation,
    );
    expect(
      mapped('invalid-argument', 'invalid-data'),
      OnboardingSubmissionError.invalidData,
    );
    expect(
      mapped('internal', 'backend-failure'),
      OnboardingSubmissionError.backendFailure,
    );
  });
}
