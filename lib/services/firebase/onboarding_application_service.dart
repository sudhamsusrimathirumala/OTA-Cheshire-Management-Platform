import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../firestore/firestore_collections.dart';

enum OnboardingRole { student, parent }

enum OnboardingSubmissionError {
  unauthenticated,
  applicationAlreadyExists,
  invalidAge,
  invalidLocation,
  invalidData,
  permissionDenied,
  networkFailure,
  unknownFailure,
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
}

class OnboardingApplicationRequest {
  const OnboardingApplicationRequest({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.role,
    required this.locationId,
    this.applicantBeltRank,
    this.phoneNumber,
    this.guardianEmail,
    this.parentIsStudent = false,
    this.additionalStudents = const <OnboardingStudentInput>[],
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String? applicantBeltRank;
  final String? phoneNumber;
  final OnboardingRole role;
  final String locationId;
  final String? guardianEmail;
  final bool parentIsStudent;
  final List<OnboardingStudentInput> additionalStudents;
}

class OnboardingAuthIdentity {
  const OnboardingAuthIdentity({
    required this.uid,
    required this.email,
    this.googleAccountId,
  });

  final String uid;
  final String email;
  final String? googleAccountId;
}

class OnboardingProviderIdentity {
  const OnboardingProviderIdentity({
    required this.providerId,
    required this.uid,
  });

  final String providerId;
  final String uid;
}

OnboardingAuthIdentity buildOnboardingAuthIdentity({
  required String uid,
  required String email,
  required Iterable<OnboardingProviderIdentity> providers,
}) {
  final normalizedEmail = _normalizedEmail(email, 'Account email');
  String? googleAccountId;
  for (final provider in providers) {
    if (provider.providerId == 'google.com' && provider.uid.trim().isNotEmpty) {
      googleAccountId = provider.uid.trim();
      break;
    }
  }
  return OnboardingAuthIdentity(
    uid: uid,
    email: normalizedEmail,
    googleAccountId: googleAccountId,
  );
}

class OnboardingDocumentPayloads {
  const OnboardingDocumentPayloads({
    required this.user,
    required this.application,
  });

  final Map<String, Object?> user;
  final Map<String, Object?> application;
}

class OnboardingApplicationRecord {
  const OnboardingApplicationRecord({required this.uid, required this.data});

  final String uid;
  final Map<String, dynamic> data;
}

enum OnboardingAccountState {
  needsOnboarding,
  pending,
  approved,
  rejected,
  disabled,
}

OnboardingAccountState resolveOnboardingAccountState({
  required Map<String, dynamic>? user,
  required Map<String, dynamic>? application,
}) {
  if (user == null && application == null) {
    return OnboardingAccountState.needsOnboarding;
  }
  if (user == null || application == null) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The account has an incomplete onboarding record.',
    );
  }
  final userStatus = user['approvalStatus'];
  final applicationStatus = application['status'];
  if (userStatus == 'disabled') {
    return OnboardingAccountState.disabled;
  }
  if (userStatus != applicationStatus) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The account and application statuses do not match.',
    );
  }
  return switch (userStatus) {
    'pending' => OnboardingAccountState.pending,
    'approved' => OnboardingAccountState.approved,
    'rejected' => OnboardingAccountState.rejected,
    _ => throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The onboarding status is invalid.',
    ),
  };
}

class OnboardingReviewResult {
  const OnboardingReviewResult({
    required this.applicantUid,
    required this.status,
    this.studentProfileIds = const <String>[],
    this.selectedStudentProfileId,
    this.familyApplicationId,
  });

  final String applicantUid;
  final String status;
  final List<String> studentProfileIds;
  final String? selectedStudentProfileId;
  final String? familyApplicationId;
}

class OnboardingSubmissionException implements Exception {
  const OnboardingSubmissionException(this.error, this.message);

  final OnboardingSubmissionError error;
  final String message;

  @override
  String toString() => message;
}

class FirestoreOnboardingService {
  FirestoreOnboardingService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static const int maximumAdditionalStudents = 10;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> submitApplication(OnboardingApplicationRequest request) async {
    final identity = _identityFromCurrentUser(_auth.currentUser);
    try {
      late final DocumentSnapshot<Map<String, dynamic>> location;
      try {
        location = await _firestore
            .collection(FirestoreCollections.locations)
            .doc(request.locationId.trim())
            .get();
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.invalidLocation,
            'The selected academy location is unavailable.',
          );
        }
        rethrow;
      }
      final locationData = location.data();
      if (!location.exists || locationData?['isActive'] != true) {
        throw const OnboardingSubmissionException(
          OnboardingSubmissionError.invalidLocation,
          'The selected academy location is unavailable.',
        );
      }
      final timeZoneId = locationData?['timeZoneId'];
      if (timeZoneId is! String || timeZoneId.trim().isEmpty) {
        throw const OnboardingSubmissionException(
          OnboardingSubmissionError.invalidLocation,
          'The selected academy location has no valid time zone.',
        );
      }
      tz_data.initializeTimeZones();
      final academyDate = tz.TZDateTime.now(tz.getLocation(timeZoneId));
      final payloads = buildOnboardingDocumentPayloads(
        request: request,
        identity: identity,
        academyLocalDate: academyDate,
        timestamp: FieldValue.serverTimestamp(),
      );
      final userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(identity.uid);
      final applicationRef = _firestore
          .collection(FirestoreCollections.onboardingApplications)
          .doc(identity.uid);
      final existing = await Future.wait([userRef.get(), applicationRef.get()]);
      if (existing.any((snapshot) => snapshot.exists)) {
        throw const OnboardingSubmissionException(
          OnboardingSubmissionError.applicationAlreadyExists,
          'An application has already been submitted for this account.',
        );
      }
      final batch = _firestore.batch();
      batch.set(userRef, payloads.user);
      batch.set(applicationRef, payloads.application);
      await batch.commit();
    } on OnboardingSubmissionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapOnboardingFirebaseException(error);
    } on ArgumentError catch (error) {
      throw OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        error.message?.toString() ?? 'Review the application fields.',
      );
    } catch (_) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.unknownFailure,
        'The onboarding application could not be submitted.',
      );
    }
  }

  Future<void> retrySubmission(OnboardingApplicationRequest request) =>
      submitApplication(request);

  Future<OnboardingApplicationRecord?> loadCurrentApplication() async {
    final identity = _identityFromCurrentUser(_auth.currentUser);
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.onboardingApplications)
          .doc(identity.uid)
          .get();
      final data = snapshot.data();
      return data == null
          ? null
          : OnboardingApplicationRecord(uid: identity.uid, data: data);
    } on FirebaseException catch (error) {
      throw mapOnboardingFirebaseException(error);
    }
  }

  Future<OnboardingAccountState> loadCurrentAccountState() async {
    final identity = _identityFromCurrentUser(_auth.currentUser);
    try {
      final snapshots = await Future.wait([
        _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid)
            .get(),
        _firestore
            .collection(FirestoreCollections.onboardingApplications)
            .doc(identity.uid)
            .get(),
      ]);
      return resolveOnboardingAccountState(
        user: snapshots[0].data(),
        application: snapshots[1].data(),
      );
    } on OnboardingSubmissionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapOnboardingFirebaseException(error);
    }
  }

  Future<OnboardingReviewResult> approveApplication(String applicantUid) async {
    final reviewer = _identityFromCurrentUser(_auth.currentUser);
    final applicationRef = _firestore
        .collection(FirestoreCollections.onboardingApplications)
        .doc(applicantUid);
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(applicantUid);
    try {
      return await _firestore.runTransaction((transaction) async {
        final reviewerSnapshot = await transaction.get(
          _firestore.collection(FirestoreCollections.users).doc(reviewer.uid),
        );
        final applicationSnapshot = await transaction.get(applicationRef);
        final userSnapshot = await transaction.get(userRef);
        final application = applicationSnapshot.data();
        final applicant = userSnapshot.data();
        if (application == null || applicant == null) {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.invalidData,
            'The pending application could not be found.',
          );
        }
        _validateReviewer(reviewerSnapshot.data(), application);
        if (application['status'] != 'pending' ||
            applicant['approvalStatus'] != 'pending') {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.applicationAlreadyExists,
            'This application has already been reviewed.',
          );
        }
        final locationId = _requiredString(application, 'locationId');
        final locationSnapshot = await transaction.get(
          _firestore.collection(FirestoreCollections.locations).doc(locationId),
        );
        if (locationSnapshot.data()?['isActive'] != true) {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.invalidLocation,
            'The application location is unavailable.',
          );
        }
        final parsed = parsePendingApplication(applicantUid, application);
        final profileInputs = parsed.profileInputs;
        final profileRefs = profileInputs
            .map(
              (_) => _firestore
                  .collection(FirestoreCollections.studentProfiles)
                  .doc(),
            )
            .toList(growable: false);
        for (final profileRef in profileRefs) {
          if ((await transaction.get(profileRef)).exists) {
            throw const OnboardingSubmissionException(
              OnboardingSubmissionError.invalidData,
              'A generated student profile ID already exists.',
            );
          }
        }
        final familyId = parsed.role == OnboardingRole.parent
            ? _firestore
                  .collection(FirestoreCollections.onboardingApplications)
                  .doc()
                  .id
            : null;
        final timestamp = FieldValue.serverTimestamp();
        for (var index = 0; index < profileRefs.length; index++) {
          transaction.set(
            profileRefs[index],
            buildApprovedStudentProfile(
              applicantUid: applicantUid,
              application: parsed,
              student: profileInputs[index],
              isApplicantProfile: parsed.applicantProfileIndex == index,
              familyApplicationId: familyId,
              timestamp: timestamp,
            ),
          );
        }
        final profileIds = profileRefs.map((ref) => ref.id).toList();
        final selectedId = profileIds[parsed.applicantProfileIndex ?? 0];
        transaction.update(userRef, {
          'approvalStatus': 'approved',
          'linkedStudentProfileIds': profileIds,
          'selectedStudentProfileId': selectedId,
          'familyApplicationId': ?familyId,
          'updatedAt': timestamp,
        });
        transaction.update(applicationRef, {
          'status': 'approved',
          'reviewedAt': timestamp,
          'reviewedBy': reviewer.uid,
          'updatedAt': timestamp,
        });
        return OnboardingReviewResult(
          applicantUid: applicantUid,
          status: 'approved',
          studentProfileIds: profileIds,
          selectedStudentProfileId: selectedId,
          familyApplicationId: familyId,
        );
      });
    } on OnboardingSubmissionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapOnboardingFirebaseException(error);
    }
  }

  Future<OnboardingReviewResult> rejectApplication(
    String applicantUid, {
    String? rejectionReason,
  }) async {
    final reviewer = _identityFromCurrentUser(_auth.currentUser);
    final normalizedReason = _optionalString(rejectionReason);
    if (normalizedReason != null && normalizedReason.length > 500) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'The rejection reason must be 500 characters or fewer.',
      );
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final reviewerSnapshot = await transaction.get(
          _firestore.collection(FirestoreCollections.users).doc(reviewer.uid),
        );
        final applicationRef = _firestore
            .collection(FirestoreCollections.onboardingApplications)
            .doc(applicantUid);
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(applicantUid);
        final applicationSnapshot = await transaction.get(applicationRef);
        final userSnapshot = await transaction.get(userRef);
        final application = applicationSnapshot.data();
        final applicant = userSnapshot.data();
        if (application == null || applicant == null) {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.invalidData,
            'The pending application could not be found.',
          );
        }
        _validateReviewer(reviewerSnapshot.data(), application);
        if (application['status'] != 'pending' ||
            applicant['approvalStatus'] != 'pending') {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.applicationAlreadyExists,
            'This application has already been reviewed.',
          );
        }
        final locationId = _requiredString(application, 'locationId');
        final locationSnapshot = await transaction.get(
          _firestore.collection(FirestoreCollections.locations).doc(locationId),
        );
        if (locationSnapshot.data()?['isActive'] != true) {
          throw const OnboardingSubmissionException(
            OnboardingSubmissionError.invalidLocation,
            'The application location is unavailable.',
          );
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.update(userRef, {
          'approvalStatus': 'rejected',
          'updatedAt': timestamp,
        });
        transaction.update(applicationRef, {
          'status': 'rejected',
          'reviewedAt': timestamp,
          'reviewedBy': reviewer.uid,
          'rejectionReason': ?normalizedReason,
          'updatedAt': timestamp,
        });
        return OnboardingReviewResult(
          applicantUid: applicantUid,
          status: 'rejected',
        );
      });
    } on OnboardingSubmissionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapOnboardingFirebaseException(error);
    }
  }
}

OnboardingDocumentPayloads buildOnboardingDocumentPayloads({
  required OnboardingApplicationRequest request,
  required OnboardingAuthIdentity identity,
  required DateTime academyLocalDate,
  required Object timestamp,
}) {
  final firstName = _requiredInput(request.firstName, 'First name');
  final lastName = _requiredInput(request.lastName, 'Last name');
  final locationId = _requiredInput(request.locationId, 'Location');
  final email = _normalizedEmail(identity.email, 'Account email');
  final phone = _optionalString(request.phoneNumber);
  if (_ageOn(request.dateOfBirth, academyLocalDate) < 16) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidAge,
      'The account holder must be at least 16.',
    );
  }
  if (request.additionalStudents.length >
      FirestoreOnboardingService.maximumAdditionalStudents) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'An application may include at most 10 additional students.',
    );
  }
  final applicantBelt = _optionalString(request.applicantBeltRank);
  final guardianEmail = _optionalString(request.guardianEmail)?.toLowerCase();
  if (request.role == OnboardingRole.student) {
    if (request.parentIsStudent || request.additionalStudents.isNotEmpty) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'Student applications cannot include additional students.',
      );
    }
    if (applicantBelt == null || guardianEmail == null) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'Belt rank and guardian email are required.',
      );
    }
    _normalizedEmail(guardianEmail, 'Guardian email');
  } else {
    if (request.parentIsStudent && applicantBelt == null) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'The parent applicant belt rank is required.',
      );
    }
    if (!request.parentIsStudent && request.additionalStudents.isEmpty) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'A parent application must include at least one student.',
      );
    }
  }
  final additionalStudents = request.additionalStudents
      .map((student) {
        return <String, Object?>{
          'firstName': _requiredInput(student.firstName, 'Student first name'),
          'lastName': _requiredInput(student.lastName, 'Student last name'),
          'dateOfBirth': Timestamp.fromDate(_dateOnly(student.dateOfBirth)),
          'beltRank': _requiredInput(student.beltRank, 'Student belt rank'),
          'guardianEmail': _normalizedEmail(
            student.guardianEmail,
            'Student guardian email',
          ),
        };
      })
      .toList(growable: false);
  final googleId = _optionalString(identity.googleAccountId);
  final user = <String, Object?>{
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'role': request.role.name,
    'approvalStatus': 'pending',
    'locationId': locationId,
    'linkedStudentProfileIds': <String>[],
    'phoneNumber': ?phone,
    'googleAccountId': ?googleId,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  };
  final application = <String, Object?>{
    'applicantUid': identity.uid,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phoneNumber': ?phone,
    'dateOfBirth': Timestamp.fromDate(_dateOnly(request.dateOfBirth)),
    'role': request.role.name,
    'locationId': locationId,
    'status': 'pending',
    'parentIsStudent': request.parentIsStudent,
    'applicantBeltRank': ?applicantBelt,
    'guardianEmail': ?guardianEmail,
    'additionalStudents': additionalStudents,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  };
  return OnboardingDocumentPayloads(user: user, application: application);
}

class ParsedPendingApplication {
  const ParsedPendingApplication({
    required this.role,
    required this.locationId,
    required this.parentIsStudent,
    required this.profileInputs,
    required this.applicantProfileIndex,
  });

  final OnboardingRole role;
  final String locationId;
  final bool parentIsStudent;
  final List<OnboardingStudentInput> profileInputs;
  final int? applicantProfileIndex;
}

ParsedPendingApplication parsePendingApplication(
  String applicantUid,
  Map<String, dynamic> application,
) {
  if (_requiredString(application, 'applicantUid') != applicantUid ||
      application['status'] != 'pending') {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The application identity or status is invalid.',
    );
  }
  final role = switch (application['role']) {
    'student' => OnboardingRole.student,
    'parent' => OnboardingRole.parent,
    _ => throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The application role is invalid.',
    ),
  };
  final parentIsStudent = application['parentIsStudent'] == true;
  final students = <OnboardingStudentInput>[];
  int? applicantIndex;
  if (role == OnboardingRole.student || parentIsStudent) {
    applicantIndex = 0;
    students.add(
      OnboardingStudentInput(
        firstName: _requiredString(application, 'firstName'),
        lastName: _requiredString(application, 'lastName'),
        dateOfBirth: _requiredDate(application, 'dateOfBirth'),
        beltRank: _requiredString(application, 'applicantBeltRank'),
        guardianEmail: role == OnboardingRole.student
            ? _normalizedEmail(
                _requiredString(application, 'guardianEmail'),
                'Guardian email',
              )
            : _normalizedEmail(
                _requiredString(application, 'email'),
                'Applicant email',
              ),
      ),
    );
  }
  final additional = application['additionalStudents'];
  if (additional is! List ||
      additional.length >
          FirestoreOnboardingService.maximumAdditionalStudents) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The additional student list is invalid.',
    );
  }
  for (final value in additional) {
    if (value is! Map) {
      throw const OnboardingSubmissionException(
        OnboardingSubmissionError.invalidData,
        'An additional student record is invalid.',
      );
    }
    final data = Map<String, dynamic>.from(value);
    students.add(
      OnboardingStudentInput(
        firstName: _requiredString(data, 'firstName'),
        lastName: _requiredString(data, 'lastName'),
        dateOfBirth: _requiredDate(data, 'dateOfBirth'),
        beltRank: _requiredString(data, 'beltRank'),
        guardianEmail: _normalizedEmail(
          _requiredString(data, 'guardianEmail'),
          'Guardian email',
        ),
      ),
    );
  }
  if (students.isEmpty ||
      (role == OnboardingRole.student && additional.isNotEmpty) ||
      (role == OnboardingRole.parent &&
          !parentIsStudent &&
          additional.isEmpty)) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      'The application has no valid student profiles.',
    );
  }
  return ParsedPendingApplication(
    role: role,
    locationId: _requiredString(application, 'locationId'),
    parentIsStudent: parentIsStudent,
    profileInputs: students,
    applicantProfileIndex: applicantIndex,
  );
}

Map<String, Object?> buildApprovedStudentProfile({
  required String applicantUid,
  required ParsedPendingApplication application,
  required OnboardingStudentInput student,
  required bool isApplicantProfile,
  required String? familyApplicationId,
  required Object timestamp,
}) {
  return <String, Object?>{
    'applicationUid': applicantUid,
    'firstName': student.firstName,
    'lastName': student.lastName,
    'dateOfBirth': Timestamp.fromDate(_dateOnly(student.dateOfBirth)),
    'beltRank': student.beltRank,
    'locationId': application.locationId,
    'guardianEmail': student.guardianEmail,
    'guardianUserIds': isApplicantProfile ? <String>[] : <String>[applicantUid],
    if (isApplicantProfile) 'linkedUserId': applicantUid,
    'familyApplicationId': ?familyApplicationId,
    'approvalStatus': 'approved',
    'preferredClassGroupIds': <String>[],
    'stickerProgress': <String, Object?>{
      'current': 0,
      'required': 0,
      'nextRank': 'Next rank',
    },
    'promotionHistory': <String>[],
    'testingNotes': <String>[],
    'isActive': true,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  };
}

OnboardingSubmissionException mapOnboardingFirebaseException(
  FirebaseException exception,
) {
  final error = switch (exception.code) {
    'permission-denied' => OnboardingSubmissionError.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'network-request-failed' => OnboardingSubmissionError.networkFailure,
    'already-exists' => OnboardingSubmissionError.applicationAlreadyExists,
    'unauthenticated' => OnboardingSubmissionError.unauthenticated,
    _ => OnboardingSubmissionError.unknownFailure,
  };
  return OnboardingSubmissionException(error, switch (error) {
    OnboardingSubmissionError.permissionDenied =>
      'You do not have permission to perform this onboarding action.',
    OnboardingSubmissionError.networkFailure =>
      'The network is unavailable. Try again when connected.',
    OnboardingSubmissionError.applicationAlreadyExists =>
      'An application has already been submitted for this account.',
    OnboardingSubmissionError.unauthenticated =>
      'Sign in before submitting an application.',
    _ => 'The onboarding operation could not be completed.',
  });
}

OnboardingAuthIdentity _identityFromCurrentUser(User? user) {
  final email = user?.email?.trim().toLowerCase();
  if (user == null || email == null || email.isEmpty) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.unauthenticated,
      'Sign in with an account that has an email address.',
    );
  }
  return buildOnboardingAuthIdentity(
    uid: user.uid,
    email: email,
    providers: user.providerData.map(
      (provider) => OnboardingProviderIdentity(
        providerId: provider.providerId,
        uid: provider.uid ?? '',
      ),
    ),
  );
}

void _validateReviewer(
  Map<String, dynamic>? reviewer,
  Map<String, dynamic> application,
) {
  final role = reviewer?['role'];
  if (reviewer?['approvalStatus'] != 'approved' ||
      (role != 'admin' && role != 'superAdmin') ||
      (role == 'admin' &&
          reviewer?['locationId'] != application['locationId'])) {
    throw const OnboardingSubmissionException(
      OnboardingSubmissionError.permissionDenied,
      'This reviewer cannot review the selected application.',
    );
  }
}

String _requiredInput(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      '$label is required.',
    );
  }
  return normalized;
}

String _requiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) {
    throw OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      '$key is missing or invalid.',
    );
  }
  return value.trim();
}

DateTime _requiredDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  final date = switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };
  if (date == null) {
    throw OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      '$key is missing or invalid.',
    );
  }
  return date;
}

String _normalizedEmail(String value, String label) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
    throw OnboardingSubmissionException(
      OnboardingSubmissionError.invalidData,
      '$label is invalid.',
    );
  }
  return normalized;
}

String? _optionalString(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _ageOn(DateTime birthDate, DateTime localDate) {
  var age = localDate.year - birthDate.year;
  if (localDate.month < birthDate.month ||
      (localDate.month == birthDate.month && localDate.day < birthDate.day)) {
    age--;
  }
  return age;
}
