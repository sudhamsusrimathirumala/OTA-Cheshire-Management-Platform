import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../data/sample_resources.dart';
import '../../data/sample_student.dart';
import '../../models/academy_resource.dart';
import 'firestore_collections.dart';

class FirestoreMigrationService {
  FirestoreMigrationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<FirestoreMigrationResult> runMvpReadinessMigration() async {
    final userResult = await migrateUserAccounts();
    final studentProfilesUpdated =
        await addPreferredClassGroupIdsToStudentProfiles();
    final guardianResult = await migrateStudentGuardianEmails();
    final classTypeIdsNormalized = await normalizeClassSessionClassTypeIds();
    final bulkGroupResult = await backfillClassSessionBulkGroupIds();
    final announcementsUpdated = await normalizeAnnouncements();
    final eventsUpdated = await backfillEventFields();
    final resourceResult = await backfillResourceFields();
    final locationResult = await migrateLocations();
    final starterResourcesCreated = await createStarterResourcesIfMissing();
    final result = FirestoreMigrationResult(
      studentProfilesUpdated: studentProfilesUpdated,
      studentProfilesGivenGuardianEmail: guardianResult.givenGuardianEmail,
      studentProfilesMissingGuardianEmail: guardianResult.missingGuardianEmail,
      usersNormalizedOrBackfilled: userResult.normalizedOrBackfilled,
      usersMissingRequiredEmail: userResult.missingRequiredEmail,
      userPhoneNumbersPreserved: userResult.phoneNumbersPreserved,
      googleAccountIdsPreservedOrNormalized:
          userResult.googleAccountIdsPreservedOrNormalized,
      classTypeIdsNormalized: classTypeIdsNormalized,
      bulkGroupIdsAdded: bulkGroupResult.added,
      bulkGroupIdsRepaired: bulkGroupResult.repaired,
      announcementsUpdated: announcementsUpdated,
      eventsUpdated: eventsUpdated,
      resourcesUpdated: resourceResult.updated,
      legacyResourceCategoriesNormalized:
          resourceResult.legacyCategoriesNormalized,
      resourceTypeFieldsRemoved: resourceResult.resourceTypeFieldsRemoved,
      resourceTypeFieldsLeftAsLegacy: 0,
      locationsUpdated: locationResult.updated,
      locationsMissingRequiredAddressData:
          locationResult.missingRequiredAddressData,
      starterResourcesCreated: starterResourcesCreated,
    );
    debugPrint(result.logSummary);
    return result;
  }

  Future<UserMigrationResult> migrateUserAccounts() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.users)
        .get();
    final batch = _firestore.batch();
    var normalizedOrBackfilled = 0;
    var missingRequiredEmail = 0;
    var phoneNumbersPreserved = 0;
    var googleAccountIdsPreservedOrNormalized = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final email = validNormalizedEmail(data['email']);
      if (email == null) missingRequiredEmail++;
      if (_stringValue(data['phoneNumber']) != null) phoneNumbersPreserved++;
      if (_stringValue(data['googleAccountId']) != null) {
        googleAccountIdsPreservedOrNormalized++;
      }
      final updates = migrationUserBackfill(data);
      if (updates.isEmpty) continue;
      for (final entry in updates.entries.toList()) {
        if (identical(entry.value, migrationDeleteField)) {
          updates[entry.key] = FieldValue.delete();
        }
      }
      updates['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(document.reference, updates, SetOptions(merge: true));
      normalizedOrBackfilled++;
    }
    if (normalizedOrBackfilled > 0) await batch.commit();
    return UserMigrationResult(
      normalizedOrBackfilled: normalizedOrBackfilled,
      missingRequiredEmail: missingRequiredEmail,
      phoneNumbersPreserved: phoneNumbersPreserved,
      googleAccountIdsPreservedOrNormalized:
          googleAccountIdsPreservedOrNormalized,
    );
  }

  Future<StudentGuardianMigrationResult> migrateStudentGuardianEmails() async {
    final usersSnapshot = await _firestore
        .collection(FirestoreCollections.users)
        .get();
    final usersById = {
      for (final document in usersSnapshot.docs) document.id: document.data(),
    };
    final profilesSnapshot = await _firestore
        .collection(FirestoreCollections.studentProfiles)
        .get();
    final batch = _firestore.batch();
    var givenGuardianEmail = 0;
    var missingGuardianEmail = 0;
    for (final document in profilesSnapshot.docs) {
      final data = document.data();
      if (validNormalizedEmail(data['guardianEmail']) != null) continue;
      final derived = deriveGuardianEmail(document.id, data, usersById);
      if (derived == null) {
        missingGuardianEmail++;
        continue;
      }
      batch.set(document.reference, {
        'guardianEmail': derived,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      givenGuardianEmail++;
    }
    if (givenGuardianEmail > 0) await batch.commit();
    return StudentGuardianMigrationResult(
      givenGuardianEmail: givenGuardianEmail,
      missingGuardianEmail: missingGuardianEmail,
    );
  }

  Future<int> addPreferredClassGroupIdsToStudentProfiles() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.studentProfiles)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      if (data.containsKey('preferredClassGroupIds')) {
        continue;
      }

      final sampleProfile = _sampleStudentProfilesById[document.id];
      final belt =
          _stringValue(data['beltRank']) ??
          _stringValue(data['belt']) ??
          sampleProfile?.belt;
      final preferredClassGroupIds =
          sampleProfile?.preferredClassGroupIds ??
          _preferredClassGroupIdsForBelt(belt);

      batch.set(document.reference, {
        'preferredClassGroupIds': preferredClassGroupIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }
    return updatedCount;
  }

  Future<int> normalizeClassSessionClassTypeIds() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.classSessions)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final className = _stringValue(data['className']);
      final currentClassTypeId = _stringValue(data['classTypeId']);
      final normalizedClassTypeId =
          _normalizeClassTypeId(currentClassTypeId) ??
          (className == null ? null : _classTypeIdForClassName(className));

      if (normalizedClassTypeId == null ||
          normalizedClassTypeId == currentClassTypeId) {
        continue;
      }

      batch.set(document.reference, {
        'classTypeId': normalizedClassTypeId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }
    return updatedCount;
  }

  Future<int> normalizeAnnouncements() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.announcements)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final updates = <String, Object?>{};

      if (_stringValue(data['priority']) == 'critical') {
        updates['priority'] = 'important';
      }

      if (!data.containsKey('requiresAction')) {
        updates['requiresAction'] = false;
      }

      final currentTargetClassTypeIds = _stringListValue(
        data['targetClassTypeIds'],
      );
      final normalizedTargetClassTypeIds =
          currentTargetClassTypeIds
              .map(_normalizeAnnouncementClassGroupId)
              .toSet()
              .toList()
            ..sort();

      if (!_listEquals(
        currentTargetClassTypeIds,
        normalizedTargetClassTypeIds,
      )) {
        updates['targetClassTypeIds'] = normalizedTargetClassTypeIds;
      } else if (!data.containsKey('targetClassTypeIds')) {
        updates['targetClassTypeIds'] = <String>[];
      }

      if (updates.isEmpty) {
        continue;
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(document.reference, updates, SetOptions(merge: true));
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }
    return updatedCount;
  }

  Future<BulkGroupMigrationResult> backfillClassSessionBulkGroupIds() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.classSessions)
        .get();
    final batch = _firestore.batch();
    var addedCount = 0;
    var repairedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final currentBulkGroupId = _stringValue(data['bulkGroupId']);
      final normalizedBulkGroupId = migrationBulkGroupId(data);
      if (currentBulkGroupId == normalizedBulkGroupId) {
        continue;
      }

      batch.set(document.reference, {
        'bulkGroupId': normalizedBulkGroupId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (currentBulkGroupId == null) {
        addedCount++;
      } else {
        repairedCount++;
      }
    }

    if (addedCount + repairedCount > 0) {
      await batch.commit();
    }
    return BulkGroupMigrationResult(added: addedCount, repaired: repairedCount);
  }

  Future<int> backfillEventFields() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.events)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final updates = <String, Object?>{};

      if (!data.containsKey('linkedResourceIds')) {
        updates['linkedResourceIds'] = <String>[];
      }

      if (!data.containsKey('primaryRegistrationResourceId')) {
        updates['primaryRegistrationResourceId'] = null;
      }

      if (!data.containsKey('isArchived')) {
        updates['isArchived'] = false;
      }

      if (updates.isEmpty) {
        continue;
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(document.reference, updates, SetOptions(merge: true));
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }
    return updatedCount;
  }

  Future<ResourceMigrationResult> backfillResourceFields() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.resources)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;
    var legacyCategoriesNormalized = 0;
    var resourceTypeFieldsRemoved = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final plan = migrationResourcePlan(data);
      if (plan.updates.isEmpty && !plan.deleteResourceType) {
        continue;
      }
      final updates = <String, Object?>{...plan.updates};
      if (plan.deleteResourceType) {
        updates['resourceType'] = FieldValue.delete();
        resourceTypeFieldsRemoved++;
      }
      if (plan.normalizesLegacyCategory) legacyCategoriesNormalized++;
      updates['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(document.reference, updates, SetOptions(merge: true));
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }
    return ResourceMigrationResult(
      updated: updatedCount,
      legacyCategoriesNormalized: legacyCategoriesNormalized,
      resourceTypeFieldsRemoved: resourceTypeFieldsRemoved,
    );
  }

  Future<LocationMigrationResult> migrateLocations() async {
    final reference = _firestore
        .collection(FirestoreCollections.locations)
        .doc('ota-cheshire');
    final locationDocument = await reference.get();
    final data = locationDocument.data() ?? const <String, dynamic>{};
    final updates = migrationLocationBackfill(data);
    var updatedCount = 0;
    if (updates.isNotEmpty) {
      await reference.set(updates, SetOptions(merge: true));
      updatedCount = 1;
    }
    final locationsSnapshot = await _firestore
        .collection(FirestoreCollections.locations)
        .get();
    var missingRequiredAddressData = 0;
    for (final document in locationsSnapshot.docs) {
      final effectiveData = document.id == 'ota-cheshire'
          ? <String, dynamic>{...document.data(), ...updates}
          : document.data();
      if (missingLocationAddressFields(effectiveData).isNotEmpty) {
        missingRequiredAddressData++;
      }
    }
    return LocationMigrationResult(
      updated: updatedCount,
      missingRequiredAddressData: missingRequiredAddressData,
    );
  }

  Future<int> createStarterResourcesIfMissing() async {
    final batch = _firestore.batch();
    var writeCount = 0;
    var createdCount = 0;

    for (final resource in sampleAcademyResources) {
      final reference = _firestore
          .collection(FirestoreCollections.resources)
          .doc(resource.id);
      final snapshot = await reference.get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? const <String, dynamic>{};
        final updates = <String, Object?>{};
        if (!data.containsKey('isArchived')) {
          updates['isArchived'] = false;
        }
        if (!data.containsKey('resourceSection')) {
          updates['resourceSection'] = 'general';
        }
        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          batch.set(reference, updates, SetOptions(merge: true));
          writeCount++;
        }
        continue;
      }

      batch.set(reference, _resourceData(resource), SetOptions(merge: true));
      writeCount++;
      createdCount++;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
    return createdCount;
  }
}

class FirestoreMigrationResult {
  const FirestoreMigrationResult({
    required this.studentProfilesUpdated,
    required this.studentProfilesGivenGuardianEmail,
    required this.studentProfilesMissingGuardianEmail,
    required this.usersNormalizedOrBackfilled,
    required this.usersMissingRequiredEmail,
    required this.userPhoneNumbersPreserved,
    required this.googleAccountIdsPreservedOrNormalized,
    required this.classTypeIdsNormalized,
    required this.bulkGroupIdsAdded,
    required this.bulkGroupIdsRepaired,
    required this.announcementsUpdated,
    required this.eventsUpdated,
    required this.resourcesUpdated,
    required this.legacyResourceCategoriesNormalized,
    required this.resourceTypeFieldsRemoved,
    required this.resourceTypeFieldsLeftAsLegacy,
    required this.locationsUpdated,
    required this.locationsMissingRequiredAddressData,
    required this.starterResourcesCreated,
  });

  final int studentProfilesUpdated;
  final int studentProfilesGivenGuardianEmail;
  final int studentProfilesMissingGuardianEmail;
  final int usersNormalizedOrBackfilled;
  final int usersMissingRequiredEmail;
  final int userPhoneNumbersPreserved;
  final int googleAccountIdsPreservedOrNormalized;
  final int classTypeIdsNormalized;
  final int bulkGroupIdsAdded;
  final int bulkGroupIdsRepaired;
  final int announcementsUpdated;
  final int eventsUpdated;
  final int resourcesUpdated;
  final int legacyResourceCategoriesNormalized;
  final int resourceTypeFieldsRemoved;
  final int resourceTypeFieldsLeftAsLegacy;
  final int locationsUpdated;
  final int locationsMissingRequiredAddressData;
  final int starterResourcesCreated;

  String get logSummary =>
      'Firestore migration complete: '
      'student profiles updated=$studentProfilesUpdated, '
      'guardian emails added=$studentProfilesGivenGuardianEmail, '
      'profiles missing guardian email=$studentProfilesMissingGuardianEmail, '
      'users normalized or backfilled=$usersNormalizedOrBackfilled, '
      'users missing email=$usersMissingRequiredEmail, '
      'phone numbers preserved=$userPhoneNumbersPreserved, '
      'Google account IDs preserved=$googleAccountIdsPreservedOrNormalized, '
      'class type IDs normalized=$classTypeIdsNormalized, '
      'bulk group IDs added=$bulkGroupIdsAdded, '
      'bulk group IDs repaired=$bulkGroupIdsRepaired, '
      'announcements updated=$announcementsUpdated, '
      'events updated=$eventsUpdated, '
      'resources updated=$resourcesUpdated, '
      'legacy resource categories normalized=$legacyResourceCategoriesNormalized, '
      'resourceType fields removed=$resourceTypeFieldsRemoved, '
      'resourceType fields left ignored=$resourceTypeFieldsLeftAsLegacy, '
      'locations created or backfilled=$locationsUpdated, '
      'locations missing address=$locationsMissingRequiredAddressData, '
      'starter resources created=$starterResourcesCreated.';

  String get displaySummary =>
      'Migration complete.\n'
      'Student profiles updated: $studentProfilesUpdated\n'
      'Student profiles given guardianEmail: $studentProfilesGivenGuardianEmail\n'
      'Student profiles still missing guardianEmail: $studentProfilesMissingGuardianEmail\n'
      'Users normalized or backfilled: $usersNormalizedOrBackfilled\n'
      'Users still missing required email: $usersMissingRequiredEmail\n'
      'User phone numbers preserved: $userPhoneNumbersPreserved\n'
      'Google account IDs preserved or normalized: $googleAccountIdsPreservedOrNormalized\n'
      'Class type IDs normalized: $classTypeIdsNormalized\n'
      'Bulk group IDs added: $bulkGroupIdsAdded\n'
      'Bulk group IDs repaired: $bulkGroupIdsRepaired\n'
      'Announcements updated: $announcementsUpdated\n'
      'Events updated: $eventsUpdated\n'
      'Resources updated: $resourcesUpdated\n'
      'Legacy resource categories normalized: $legacyResourceCategoriesNormalized\n'
      'resourceType fields removed: $resourceTypeFieldsRemoved\n'
      'resourceType fields left as ignored legacy data: $resourceTypeFieldsLeftAsLegacy\n'
      'Locations created or backfilled: $locationsUpdated\n'
      'Locations still missing required address data: $locationsMissingRequiredAddressData\n'
      'Starter resources created: $starterResourcesCreated';
}

class BulkGroupMigrationResult {
  const BulkGroupMigrationResult({required this.added, required this.repaired});

  final int added;
  final int repaired;
}

class UserMigrationResult {
  const UserMigrationResult({
    required this.normalizedOrBackfilled,
    required this.missingRequiredEmail,
    required this.phoneNumbersPreserved,
    required this.googleAccountIdsPreservedOrNormalized,
  });

  final int normalizedOrBackfilled;
  final int missingRequiredEmail;
  final int phoneNumbersPreserved;
  final int googleAccountIdsPreservedOrNormalized;
}

class StudentGuardianMigrationResult {
  const StudentGuardianMigrationResult({
    required this.givenGuardianEmail,
    required this.missingGuardianEmail,
  });

  final int givenGuardianEmail;
  final int missingGuardianEmail;
}

class ResourceMigrationResult {
  const ResourceMigrationResult({
    required this.updated,
    required this.legacyCategoriesNormalized,
    required this.resourceTypeFieldsRemoved,
  });

  final int updated;
  final int legacyCategoriesNormalized;
  final int resourceTypeFieldsRemoved;
}

class LocationMigrationResult {
  const LocationMigrationResult({
    required this.updated,
    required this.missingRequiredAddressData,
  });

  final int updated;
  final int missingRequiredAddressData;
}

class ResourceMigrationPlan {
  const ResourceMigrationPlan({
    required this.updates,
    required this.deleteResourceType,
    required this.normalizesLegacyCategory,
  });

  final Map<String, Object?> updates;
  final bool deleteResourceType;
  final bool normalizesLegacyCategory;
}

String migrationBulkGroupId(Map<String, dynamic> data) {
  final existingBulkGroupId = _stringValue(data['bulkGroupId']);
  if (existingBulkGroupId != null) {
    return _normalizeRepeatedStandardSuffix(existingBulkGroupId);
  }

  final classTypeId = _stringValue(data['classTypeId']);
  final className = _stringValue(data['className']);
  final stableId =
      classTypeId ??
      (className == null
          ? 'class-session'
          : _classTypeIdForClassName(className));
  return _ensureSingleStandardSuffix(stableId);
}

String _normalizeRepeatedStandardSuffix(String value) {
  return value.replaceFirst(RegExp(r'(?:-standard){2,}$'), '-standard');
}

String _ensureSingleStandardSuffix(String value) {
  final normalized = _normalizeRepeatedStandardSuffix(value);
  return normalized.endsWith('-standard') ? normalized : '$normalized-standard';
}

Map<String, Object?> migrationResourceBackfill(Map<String, dynamic> data) {
  return migrationResourcePlan(data).updates;
}

ResourceMigrationPlan migrationResourcePlan(Map<String, dynamic> data) {
  final currentCategory = _stringValue(data['category']);
  final legacyCategory =
      currentCategory == 'forms' || currentCategory == 'events';
  return ResourceMigrationPlan(
    updates: {
      if (!data.containsKey('resourceSection')) 'resourceSection': 'general',
      if (!data.containsKey('isArchived')) 'isArchived': false,
      if (legacyCategory) 'category': 'general',
    },
    deleteResourceType: data.containsKey('resourceType'),
    normalizesLegacyCategory: legacyCategory,
  );
}

Map<String, Object?> migrationLocationBackfill(Map<String, dynamic> data) {
  return {
    if (!data.containsKey('name')) 'name': 'OTA Cheshire',
    if (!data.containsKey('timeZoneId')) 'timeZoneId': 'America/New_York',
    if (!data.containsKey('isActive')) 'isActive': true,
    if (!data.containsKey('createdAt'))
      'createdAt': FieldValue.serverTimestamp(),
    if (!data.containsKey('updatedAt'))
      'updatedAt': FieldValue.serverTimestamp(),
  };
}

const requiredLocationAddressFieldNames = <String>{
  'addressLine1',
  'city',
  'state',
  'postalCode',
  'country',
};

Set<String> missingLocationAddressFields(Map<String, dynamic> data) {
  return {
    for (final field in requiredLocationAddressFieldNames)
      if (_stringValue(data[field]) == null) field,
  };
}

const migrationDeleteField = _MigrationDeleteField();

class _MigrationDeleteField {
  const _MigrationDeleteField();
}

Map<String, Object?> migrationUserBackfill(Map<String, dynamic> data) {
  final updates = <String, Object?>{};
  final displayName = _stringValue(data['displayName']);
  final firstName = _stringValue(data['firstName']);
  final lastName = _stringValue(data['lastName']);
  if ((firstName == null || lastName == null) && displayName != null) {
    final parts = displayName.split(RegExp(r'\s+'));
    if (firstName == null && parts.isNotEmpty) {
      updates['firstName'] = parts.first;
    }
    if (lastName == null && parts.length > 1) {
      updates['lastName'] = parts.skip(1).join(' ');
    }
  }
  final email = validNormalizedEmail(data['email']);
  if (email != null && data['email'] != email) updates['email'] = email;
  if (data.containsKey('phoneNumber')) {
    final phone = _stringValue(data['phoneNumber']);
    if (phone == null) {
      updates['phoneNumber'] = migrationDeleteField;
    } else if (data['phoneNumber'] != phone) {
      updates['phoneNumber'] = phone;
    }
  }
  final googleAccountId = _stringValue(data['googleAccountId']);
  if (data.containsKey('googleAccountId')) {
    if (googleAccountId == null) {
      updates['googleAccountId'] = migrationDeleteField;
    } else if (data['googleAccountId'] != googleAccountId) {
      updates['googleAccountId'] = googleAccountId;
    }
  }
  if (!data.containsKey('linkedStudentProfileIds')) {
    updates['linkedStudentProfileIds'] = <String>[];
  }
  if (!data.containsKey('createdAt')) {
    updates['createdAt'] = FieldValue.serverTimestamp();
  }
  return updates;
}

String? validNormalizedEmail(Object? value) {
  final email = _stringValue(value)?.toLowerCase();
  if (email == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return null;
  }
  return email;
}

String? deriveGuardianEmail(
  String profileId,
  Map<String, dynamic> profile,
  Map<String, Map<String, dynamic>> usersById,
) {
  final existing = validNormalizedEmail(profile['guardianEmail']);
  if (existing != null) return existing;
  final guardianIds = _stringListValue(profile['guardianUserIds']).toSet();
  final candidates = <String>{};
  for (final entry in usersById.entries) {
    final user = entry.value;
    if (user['role'] != 'parent') continue;
    final linkedProfiles = _stringListValue(user['linkedStudentProfileIds']);
    final hasExplicitRelationship =
        guardianIds.contains(entry.key) || linkedProfiles.contains(profileId);
    if (!hasExplicitRelationship) continue;
    final email = validNormalizedEmail(user['email']);
    if (email != null) candidates.add(email);
  }
  return candidates.length == 1 ? candidates.single : null;
}

final _sampleStudentProfilesById = {
  for (final profile in sampleStudentProfiles) profile.id: profile,
};

String? _stringValue(Object? value) {
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

List<String> _preferredClassGroupIdsForBelt(String? belt) {
  return switch (belt) {
    'White' || 'White-Yellow' || 'Yellow' => ['level-1'],
    'Yellow-Green' || 'Green' || 'Green-Blue' => ['level-2'],
    'Blue' || 'Blue-Red' => ['level-3'],
    'Red' ||
    'Red-Yellow' ||
    'Red-Green' ||
    'Red-Blue' ||
    'Red-Black' => ['level-4'],
    'Black' => ['teen-adult'],
    _ => <String>[],
  };
}

String? _normalizeClassTypeId(String? classTypeId) {
  return switch (classTypeId) {
    'black-belt' || 'teen-black-belt' || 'adult' => 'teen-adult',
    'sparring-class' => 'level-1-2-sparring',
    _ => classTypeId,
  };
}

String _classTypeIdForClassName(String className) {
  final normalized = className.trim();
  return switch (normalized) {
    'Little Tiger (Age 3-5)' || 'Little Tiger' => 'little-tiger',
    'Level 1' => 'level-1',
    'Level 2' => 'level-2',
    'Level 3' => 'level-3',
    'Level 4' => 'level-4',
    'Black Belt' || 'Teen & Black Belt' || 'Adult' => 'teen-adult',
    'Teen/Adult Sparring' => 'teen-adult-sparring',
    'Level 1 / Level 2 Sparring' => 'level-1-2-sparring',
    _ => _slugForClassName(normalized),
  };
}

String _normalizeAnnouncementClassGroupId(String id) {
  return switch (id) {
    'black-belt' || 'teen-black-belt' || 'adult' => 'teen-adult',
    'sparring-class' => 'level-1-2-sparring',
    _ => id,
  };
}

String _slugForClassName(String className) {
  final slug = className
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'class-session' : slug;
}

bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

Map<String, Object?> _resourceData(AcademyResource resource) {
  return {
    'title': resource.title,
    'description': resource.description,
    'resourceSection': resource.resourceSection,
    'category': resource.category,
    'linkUrl': resource.linkUrl,
    'locationId': resource.locationId,
    'isPublished': resource.isPublished,
    'isArchived': resource.isArchived,
    'createdAt': Timestamp.fromDate(resource.createdAt),
    'updatedAt': Timestamp.fromDate(resource.updatedAt),
  };
}
