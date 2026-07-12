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
    final studentProfilesUpdated =
        await addPreferredClassGroupIdsToStudentProfiles();
    final classTypeIdsNormalized = await normalizeClassSessionClassTypeIds();
    final bulkGroupResult = await backfillClassSessionBulkGroupIds();
    final announcementsUpdated = await normalizeAnnouncements();
    final eventsUpdated = await backfillEventFields();
    final resourcesUpdated = await backfillResourceFields();
    final locationsUpdated = await ensureOtaCheshireLocation();
    final starterResourcesCreated = await createStarterResourcesIfMissing();
    final result = FirestoreMigrationResult(
      studentProfilesUpdated: studentProfilesUpdated,
      classTypeIdsNormalized: classTypeIdsNormalized,
      bulkGroupIdsAdded: bulkGroupResult.added,
      bulkGroupIdsRepaired: bulkGroupResult.repaired,
      announcementsUpdated: announcementsUpdated,
      eventsUpdated: eventsUpdated,
      resourcesUpdated: resourcesUpdated,
      locationsUpdated: locationsUpdated,
      starterResourcesCreated: starterResourcesCreated,
    );
    debugPrint(result.logSummary);
    return result;
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

  Future<int> backfillResourceFields() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.resources)
        .get();

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      final updates = migrationResourceBackfill(data);
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

  Future<int> ensureOtaCheshireLocation() async {
    final reference = _firestore
        .collection(FirestoreCollections.locations)
        .doc('ota-cheshire');
    final snapshot = await reference.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final updates = migrationLocationBackfill(data);
    if (updates.isNotEmpty) {
      await reference.set(updates, SetOptions(merge: true));
      return 1;
    }
    return 0;
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
    required this.classTypeIdsNormalized,
    required this.bulkGroupIdsAdded,
    required this.bulkGroupIdsRepaired,
    required this.announcementsUpdated,
    required this.eventsUpdated,
    required this.resourcesUpdated,
    required this.locationsUpdated,
    required this.starterResourcesCreated,
  });

  final int studentProfilesUpdated;
  final int classTypeIdsNormalized;
  final int bulkGroupIdsAdded;
  final int bulkGroupIdsRepaired;
  final int announcementsUpdated;
  final int eventsUpdated;
  final int resourcesUpdated;
  final int locationsUpdated;
  final int starterResourcesCreated;

  String get logSummary =>
      'Firestore migration complete: '
      'student profiles updated=$studentProfilesUpdated, '
      'class type IDs normalized=$classTypeIdsNormalized, '
      'bulk group IDs added=$bulkGroupIdsAdded, '
      'bulk group IDs repaired=$bulkGroupIdsRepaired, '
      'announcements updated=$announcementsUpdated, '
      'events updated=$eventsUpdated, '
      'resources updated=$resourcesUpdated, '
      'locations created or backfilled=$locationsUpdated, '
      'starter resources created=$starterResourcesCreated.';

  String get displaySummary =>
      'Migration complete.\n'
      'Student profiles updated: $studentProfilesUpdated\n'
      'Class type IDs normalized: $classTypeIdsNormalized\n'
      'Bulk group IDs added: $bulkGroupIdsAdded\n'
      'Bulk group IDs repaired: $bulkGroupIdsRepaired\n'
      'Announcements updated: $announcementsUpdated\n'
      'Events updated: $eventsUpdated\n'
      'Resources updated: $resourcesUpdated\n'
      'Locations created or backfilled: $locationsUpdated\n'
      'Starter resources created: $starterResourcesCreated';
}

class BulkGroupMigrationResult {
  const BulkGroupMigrationResult({required this.added, required this.repaired});

  final int added;
  final int repaired;
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
  return {
    if (!data.containsKey('resourceSection')) 'resourceSection': 'general',
    if (!data.containsKey('isArchived')) 'isArchived': false,
  };
}

Map<String, Object?> migrationLocationBackfill(Map<String, dynamic> data) {
  return {
    if (!data.containsKey('name')) 'name': 'OTA Cheshire',
    if (!data.containsKey('timeZoneId')) 'timeZoneId': 'America/New_York',
    if (!data.containsKey('isActive')) 'isActive': true,
  };
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
    'resourceType': resource.resourceType,
    'category': resource.category,
    'linkUrl': resource.linkUrl,
    'locationId': resource.locationId,
    'isPublished': resource.isPublished,
    'isArchived': resource.isArchived,
    'createdAt': Timestamp.fromDate(resource.createdAt),
    'updatedAt': Timestamp.fromDate(resource.updatedAt),
  };
}
