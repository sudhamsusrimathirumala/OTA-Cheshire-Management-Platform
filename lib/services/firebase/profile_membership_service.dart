import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/sample_curriculum.dart';
import '../../models/academy_location.dart';
import '../firestore/firestore_collections.dart';

enum ProfileAccountRole { student, parent }

enum MembershipServiceError {
  unauthenticated,
  alreadyExists,
  invalidAge,
  invalidData,
  invalidLocation,
  invalidTransition,
  permissionDenied,
  networkFailure,
  unknownFailure,
}

class MembershipServiceException implements Exception {
  const MembershipServiceException(this.error, this.message);

  final MembershipServiceError error;
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
    this.familyApplicationId,
  });

  final Map<String, Object?> user;
  final Map<String, Map<String, Object?>> profiles;
  final String selectedProfileId;
  final String? familyApplicationId;
}

class MembershipReviewRequest {
  const MembershipReviewRequest({
    required this.profileId,
    required this.approve,
    this.rejectionReason,
  });

  final String profileId;
  final bool approve;
  final String? rejectionReason;
}

class MembershipApplicationRequest {
  const MembershipApplicationRequest({
    required this.locationId,
    required this.studentProfileIds,
  });

  final String locationId;
  final List<String> studentProfileIds;
}

class MembershipApplicationReviewRequest {
  const MembershipApplicationReviewRequest({
    required this.applicationId,
    required this.approve,
    this.rejectionReason,
  });

  final String applicationId;
  final bool approve;
  final String? rejectionReason;
}

class FirestoreProfileMembershipService {
  FirestoreProfileMembershipService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
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
      throw const MembershipServiceException(
        MembershipServiceError.alreadyExists,
        'Profiles already exist for this account.',
      );
    }
    final profileCount = profileCountForRequest(request);
    final profileRefs = List.generate(
      profileCount,
      (_) => _firestore.collection(FirestoreCollections.studentProfiles).doc(),
    );
    final familyId = request.role == ProfileAccountRole.parent
        ? _firestore.collection(FirestoreCollections.users).doc().id
        : null;
    final plan = buildProfileCreationPlan(
      request: request,
      identity: identity,
      profileIds: profileRefs.map((reference) => reference.id).toList(),
      timestamp: FieldValue.serverTimestamp(),
      familyApplicationId: familyId,
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
      throw mapMembershipFirebaseException(error);
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
      }).toList();
      locations.sort((a, b) => a.name.compareTo(b.name));
      return locations;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
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
          throw const MembershipServiceException(
            MembershipServiceError.permissionDenied,
            'This student profile is not linked to your account.',
          );
        }
        transaction.update(userRef, {
          'selectedStudentProfileId': profileId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
    }
  }

  Future<void> applyToLocation({
    required String profileId,
    required String locationId,
  }) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(profileId);
        final locationRef = _firestore
            .collection(FirestoreCollections.locations)
            .doc(locationId);
        final user = (await transaction.get(userRef)).data();
        final profile = (await transaction.get(profileRef)).data();
        final location = (await transaction.get(locationRef)).data();
        _requireManagedProfile(user, profileId, profile);
        if (location?['isActive'] != true) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidLocation,
            'The selected academy location is unavailable.',
          );
        }
        final status = profile?['approvalStatus'];
        if (status != 'incomplete' && status != 'rejected') {
          throw const MembershipServiceException(
            MembershipServiceError.invalidTransition,
            'This profile already has an active membership application.',
          );
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.update(profileRef, {
          'locationId': locationId,
          'approvalStatus': 'pending',
          'updatedAt': timestamp,
          'rejectionReason': FieldValue.delete(),
          'reviewedAt': FieldValue.delete(),
          'reviewedBy': FieldValue.delete(),
        });
        if (profile?['linkedUserId'] == identity.uid) {
          transaction.update(userRef, {
            'locationId': locationId,
            'updatedAt': timestamp,
          });
        }
      });
    } on MembershipServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
    }
  }

  Future<String> submitMembershipApplication(
    MembershipApplicationRequest request,
  ) async {
    final identity = authProfileIdentity(_auth.currentUser);
    final profileIds = request.studentProfileIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (profileIds.isEmpty ||
        profileIds.length > 11 ||
        profileIds.toSet().length != profileIds.length ||
        request.locationId.trim().isEmpty) {
      throw const MembershipServiceException(
        MembershipServiceError.invalidData,
        'Select at least one eligible student profile and one academy.',
      );
    }
    final applicationRef = _firestore
        .collection(FirestoreCollections.membershipApplications)
        .doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final locationRef = _firestore
            .collection(FirestoreCollections.locations)
            .doc(request.locationId.trim());
        final user = (await transaction.get(userRef)).data();
        final location = (await transaction.get(locationRef)).data();
        if (user == null || location?['isActive'] != true) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidLocation,
            'The selected academy location is unavailable.',
          );
        }
        final linkedIds = _stringList(user['linkedStudentProfileIds']);
        if (!profileIds.every(linkedIds.contains)) {
          throw const MembershipServiceException(
            MembershipServiceError.permissionDenied,
            'One or more selected profiles are not linked to your account.',
          );
        }
        final profileEntries =
            <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
        var includesAccountHolder = false;
        for (final profileId in profileIds) {
          final reference = _firestore
              .collection(FirestoreCollections.studentProfiles)
              .doc(profileId);
          final profile = (await transaction.get(reference)).data();
          _requireManagedProfile(user, profileId, profile);
          if (![
            'incomplete',
            'rejected',
          ].contains(profile?['approvalStatus'])) {
            throw const MembershipServiceException(
              MembershipServiceError.invalidTransition,
              'Only incomplete or rejected profiles may apply.',
            );
          }
          includesAccountHolder =
              includesAccountHolder || profile?['linkedUserId'] == identity.uid;
          profileEntries.add((reference, profile!));
        }
        final timestamp = FieldValue.serverTimestamp();
        final applicantSnapshot = <String, Object?>{
          'firstName': _requiredString(user['firstName'], 'First name'),
          'lastName': _requiredString(user['lastName'], 'Last name'),
          'email': _normalizedEmail(identity.email, 'Account email'),
          'role': _requiredString(user['role'], 'Account role'),
        };
        final phoneNumber = _optionalString(user['phoneNumber']);
        if (phoneNumber != null) {
          applicantSnapshot['phoneNumber'] = phoneNumber;
        }
        transaction.set(applicationRef, {
          'applicantUserId': identity.uid,
          'applicantSnapshot': applicantSnapshot,
          'locationId': request.locationId.trim(),
          'studentProfileIds': profileIds,
          'status': 'pending',
          'appliedAt': timestamp,
          'updatedAt': timestamp,
        });
        for (final entry in profileEntries) {
          transaction.update(entry.$1, {
            'locationId': request.locationId.trim(),
            'approvalStatus': 'pending',
            'applicationId': applicationRef.id,
            'appliedAt': timestamp,
            'updatedAt': timestamp,
            'rejectionReason': FieldValue.delete(),
            'reviewedAt': FieldValue.delete(),
            'reviewedBy': FieldValue.delete(),
          });
        }
        if (includesAccountHolder) {
          transaction.update(userRef, {
            'locationId': request.locationId.trim(),
            'updatedAt': timestamp,
          });
        }
      });
      return applicationRef.id;
    } on MembershipServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
    }
  }

  Future<void> reviewMembershipApplication(
    MembershipApplicationReviewRequest request,
  ) async {
    final reviewer = authProfileIdentity(_auth.currentUser);
    final reason = _optionalString(request.rejectionReason);
    if (reason != null && reason.length > 500) {
      throw const MembershipServiceException(
        MembershipServiceError.invalidData,
        'The rejection reason must be 500 characters or fewer.',
      );
    }
    try {
      await _firestore.runTransaction((transaction) async {
        final reviewerRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(reviewer.uid);
        final applicationRef = _firestore
            .collection(FirestoreCollections.membershipApplications)
            .doc(request.applicationId);
        final reviewerData = (await transaction.get(reviewerRef)).data();
        final application = (await transaction.get(applicationRef)).data();
        final locationId = _optionalString(application?['locationId']);
        final profileIds = _stringList(application?['studentProfileIds']);
        if (reviewerData?['approvalStatus'] != 'approved' ||
            !['admin', 'superAdmin'].contains(reviewerData?['role']) ||
            locationId == null ||
            (reviewerData?['role'] == 'admin' &&
                reviewerData?['locationId'] != locationId)) {
          throw const MembershipServiceException(
            MembershipServiceError.permissionDenied,
            'You cannot review this membership application.',
          );
        }
        if (application?['status'] != 'pending' || profileIds.isEmpty) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidTransition,
            'This membership application has already been reviewed.',
          );
        }
        final location = await transaction.get(
          _firestore.collection(FirestoreCollections.locations).doc(locationId),
        );
        if (location.data()?['isActive'] != true) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidLocation,
            'The selected location is inactive.',
          );
        }
        final profileRefs = <DocumentReference<Map<String, dynamic>>>[];
        for (final profileId in profileIds) {
          final reference = _firestore
              .collection(FirestoreCollections.studentProfiles)
              .doc(profileId);
          final profile = (await transaction.get(reference)).data();
          if (profile?['applicationId'] != applicationRef.id ||
              profile?['approvalStatus'] != 'pending' ||
              profile?['locationId'] != locationId) {
            throw const MembershipServiceException(
              MembershipServiceError.invalidTransition,
              'The application profiles changed and cannot be reviewed.',
            );
          }
          profileRefs.add(reference);
        }
        final timestamp = FieldValue.serverTimestamp();
        final status = request.approve ? 'approved' : 'rejected';
        transaction.update(applicationRef, {
          'status': status,
          'reviewedAt': timestamp,
          'reviewedBy': reviewer.uid,
          'updatedAt': timestamp,
          if (!request.approve && reason != null) 'rejectionReason': reason,
          if (request.approve) 'rejectionReason': FieldValue.delete(),
        });
        for (final reference in profileRefs) {
          transaction.update(reference, {
            'approvalStatus': status,
            'reviewedAt': timestamp,
            'reviewedBy': reviewer.uid,
            'updatedAt': timestamp,
            if (!request.approve && reason != null) 'rejectionReason': reason,
            if (request.approve) 'rejectionReason': FieldValue.delete(),
          });
        }
      });
    } on MembershipServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
    }
  }

  Future<void> leaveLocation(String profileId) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(profileId);
        final user = (await transaction.get(userRef)).data();
        final profile = (await transaction.get(profileRef)).data();
        _requireManagedProfile(user, profileId, profile);
        if (_optionalString(profile?['locationId']) == null ||
            ![
              'approved',
              'pending',
              'rejected',
            ].contains(profile?['approvalStatus'])) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidTransition,
            'This profile is not currently assigned to a location.',
          );
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.update(profileRef, {
          'locationId': FieldValue.delete(),
          'approvalStatus': 'incomplete',
          'rejectionReason': FieldValue.delete(),
          'reviewedAt': FieldValue.delete(),
          'reviewedBy': FieldValue.delete(),
          'updatedAt': timestamp,
        });
        if (profile?['linkedUserId'] == identity.uid &&
            user?['locationId'] == profile?['locationId']) {
          transaction.update(userRef, {
            'locationId': FieldValue.delete(),
            'updatedAt': timestamp,
          });
        }
      });
    } on MembershipServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
    }
  }

  Future<void> reviewMembership(MembershipReviewRequest request) async {
    final reviewer = authProfileIdentity(_auth.currentUser);
    final reason = _optionalString(request.rejectionReason);
    if (reason != null && reason.length > 500) {
      throw const MembershipServiceException(
        MembershipServiceError.invalidData,
        'The rejection reason must be 500 characters or fewer.',
      );
    }
    try {
      await _firestore.runTransaction((transaction) async {
        final reviewerRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(reviewer.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(request.profileId);
        final reviewerData = (await transaction.get(reviewerRef)).data();
        final profile = (await transaction.get(profileRef)).data();
        final locationId = _optionalString(profile?['locationId']);
        if (reviewerData?['approvalStatus'] != 'approved' ||
            !['admin', 'superAdmin'].contains(reviewerData?['role']) ||
            locationId == null ||
            (reviewerData?['role'] == 'admin' &&
                reviewerData?['locationId'] != locationId)) {
          throw const MembershipServiceException(
            MembershipServiceError.permissionDenied,
            'You cannot review this membership application.',
          );
        }
        if (profile?['approvalStatus'] != 'pending') {
          throw const MembershipServiceException(
            MembershipServiceError.invalidTransition,
            'This membership application has already been reviewed.',
          );
        }
        final location = await transaction.get(
          _firestore.collection(FirestoreCollections.locations).doc(locationId),
        );
        if (location.data()?['isActive'] != true) {
          throw const MembershipServiceException(
            MembershipServiceError.invalidLocation,
            'The selected location is inactive.',
          );
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.update(profileRef, {
          'approvalStatus': request.approve ? 'approved' : 'rejected',
          'reviewedAt': timestamp,
          'reviewedBy': reviewer.uid,
          'updatedAt': timestamp,
          if (!request.approve && reason != null) 'rejectionReason': reason,
          if (request.approve) 'rejectionReason': FieldValue.delete(),
        });
      });
    } on MembershipServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapMembershipFirebaseException(error);
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
  String? familyApplicationId,
}) {
  final firstName = _requiredInput(request.firstName, 'First name');
  final lastName = _requiredInput(request.lastName, 'Last name');
  final email = _normalizedEmail(identity.email, 'Account email');
  if (_ageOn(request.dateOfBirth, today) < 16) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidAge,
      'You must be at least 16. A parent must create this profile.',
    );
  }
  if (request.dateOfBirth.isAfter(today)) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'Date of birth cannot be in the future.',
    );
  }
  final ownProfile =
      request.role == ProfileAccountRole.student || request.parentIsStudent;
  if (!ownProfile && request.additionalStudents.isEmpty) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'A parent account must include at least one student.',
    );
  }
  if (request.additionalStudents.length >
      FirestoreProfileMembershipService.maximumAdditionalStudents) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'A family may include at most 10 additional students.',
    );
  }
  final expectedCount = profileCountForRequest(request);
  if (profileIds.length != expectedCount ||
      profileIds.toSet().length != profileIds.length ||
      profileIds.any((id) => id.trim().isEmpty)) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'Student profile IDs are invalid.',
    );
  }
  if (request.role == ProfileAccountRole.parent &&
      _optionalString(familyApplicationId) == null) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'A family ID is required for parent profiles.',
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
      throw const MembershipServiceException(
        MembershipServiceError.invalidData,
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
      'guardianEmail': entry.student.guardianEmail,
      'guardianUserIds': entry.isApplicant
          ? <String>[]
          : <String>[identity.uid],
      if (entry.isApplicant) 'linkedUserId': identity.uid,
      'familyApplicationId': ?familyApplicationId,
      'approvalStatus': 'incomplete',
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
    familyApplicationId: familyApplicationId,
    profiles: profiles,
    user: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': request.role.name,
      'approvalStatus': 'incomplete',
      'linkedStudentProfileIds': profileIds,
      'selectedStudentProfileId': selectedProfileId,
      'phoneNumber': ?phone,
      'googleAccountId': ?googleId,
      'familyApplicationId': ?familyApplicationId,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    },
  );
}

AuthProfileIdentity authProfileIdentity(User? user) {
  if (user == null || user.email == null) {
    throw const MembershipServiceException(
      MembershipServiceError.unauthenticated,
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

MembershipServiceException mapMembershipFirebaseException(
  FirebaseException error,
) {
  final category = switch (error.code) {
    'permission-denied' => MembershipServiceError.permissionDenied,
    'unavailable' ||
    'deadline-exceeded' ||
    'network-request-failed' => MembershipServiceError.networkFailure,
    'already-exists' => MembershipServiceError.alreadyExists,
    _ => MembershipServiceError.unknownFailure,
  };
  return MembershipServiceException(category, switch (category) {
    MembershipServiceError.permissionDenied =>
      'You do not have permission to change this membership.',
    MembershipServiceError.networkFailure =>
      'The network is unavailable. Check your connection and try again.',
    MembershipServiceError.alreadyExists => 'This record already exists.',
    _ => 'The membership operation could not be completed.',
  });
}

void _requireManagedProfile(
  Map<String, dynamic>? user,
  String profileId,
  Map<String, dynamic>? profile,
) {
  if (profile == null ||
      !_stringList(user?['linkedStudentProfileIds']).contains(profileId)) {
    throw const MembershipServiceException(
      MembershipServiceError.permissionDenied,
      'This student profile is not linked to your account.',
    );
  }
}

String _canonicalBelt(String value) {
  final belt = _requiredInput(value, 'Belt rank');
  if (!curriculumBeltOrder.contains(belt)) {
    throw const MembershipServiceException(
      MembershipServiceError.invalidData,
      'Select a valid belt rank.',
    );
  }
  return belt;
}

String _requiredInput(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw MembershipServiceException(
      MembershipServiceError.invalidData,
      '$label is required.',
    );
  }
  return normalized;
}

String _requiredString(Object? value, String label) {
  if (value is! String || value.trim().isEmpty) {
    throw MembershipServiceException(
      MembershipServiceError.invalidData,
      '$label is required.',
    );
  }
  return value.trim();
}

String _normalizedEmail(String value, String label) {
  final email = value.trim().toLowerCase();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    throw MembershipServiceException(
      MembershipServiceError.invalidData,
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
