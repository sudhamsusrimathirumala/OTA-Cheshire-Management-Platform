import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/academy_location.dart';
import '../../models/academy_resource.dart';
import '../../models/student.dart';
import '../../models/user_account.dart';

const firebaseGoogleProviderId = 'google.com';

String normalizeRequiredEmail(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
    throw FormatException('A valid email address is required.');
  }
  return normalized;
}

String? normalizeOptionalPhoneNumber(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

UserAccountRole parseUserAccountRole(Object? value) {
  return switch (value) {
    'student' => UserAccountRole.student,
    'parent' => UserAccountRole.parent,
    'admin' => UserAccountRole.admin,
    'superAdmin' => UserAccountRole.superAdmin,
    _ => throw FormatException('Unsupported user role: $value'),
  };
}

UserAccount userAccountFromFirestoreData(
  String firebaseUid,
  Map<String, dynamic> data,
) {
  if (firebaseUid.trim().isEmpty) {
    throw const FormatException('Firebase UID is required.');
  }
  final role = parseUserAccountRole(data['role']);
  final locationId = _optionalString(data['locationId']) ?? '';
  if (role != UserAccountRole.superAdmin && locationId.isEmpty) {
    throw const FormatException('locationId is required.');
  }
  return UserAccount(
    id: firebaseUid,
    firstName: _requiredString(data['firstName'], 'firstName'),
    lastName: _requiredString(data['lastName'], 'lastName'),
    email: normalizeRequiredEmail(_requiredString(data['email'], 'email')),
    role: role,
    isActive: _requiredBool(data['isActive'], 'isActive'),
    linkedStudentProfileIds: _stringList(data['linkedStudentProfileIds']),
    phoneNumber: normalizeOptionalPhoneNumber(
      _optionalString(data['phoneNumber']),
    ),
    locationId: locationId,
    selectedStudentProfileId: _optionalString(data['selectedStudentProfileId']),
    googleAccountId: _optionalString(data['googleAccountId']),
    createdAt: _requiredDateTime(data['createdAt'], 'createdAt'),
    updatedAt: _requiredDateTime(data['updatedAt'], 'updatedAt'),
  );
}

Map<String, Object?> userAccountWriteFields(
  UserAccount account, {
  required DateTime now,
  bool isCreate = false,
}) {
  final phoneNumber = normalizeOptionalPhoneNumber(account.phoneNumber);
  final googleAccountId = _optionalString(account.googleAccountId);
  return <String, Object?>{
    'firstName': _requiredString(account.firstName, 'firstName'),
    'lastName': _requiredString(account.lastName, 'lastName'),
    'email': normalizeRequiredEmail(account.email),
    'role': account.role.name,
    'isActive': account.isActive,
    'linkedStudentProfileIds': account.linkedStudentProfileIds,
    'phoneNumber': ?phoneNumber,
    if (!isCreate && phoneNumber == null) 'phoneNumber': FieldValue.delete(),
    if (account.locationId.trim().isNotEmpty)
      'locationId': account.locationId.trim(),
    'selectedStudentProfileId': ?account.selectedStudentProfileId,
    'googleAccountId': ?googleAccountId,
    if (isCreate) 'createdAt': Timestamp.fromDate(account.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

Student studentProfileFromCanonicalData(String id, Map<String, dynamic> data) {
  final firstName = _requiredString(data['firstName'], 'firstName');
  final lastName = _requiredString(data['lastName'], 'lastName');
  final guardianEmailValue = _optionalString(data['guardianEmail']);
  return Student(
    id: id,
    name: '$firstName $lastName'.trim(),
    canonicalFirstName: firstName,
    canonicalLastName: lastName,
    locationId: _requiredString(data['locationId'], 'locationId'),
    belt: _requiredString(data['beltRank'], 'beltRank'),
    canonicalBeltRank: _requiredString(data['beltRank'], 'beltRank'),
    dateOfBirth: _requiredDateTime(data['dateOfBirth'], 'dateOfBirth'),
    guardianEmail: guardianEmailValue == null
        ? null
        : normalizeRequiredEmail(guardianEmailValue),
    guardianUserIds: _stringList(data['guardianUserIds']),
    linkedUserId: _optionalString(data['linkedUserId']),
    preferredClassGroupIds: _stringList(data['preferredClassGroupIds']),
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'Next rank',
    isActive: _requiredBool(data['isActive'], 'isActive'),
    createdAt: _requiredDateTime(data['createdAt'], 'createdAt'),
    updatedAt: _requiredDateTime(data['updatedAt'], 'updatedAt'),
  );
}

Map<String, Object?> studentProfileWriteFields(
  Student profile, {
  required DateTime now,
  bool isCreate = false,
}) {
  final dateOfBirth = profile.dateOfBirth;
  final guardianEmail = profile.guardianEmail;
  final linkedUserId = _optionalString(profile.linkedUserId);
  final locationId = _optionalString(profile.locationId);
  if (dateOfBirth == null) {
    throw ArgumentError('dateOfBirth is required for new student profiles.');
  }
  if (guardianEmail == null && linkedUserId == null) {
    throw ArgumentError(
      'guardianEmail is required for parent-managed student profiles.',
    );
  }
  return <String, Object?>{
    'firstName': _requiredString(profile.firstName, 'firstName'),
    'lastName': _requiredString(profile.lastName, 'lastName'),
    'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    'beltRank': _requiredString(profile.beltRank, 'beltRank'),
    'locationId': ?locationId,
    if (guardianEmail != null)
      'guardianEmail': normalizeRequiredEmail(guardianEmail),
    'guardianUserIds': profile.guardianUserIds,
    'isActive': profile.isActive,
    'linkedUserId': ?linkedUserId,
    'preferredClassGroupIds': profile.preferredClassGroupIds,
    if (isCreate) 'createdAt': Timestamp.fromDate(profile.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

AcademyLocation academyLocationFromFirestoreData(
  String id,
  Map<String, dynamic> data,
) {
  return AcademyLocation(
    id: id,
    name: _requiredString(data['name'], 'name'),
    addressLine1: _optionalString(data['addressLine1']),
    addressLine2: _optionalString(data['addressLine2']),
    city: _optionalString(data['city']),
    state: _optionalString(data['state']),
    postalCode: _optionalString(data['postalCode']),
    country: _optionalString(data['country']),
    timeZoneId: _requiredString(data['timeZoneId'], 'timeZoneId'),
    isActive: data['isActive'] is bool ? data['isActive'] as bool : false,
    createdAt: _dateTime(data['createdAt']),
    updatedAt: _dateTime(data['updatedAt']),
  );
}

Map<String, Object?> academyLocationWriteFields(
  AcademyLocation location, {
  required DateTime now,
  bool isCreate = false,
}) {
  final addressLine1 = _requiredString(location.addressLine1, 'addressLine1');
  final city = _requiredString(location.city, 'city');
  final state = _requiredString(location.state, 'state');
  final postalCode = _requiredString(location.postalCode, 'postalCode');
  final country = _requiredString(location.country, 'country');
  final addressLine2 = _optionalString(location.addressLine2);
  return <String, Object?>{
    'name': _requiredString(location.name, 'name'),
    'addressLine1': addressLine1,
    'addressLine2': ?addressLine2,
    if (!isCreate && addressLine2 == null) 'addressLine2': FieldValue.delete(),
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'timeZoneId': _requiredString(location.timeZoneId, 'timeZoneId'),
    'isActive': location.isActive,
    if (isCreate) 'createdAt': Timestamp.fromDate(location.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

AcademyResource? academyResourceFromFirestoreData(
  String id,
  Map<String, dynamic> data,
) {
  final title = _optionalString(data['title']);
  final locationId = _optionalString(data['locationId']);
  final createdAt = _dateTime(data['createdAt']);
  final updatedAt = _dateTime(data['updatedAt']);
  if (title == null ||
      locationId == null ||
      createdAt == null ||
      updatedAt == null) {
    return null;
  }
  return AcademyResource(
    id: id,
    title: title,
    description: _optionalString(data['description']) ?? '',
    resourceSection: _optionalString(data['resourceSection']) ?? 'general',
    category: normalizeLegacyResourceCategory(
      _optionalString(data['category']) ?? 'general',
    ),
    linkUrl: _optionalString(data['linkUrl']) ?? _optionalString(data['url']),
    locationId: locationId,
    isPublished: data['isPublished'] is bool
        ? data['isPublished'] as bool
        : false,
    isArchived: data['isArchived'] is bool ? data['isArchived'] as bool : false,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

const requiredLocationAddressFields = <String>{
  'addressLine1',
  'city',
  'state',
  'postalCode',
  'country',
};

Set<String> missingRequiredLocationAddressFields(Map<String, dynamic> data) {
  return {
    for (final field in requiredLocationAddressFields)
      if (_optionalString(data[field]) == null) field,
  };
}

class FirebaseProviderIdentity {
  const FirebaseProviderIdentity({
    required this.firebaseUid,
    required this.email,
    required this.googleAccountId,
  });

  final String firebaseUid;
  final String? email;
  final String? googleAccountId;
}

FirebaseProviderIdentity providerIdentityFromValues({
  required String firebaseUid,
  String? email,
  required Iterable<ProviderIdentityValue> providers,
}) {
  final googleProvider = providers.where(
    (provider) => provider.providerId == firebaseGoogleProviderId,
  );
  return FirebaseProviderIdentity(
    firebaseUid: firebaseUid,
    email: email == null ? null : normalizeRequiredEmail(email),
    googleAccountId: googleProvider.isEmpty
        ? null
        : _optionalString(googleProvider.first.providerUid),
  );
}

FirebaseProviderIdentity providerIdentityFromFirebaseUser(User user) {
  return providerIdentityFromValues(
    firebaseUid: user.uid,
    email: user.email,
    providers: user.providerData.map(
      (provider) => ProviderIdentityValue(
        providerId: provider.providerId,
        providerUid: provider.uid,
      ),
    ),
  );
}

class ProviderIdentityValue {
  const ProviderIdentityValue({
    required this.providerId,
    required this.providerUid,
  });

  final String providerId;
  final String? providerUid;
}

abstract interface class AuthenticationIdentityService {
  FirebaseProviderIdentity? get currentIdentity;
}

class FirebaseAuthenticationIdentityService
    implements AuthenticationIdentityService {
  FirebaseAuthenticationIdentityService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  FirebaseProviderIdentity? get currentIdentity {
    final user = _auth.currentUser;
    return user == null ? null : providerIdentityFromFirebaseUser(user);
  }
}

String _requiredString(Object? value, String fieldName) {
  final result = _optionalString(value);
  if (result == null) throw FormatException('$fieldName is required.');
  return result;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

DateTime? _dateTime(Object? value) {
  return switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };
}

DateTime _requiredDateTime(Object? value, String fieldName) {
  final result = _dateTime(value);
  if (result == null) throw FormatException('$fieldName is required.');
  return result;
}

bool _requiredBool(Object? value, String fieldName) {
  if (value is! bool) throw FormatException('$fieldName is required.');
  return value;
}
