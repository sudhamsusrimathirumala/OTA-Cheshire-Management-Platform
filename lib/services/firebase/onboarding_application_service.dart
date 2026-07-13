import 'package:cloud_functions/cloud_functions.dart';

enum OnboardingRole { student, parent }

enum OnboardingSubmissionError {
  unauthenticated,
  alreadySubmitted,
  invalidAge,
  invalidLocation,
  invalidData,
  backendFailure,
}

class OnboardingStudentInput {
  const OnboardingStudentInput({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.beltRank,
    required this.guardianEmail,
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String beltRank;
  final String guardianEmail;

  Map<String, Object?> toJson() => {
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'dateOfBirth': _dateOnly(dateOfBirth),
    'beltRank': beltRank.trim(),
    'guardianEmail': guardianEmail.trim().toLowerCase(),
  };
}

class OnboardingApplicationRequest {
  const OnboardingApplicationRequest({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.role,
    required this.locationId,
    this.beltRank,
    this.phoneNumber,
    this.guardianEmail,
    this.parentIsStudent = false,
    this.additionalStudents = const <OnboardingStudentInput>[],
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String? beltRank;
  final String? phoneNumber;
  final OnboardingRole role;
  final String locationId;
  final String? guardianEmail;
  final bool parentIsStudent;
  final List<OnboardingStudentInput> additionalStudents;

  Map<String, Object?> toJson() {
    final normalizedPhone = _optionalString(phoneNumber);
    final normalizedBelt = _optionalString(beltRank);
    final normalizedGuardianEmail = _optionalString(
      guardianEmail,
    )?.toLowerCase();
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'dateOfBirth': _dateOnly(dateOfBirth),
      'role': role.name,
      'locationId': locationId.trim(),
      'parentIsStudent': parentIsStudent,
      'additionalStudents': additionalStudents
          .map((student) => student.toJson())
          .toList(growable: false),
      'beltRank': ?normalizedBelt,
      'phoneNumber': ?normalizedPhone,
      'guardianEmail': ?normalizedGuardianEmail,
    };
  }
}

class OnboardingApplicationResult {
  const OnboardingApplicationResult({
    required this.userId,
    required this.studentProfileIds,
    required this.selectedStudentProfileId,
    this.familyApplicationId,
  });

  factory OnboardingApplicationResult.fromJson(Map<Object?, Object?> json) {
    final userId = json['userId'];
    final profileIds = json['studentProfileIds'];
    final selectedProfileId = json['selectedStudentProfileId'];
    if (userId is! String ||
        profileIds is! List ||
        selectedProfileId is! String ||
        profileIds.isEmpty ||
        profileIds.any((value) => value is! String) ||
        !profileIds.contains(selectedProfileId)) {
      throw const FormatException('Invalid onboarding result payload.');
    }
    return OnboardingApplicationResult(
      userId: userId,
      studentProfileIds: profileIds.whereType<String>().toList(growable: false),
      selectedStudentProfileId: selectedProfileId,
      familyApplicationId: json['familyApplicationId'] as String?,
    );
  }

  final String userId;
  final List<String> studentProfileIds;
  final String selectedStudentProfileId;
  final String? familyApplicationId;
}

class OnboardingSubmissionException implements Exception {
  const OnboardingSubmissionException(this.error, this.message);

  final OnboardingSubmissionError error;
  final String message;

  @override
  String toString() => message;
}

abstract interface class OnboardingApplicationService {
  Future<OnboardingApplicationResult> submit(
    OnboardingApplicationRequest request,
  );
}

typedef OnboardingCallable =
    Future<Object?> Function(Map<String, Object?> payload);

class FirebaseOnboardingApplicationService
    implements OnboardingApplicationService {
  FirebaseOnboardingApplicationService({
    FirebaseFunctions? functions,
    OnboardingCallable? callable,
  }) : _callable =
           callable ??
           ((payload) async {
             final result = await (functions ?? FirebaseFunctions.instance)
                 .httpsCallable('submitOnboardingApplication')
                 .call<Map<Object?, Object?>>(payload);
             return result.data;
           });

  final OnboardingCallable _callable;

  @override
  Future<OnboardingApplicationResult> submit(
    OnboardingApplicationRequest request,
  ) async {
    try {
      final response = await _callable(request.toJson());
      if (response is! Map) {
        throw const FormatException('Invalid onboarding result payload.');
      }
      return OnboardingApplicationResult.fromJson(response);
    } on FirebaseFunctionsException catch (error) {
      throw mapOnboardingFunctionsException(error);
    } on OnboardingSubmissionException {
      rethrow;
    } catch (_) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.backendFailure,
        'The onboarding application could not be submitted.',
      );
    }
  }
}

OnboardingSubmissionException mapOnboardingFunctionsException(
  FirebaseFunctionsException exception,
) {
  final details = exception.details;
  final reason = details is Map ? details['reason'] : null;
  final error = switch ((exception.code, reason)) {
    ('unauthenticated', _) => OnboardingSubmissionError.unauthenticated,
    ('already-exists', _) ||
    (_, 'already-submitted') => OnboardingSubmissionError.alreadySubmitted,
    (_, 'invalid-age') => OnboardingSubmissionError.invalidAge,
    (_, 'invalid-location') => OnboardingSubmissionError.invalidLocation,
    ('invalid-argument', _) ||
    (_, 'invalid-data') => OnboardingSubmissionError.invalidData,
    _ => OnboardingSubmissionError.backendFailure,
  };
  return OnboardingSubmissionException(error, switch (error) {
    OnboardingSubmissionError.unauthenticated =>
      'Sign in before submitting an application.',
    OnboardingSubmissionError.alreadySubmitted =>
      'An application has already been submitted for this account.',
    OnboardingSubmissionError.invalidAge =>
      'The account holder must be at least 16.',
    OnboardingSubmissionError.invalidLocation =>
      'The selected academy location is unavailable.',
    OnboardingSubmissionError.invalidData =>
      exception.message ?? 'Review the application fields and try again.',
    OnboardingSubmissionError.backendFailure =>
      'The onboarding application could not be submitted.',
  });
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _optionalString(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}
