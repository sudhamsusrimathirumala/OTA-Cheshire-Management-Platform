import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/sample_curriculum.dart';
import '../../models/academy_location.dart';
import '../firestore/firestore_collections.dart';

enum ProfileAccountRole { student, parent }

enum ProfileServiceError {
  unauthenticated,
  alreadyExists,
  invalidAge,
  invalidData,
  invalidLocation,
  permissionDenied,
  networkFailure,
  unknownFailure,
}

class ProfileServiceException implements Exception {
  const ProfileServiceException(this.error, this.message);

  final ProfileServiceError error;
  final String message;

  @override
  String toString() => message;
}

class StudentProfileInput {
  const StudentProfileInput({
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

class ProfileCreationRequest {
  const ProfileCreationRequest({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.applicantBeltRank,
    required this.role,
    required this.locationId,
    this.phoneNumber,
    this.guardianEmail,
    this.parentIsStudent = false,
    this.additionalStudents = const <StudentProfileInput>[],
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String applicantBeltRank;
  final String? phoneNumber;
  final ProfileAccountRole role;
  final String locationId;
  final String? guardianEmail;
  final bool parentIsStudent;
  final List<StudentProfileInput> additionalStudents;
}

class AuthProfileIdentity {
  const AuthProfileIdentity({
    required this.uid,
    required this.email,
    this.googleAccountId,
  });

  final String uid;
  final String email;
  final String? googleAccountId;
}

class ProfileCreationPlan {
  const ProfileCreationPlan({
    required this.user,
    required this.profiles,
    required this.selectedProfileId,
  });

  final Map<String, Object?> user;
  final Map<String, Map<String, Object?>> profiles;
  final String selectedProfileId;
}

class FirestoreProfileService {
  FirestoreProfileService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static const int maximumAdditionalStudents = 10;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<List<String>> createProfiles(ProfileCreationRequest request) async {
    final identity = authProfileIdentity(_auth.currentUser);
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(identity.uid);
    if ((await userRef.get()).exists) {
      throw const ProfileServiceException(
        ProfileServiceError.alreadyExists,
        'Profiles already exist for this account.',
      );
    }

    final locationId = request.locationId.trim();
    final locationSnapshot = await _firestore
        .collection(FirestoreCollections.locations)
        .doc(locationId)
        .get();
    if (locationId.isEmpty || locationSnapshot.data()?['isActive'] != true) {
      throw const ProfileServiceException(
        ProfileServiceError.invalidLocation,
        'The selected academy location is unavailable.',
      );
    }

    final profileCount = profileCountForRequest(request);
    final profileRefs = List.generate(
      profileCount,
      (_) => _firestore.collection(FirestoreCollections.studentProfiles).doc(),
    );
    final plan = buildProfileCreationPlan(
      request: request,
      identity: identity,
      profileIds: profileRefs.map((reference) => reference.id).toList(),
      timestamp: FieldValue.serverTimestamp(),
      today: DateTime.now(),
    );
    try {
      final batch = _firestore.batch();
      batch.set(userRef, plan.user);
      for (final reference in profileRefs) {
        batch.set(reference, plan.profiles[reference.id]!);
      }
      await batch.commit();
      return profileRefs.map((reference) => reference.id).toList();
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<List<AcademyLocation>> loadActiveLocations() async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.locations)
          .where('isActive', isEqualTo: true)
          .get();
      final locations = snapshot.docs.map((document) {
        final data = document.data();
        return AcademyLocation(
          id: document.id,
          name: _requiredString(data['name'], 'Location name'),
          timeZoneId: _requiredString(data['timeZoneId'], 'Location time zone'),
          isActive: true,
          addressLine1: _optionalString(data['addressLine1']),
          addressLine2: _optionalString(data['addressLine2']),
          city: _optionalString(data['city']),
          state: _optionalString(data['state']),
          postalCode: _optionalString(data['postalCode']),
          country: _optionalString(data['country']),
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));
      return locations;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<void> selectProfile(String profileId) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final user = (await transaction.get(userRef)).data();
        final linked = _stringList(user?['linkedStudentProfileIds']);
        if (!linked.contains(profileId)) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'This student profile is not linked to your account.',
          );
        }
        transaction.update(userRef, {
          'selectedStudentProfileId': profileId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }
}

int profileCountForRequest(ProfileCreationRequest request) {
  final ownProfile =
      request.role == ProfileAccountRole.student || request.parentIsStudent;
  return (ownProfile ? 1 : 0) + request.additionalStudents.length;
}

ProfileCreationPlan buildProfileCreationPlan({
  required ProfileCreationRequest request,
  required AuthProfileIdentity identity,
  required List<String> profileIds,
  required Object timestamp,
  required DateTime today,
}) {
  final firstName = _requiredInput(request.firstName, 'First name');
  final lastName = _requiredInput(request.lastName, 'Last name');
  final email = _normalizedEmail(identity.email, 'Account email');
  final locationId = _requiredInput(request.locationId, 'Academy location');
  if (_ageOn(request.dateOfBirth, today) < 16) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidAge,
      'You must be at least 16. A parent must create this profile.',
    );
  }
  if (request.dateOfBirth.isAfter(today)) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Date of birth cannot be in the future.',
    );
  }
  final ownProfile =
      request.role == ProfileAccountRole.student || request.parentIsStudent;
  if (!ownProfile && request.additionalStudents.isEmpty) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'A parent account must include at least one student.',
    );
  }
  if (request.additionalStudents.length >
      FirestoreProfileService.maximumAdditionalStudents) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'A family may include at most 10 additional students.',
    );
  }
  final expectedCount = profileCountForRequest(request);
  if (profileIds.length != expectedCount ||
      profileIds.toSet().length != profileIds.length ||
      profileIds.any((id) => id.trim().isEmpty)) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Student profile IDs are invalid.',
    );
  }

  final inputs = <({StudentProfileInput student, bool isApplicant})>[];
  if (ownProfile) {
    final guardian = request.role == ProfileAccountRole.student
        ? _normalizedEmail(
            _requiredInput(request.guardianEmail ?? '', 'Guardian email'),
            'Guardian email',
          )
        : email;
    inputs.add((
      student: StudentProfileInput(
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: request.dateOfBirth,
        beltRank: _canonicalBelt(request.applicantBeltRank),
        guardianEmail: guardian,
      ),
      isApplicant: true,
    ));
  }
  for (final student in request.additionalStudents) {
    if (student.dateOfBirth.isAfter(today)) {
      throw const ProfileServiceException(
        ProfileServiceError.invalidData,
        'Student dates of birth cannot be in the future.',
      );
    }
    inputs.add((
      student: StudentProfileInput(
        firstName: _requiredInput(student.firstName, 'Student first name'),
        lastName: _requiredInput(student.lastName, 'Student last name'),
        dateOfBirth: student.dateOfBirth,
        beltRank: _canonicalBelt(student.beltRank),
        guardianEmail: _normalizedEmail(
          student.guardianEmail,
          'Guardian email',
        ),
      ),
      isApplicant: false,
    ));
  }

  final profiles = <String, Map<String, Object?>>{};
  for (var index = 0; index < inputs.length; index++) {
    final entry = inputs[index];
    profiles[profileIds[index]] = {
      'firstName': entry.student.firstName,
      'lastName': entry.student.lastName,
      'dateOfBirth': Timestamp.fromDate(_dateOnly(entry.student.dateOfBirth)),
      'beltRank': entry.student.beltRank,
      'locationId': locationId,
      'guardianEmail': entry.student.guardianEmail,
      'guardianUserIds': entry.isApplicant
          ? <String>[]
          : <String>[identity.uid],
      if (entry.isApplicant) 'linkedUserId': identity.uid,
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
  final phone = _optionalString(request.phoneNumber);
  final googleId = _optionalString(identity.googleAccountId);
  final selectedProfileId = profileIds.first;
  return ProfileCreationPlan(
    selectedProfileId: selectedProfileId,
    profiles: profiles,
    user: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': request.role.name,
      'isActive': true,
      'locationId': locationId,
      'linkedStudentProfileIds': profileIds,
      'selectedStudentProfileId': selectedProfileId,
      'phoneNumber': ?phone,
      'googleAccountId': ?googleId,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    },
  );
}

AuthProfileIdentity authProfileIdentity(User? user) {
  if (user == null || user.email == null) {
    throw const ProfileServiceException(
      ProfileServiceError.unauthenticated,
      'Sign in before managing profiles.',
    );
  }
  String? googleId;
  for (final provider in user.providerData) {
    if (provider.providerId == 'google.com' &&
        provider.uid != null &&
        provider.uid!.trim().isNotEmpty) {
      googleId = provider.uid!.trim();
      break;
    }
  }
  return AuthProfileIdentity(
    uid: user.uid,
    email: user.email!,
    googleAccountId: googleId,
  );
}

ProfileServiceException mapProfileFirebaseException(FirebaseException error) {
  final category = switch (error.code) {
    'permission-denied' => ProfileServiceError.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'network-request-failed' => ProfileServiceError.networkFailure,
    'already-exists' => ProfileServiceError.alreadyExists,
    _ => ProfileServiceError.unknownFailure,
  };
  return ProfileServiceException(category, switch (category) {
    ProfileServiceError.permissionDenied =>
      'You do not have permission to change these profiles.',
    ProfileServiceError.networkFailure =>
      'The network is unavailable. Check your connection and try again.',
    ProfileServiceError.alreadyExists => 'This record already exists.',
    _ => 'The profile operation could not be completed.',
  });
}

String _canonicalBelt(String value) {
  final belt = _requiredInput(value, 'Belt rank');
  if (!curriculumBeltOrder.contains(belt)) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Select a valid belt rank.',
    );
  }
  return belt;
}

String _requiredInput(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ProfileServiceException(
      ProfileServiceError.invalidData,
      '$label is required.',
    );
  }
  return normalized;
}

String _requiredString(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw ProfileServiceException(
      ProfileServiceError.invalidData,
      '$label is required.',
    );
  }
  return value.trim();
}

String _normalizedEmail(String value, String label) {
  final email = value.trim().toLowerCase();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    throw ProfileServiceException(
      ProfileServiceError.invalidData,
      '$label is invalid.',
    );
  }
  return email;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) => value is Iterable
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _ageOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}
