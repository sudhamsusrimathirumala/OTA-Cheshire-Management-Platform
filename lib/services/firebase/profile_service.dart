import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/sample_curriculum.dart';
import '../../models/academy_location.dart';
import '../../models/class_session.dart';
import '../../models/student_profile.dart';
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
    this.guardianEmail,
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String beltRank;
  final String? guardianEmail;
}

class AccountContactInput {
  const AccountContactInput({
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String? phoneNumber;
}

class StudentProfileEditInput {
  const StudentProfileEditInput({
    required this.profileId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.beltRank,
    required this.stickerCurrent,
    required this.stickerRequired,
    this.guardianEmail,
  });

  final String profileId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String beltRank;
  final int stickerCurrent;
  final int stickerRequired;
  final String? guardianEmail;
}

class ParentSelfProfileInput {
  const ParentSelfProfileInput({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.beltRank,
    required this.stickerCurrent,
    required this.stickerRequired,
    this.guardianEmail,
  });

  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String beltRank;
  final int stickerCurrent;
  final int stickerRequired;
  final String? guardianEmail;
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
    try {
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
        (_) =>
            _firestore.collection(FirestoreCollections.studentProfiles).doc(),
      );
      final plan = buildProfileCreationPlan(
        request: request,
        identity: identity,
        profileIds: profileRefs.map((reference) => reference.id).toList(),
        timestamp: FieldValue.serverTimestamp(),
        today: DateTime.now(),
      );
      final batch = _firestore.batch();
      batch.set(userRef, plan.user);
      for (final reference in profileRefs) {
        batch.set(reference, plan.profiles[reference.id]!);
      }
      await batch.commit();
      return profileRefs.map((reference) => reference.id).toList();
    } on ProfileServiceException {
      rethrow;
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

  Future<void> updatePreferredClass({
    required StudentProfile profile,
    ClassSession? session,
  }) async {
    final identity = authProfileIdentity(_auth.currentUser);
    if (session != null && !canSetPreferredClass(profile, session)) {
      throw const ProfileServiceException(
        ProfileServiceError.invalidData,
        'This class is not currently available as a preferred class.',
      );
    }
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(profile.id);
        final user = (await transaction.get(userRef)).data();
        final storedProfile = (await transaction.get(profileRef)).data();
        final storedClass = session == null
            ? null
            : (await transaction.get(
                _firestore
                    .collection(FirestoreCollections.classSessions)
                    .doc(session.id),
              )).data();
        if (!accountManagesStoredProfile(
          user: user,
          profileId: profile.id,
          profile: storedProfile,
        )) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'This student profile is not managed by your account.',
          );
        }
        if (storedProfile?['locationId'] != profile.locationId) {
          throw const ProfileServiceException(
            ProfileServiceError.invalidData,
            'The selected student profile location is out of date.',
          );
        }
        if (session != null) {
          final storedGroup = _optionalString(storedClass?['bulkGroupId']);
          if (storedClass == null ||
              storedClass['isActive'] != true ||
              storedClass['locationId'] != storedProfile?['locationId'] ||
              storedGroup == null ||
              storedGroup != session.bulkGroupId) {
            throw const ProfileServiceException(
              ProfileServiceError.invalidData,
              'The selected class record is unavailable or no longer active.',
            );
          }
        }
        transaction.update(
          profileRef,
          preferredClassUpdateData(
            session?.bulkGroupId,
            timestamp: FieldValue.serverTimestamp(),
          ),
        );
      });
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<String> addChild(StudentProfileInput input) async {
    final identity = authProfileIdentity(_auth.currentUser);
    final childRef = _firestore
        .collection(FirestoreCollections.studentProfiles)
        .doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final user = (await transaction.get(userRef)).data();
        final linked = _stringList(user?['linkedStudentProfileIds']);
        final locationId = _optionalString(user?['locationId']);
        if (user?['role'] != ProfileAccountRole.parent.name ||
            user?['isActive'] != true ||
            locationId == null) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'Only an active parent account may add a child.',
          );
        }
        if (linked.length >= maximumAdditionalStudents + 1) {
          throw const ProfileServiceException(
            ProfileServiceError.invalidData,
            'This account has reached the student profile limit.',
          );
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.set(
          childRef,
          childProfileCreationData(
            input: input,
            parentUid: identity.uid,
            locationId: locationId,
            timestamp: timestamp,
            today: DateTime.now(),
          ),
        );
        transaction.update(userRef, {
          'linkedStudentProfileIds': [...linked, childRef.id],
          'updatedAt': timestamp,
        });
      });
      return childRef.id;
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<String> addParentSelfProfile(ParentSelfProfileInput input) async {
    final identity = authProfileIdentity(_auth.currentUser);
    final profileRef = _firestore
        .collection(FirestoreCollections.studentProfiles)
        .doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final user = (await transaction.get(userRef)).data();
        final linked = _stringList(user?['linkedStudentProfileIds']);
        final locationId = _optionalString(user?['locationId']);
        if (user?['role'] != ProfileAccountRole.parent.name ||
            user?['isActive'] != true ||
            locationId == null) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'Only an active parent account may add its own student profile.',
          );
        }
        if (linked.length >= maximumAdditionalStudents + 1) {
          throw const ProfileServiceException(
            ProfileServiceError.invalidData,
            'This account has reached the student profile limit.',
          );
        }
        for (final id in linked) {
          final existing = (await transaction.get(
            _firestore.collection(FirestoreCollections.studentProfiles).doc(id),
          )).data();
          if (existing?['isActive'] == true &&
              existing?['linkedUserId'] == identity.uid) {
            throw const ProfileServiceException(
              ProfileServiceError.alreadyExists,
              'Your student profile is already linked to this account.',
            );
          }
        }
        final timestamp = FieldValue.serverTimestamp();
        transaction.set(
          profileRef,
          parentSelfProfileCreationData(
            input: input,
            parentUid: identity.uid,
            locationId: locationId,
            timestamp: timestamp,
            today: DateTime.now(),
          ),
        );
        transaction.update(userRef, {
          'linkedStudentProfileIds': [...linked, profileRef.id],
          'updatedAt': timestamp,
        });
      });
      return profileRef.id;
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<String?> removeChild(String profileId) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      return await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(profileId);
        final user = (await transaction.get(userRef)).data();
        final profile = (await transaction.get(profileRef)).data();
        final linked = _stringList(user?['linkedStudentProfileIds']);
        if (user?['role'] != ProfileAccountRole.parent.name ||
            !linked.contains(profileId) ||
            profile?['linkedUserId'] == identity.uid ||
            !_stringList(profile?['guardianUserIds']).contains(identity.uid)) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'This student cannot be removed from your account.',
          );
        }
        final remainingIds = linked.where((id) => id != profileId).toList();
        String? nextSelectedId;
        for (final id in remainingIds) {
          final candidate = (await transaction.get(
            _firestore.collection(FirestoreCollections.studentProfiles).doc(id),
          )).data();
          if (candidate?['isActive'] == true &&
              candidate?['locationId'] == user?['locationId']) {
            nextSelectedId ??= id;
          }
        }
        if (nextSelectedId == null) {
          throw const ProfileServiceException(
            ProfileServiceError.invalidData,
            'At least one active student profile must remain on the account.',
          );
        }
        final selectedId = user?['selectedStudentProfileId'] == profileId
            ? nextSelectedId
            : user?['selectedStudentProfileId'];
        final timestamp = FieldValue.serverTimestamp();
        transaction.update(userRef, {
          'linkedStudentProfileIds': remainingIds,
          'selectedStudentProfileId': selectedId,
          'updatedAt': timestamp,
        });
        transaction.update(profileRef, {
          'isActive': false,
          'updatedAt': timestamp,
        });
        return selectedId is String ? selectedId : null;
      });
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<void> updateAccountContact(AccountContactInput input) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(identity.uid)
          .update(
            accountContactUpdateData(
              input,
              timestamp: FieldValue.serverTimestamp(),
            ),
          );
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }

  Future<void> updateManagedProfile(StudentProfileEditInput input) async {
    final identity = authProfileIdentity(_auth.currentUser);
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(identity.uid);
        final profileRef = _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(input.profileId);
        final user = (await transaction.get(userRef)).data();
        final profile = (await transaction.get(profileRef)).data();
        if (!accountManagesStoredProfile(
          user: user,
          profileId: input.profileId,
          profile: profile,
        )) {
          throw const ProfileServiceException(
            ProfileServiceError.permissionDenied,
            'You cannot edit this student profile.',
          );
        }
        if (input.dateOfBirth.isAfter(DateTime.now())) {
          throw const ProfileServiceException(
            ProfileServiceError.invalidData,
            'Date of birth cannot be in the future.',
          );
        }
        final requiresGuardian = profile?['linkedUserId'] == null;
        transaction.update(
          profileRef,
          studentProfileUpdateData(
            input,
            requireGuardianEmail: requiresGuardian,
            timestamp: FieldValue.serverTimestamp(),
          ),
        );
      });
    } on ProfileServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw mapProfileFirebaseException(error);
    }
  }
}

bool accountManagesStoredProfile({
  required Map<String, dynamic>? user,
  required String profileId,
  required Map<String, dynamic>? profile,
}) {
  if (user == null ||
      profile == null ||
      user['isActive'] != true ||
      profile['isActive'] != true ||
      profile['locationId'] != user['locationId'] ||
      !_stringList(user['linkedStudentProfileIds']).contains(profileId)) {
    return false;
  }
  return true;
}

bool canSetPreferredClass(StudentProfile profile, ClassSession session) =>
    profile.isActive &&
    session.isPublished &&
    session.locationId == profile.locationId &&
    session.bulkGroupId.trim().isNotEmpty;

Map<String, Object?> preferredClassUpdateData(
  String? bulkGroupId, {
  required Object timestamp,
}) {
  final normalized = _optionalString(bulkGroupId);
  return <String, Object?>{
    'preferredClassGroupIds': normalized == null ? <String>[] : [normalized],
    'updatedAt': timestamp,
  };
}

Map<String, Object?> childProfileCreationData({
  required StudentProfileInput input,
  required String parentUid,
  required String locationId,
  required Object timestamp,
  required DateTime today,
}) {
  if (input.dateOfBirth.isAfter(today)) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Date of birth cannot be in the future.',
    );
  }
  final belt = _canonicalBelt(input.beltRank);
  final data = <String, Object?>{
    'firstName': _requiredInput(input.firstName, 'First name'),
    'lastName': _requiredInput(input.lastName, 'Last name'),
    'dateOfBirth': Timestamp.fromDate(_dateOnly(input.dateOfBirth)),
    'beltRank': belt,
    'locationId': _requiredInput(locationId, 'Academy location'),
    'guardianEmail': _normalizedEmail(
      input.guardianEmail ?? '',
      'Guardian email',
    ),
    'guardianUserIds': [parentUid],
    'preferredClassGroupIds': <String>[],
    'stickerProgress': <String, Object?>{
      'current': 0,
      'required': 0,
      'nextRank': nextRankForBelt(belt),
    },
    'promotionHistory': <String>[],
    'testingNotes': <String>[],
    'isActive': true,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  };
  return data;
}

Map<String, Object?> parentSelfProfileCreationData({
  required ParentSelfProfileInput input,
  required String parentUid,
  required String locationId,
  required Object timestamp,
  required DateTime today,
}) {
  if (input.dateOfBirth.isAfter(today)) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Date of birth cannot be in the future.',
    );
  }
  if (input.stickerCurrent < 0 || input.stickerRequired < 0) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Sticker counts cannot be negative.',
    );
  }
  final belt = _canonicalBelt(input.beltRank);
  final guardianEmail = _optionalNormalizedEmail(
    input.guardianEmail,
    'Guardian email',
  );
  final data = <String, Object?>{
    'firstName': _requiredInput(input.firstName, 'First name'),
    'lastName': _requiredInput(input.lastName, 'Last name'),
    'dateOfBirth': Timestamp.fromDate(_dateOnly(input.dateOfBirth)),
    'beltRank': belt,
    'locationId': _requiredInput(locationId, 'Academy location'),
    'guardianUserIds': <String>[],
    'linkedUserId': parentUid,
    'preferredClassGroupIds': <String>[],
    'stickerProgress': <String, Object?>{
      'current': input.stickerCurrent,
      'required': input.stickerRequired,
      'nextRank': nextRankForBelt(belt),
    },
    'promotionHistory': <String>[],
    'testingNotes': <String>[],
    'isActive': true,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  };
  if (guardianEmail != null) data['guardianEmail'] = guardianEmail;
  return data;
}

Map<String, Object?> accountContactUpdateData(
  AccountContactInput input, {
  required Object timestamp,
}) {
  final phone = _optionalString(input.phoneNumber);
  return {
    'firstName': _requiredInput(input.firstName, 'First name'),
    'lastName': _requiredInput(input.lastName, 'Last name'),
    if (phone != null)
      'phoneNumber': phone
    else
      'phoneNumber': FieldValue.delete(),
    'updatedAt': timestamp,
  };
}

Map<String, Object?> studentProfileUpdateData(
  StudentProfileEditInput input, {
  required bool requireGuardianEmail,
  required Object timestamp,
}) {
  if (input.stickerCurrent < 0 || input.stickerRequired < 0) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Sticker counts cannot be negative.',
    );
  }
  final belt = _canonicalBelt(input.beltRank);
  final guardianEmail = requireGuardianEmail
      ? _normalizedEmail(input.guardianEmail ?? '', 'Guardian email')
      : _optionalNormalizedEmail(input.guardianEmail, 'Guardian email');
  return {
    'firstName': _requiredInput(input.firstName, 'First name'),
    'lastName': _requiredInput(input.lastName, 'Last name'),
    'dateOfBirth': Timestamp.fromDate(_dateOnly(input.dateOfBirth)),
    'beltRank': belt,
    if (guardianEmail != null)
      'guardianEmail': guardianEmail
    else
      'guardianEmail': FieldValue.delete(),
    'stickerProgress': {
      'current': input.stickerCurrent,
      'required': input.stickerRequired,
      'nextRank': nextRankForBelt(belt),
    },
    'updatedAt': timestamp,
  };
}

String nextRankForBelt(String belt) {
  final index = curriculumBeltOrder.indexOf(belt);
  if (index < 0) {
    throw const ProfileServiceException(
      ProfileServiceError.invalidData,
      'Select a valid belt rank.',
    );
  }
  return index == curriculumBeltOrder.length - 1
      ? curriculumBeltOrder.last
      : curriculumBeltOrder[index + 1];
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
        ? _optionalNormalizedEmail(request.guardianEmail, 'Guardian email')
        : _optionalNormalizedEmail(request.guardianEmail, 'Guardian email') ??
              email;
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
          student.guardianEmail ?? '',
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
      if (entry.student.guardianEmail != null)
        'guardianEmail': entry.student.guardianEmail,
      'guardianUserIds': entry.isApplicant
          ? <String>[]
          : <String>[identity.uid],
      if (entry.isApplicant) 'linkedUserId': identity.uid,
      'preferredClassGroupIds': <String>[],
      'stickerProgress': <String, Object?>{
        'current': 0,
        'required': 0,
        'nextRank': nextRankForBelt(entry.student.beltRank),
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

String? _optionalNormalizedEmail(Object? value, String label) {
  final normalized = _optionalString(value);
  return normalized == null ? null : _normalizedEmail(normalized, label);
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
