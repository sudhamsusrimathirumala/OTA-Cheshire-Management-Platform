import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/sample_resources.dart';
import '../../data/sample_student.dart';
import '../../models/academy_resource.dart';
import 'firestore_collections.dart';

class FirestoreMigrationService {
  FirestoreMigrationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> runMvpReadinessMigration() async {
    await addPreferredClassGroupIdsToStudentProfiles();
    await normalizeClassSessionClassTypeIds();
    await normalizeAnnouncements();
    await backfillEventFields();
    await backfillResourceFields();
    await createStarterResourcesIfMissing();
  }

  Future<void> addPreferredClassGroupIdsToStudentProfiles() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.studentProfiles)
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

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
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> normalizeClassSessionClassTypeIds() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.classSessions)
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

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
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> normalizeAnnouncements() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.announcements)
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

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
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> backfillEventFields() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.events)
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

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
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> backfillResourceFields() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.resources)
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

    for (final document in snapshot.docs) {
      final data = document.data();
      if (data.containsKey('isArchived')) {
        continue;
      }

      batch.set(document.reference, {
        'isArchived': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> createStarterResourcesIfMissing() async {
    final batch = _firestore.batch();
    var hasWrites = false;

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
        if (updates.isNotEmpty) {
          updates['updatedAt'] = FieldValue.serverTimestamp();
          batch.set(reference, updates, SetOptions(merge: true));
          hasWrites = true;
        }
        continue;
      }

      batch.set(reference, _resourceData(resource), SetOptions(merge: true));
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }
  }
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
    'Black Belt' ||
    'Teen & Black Belt' ||
    'Adult' ||
    'Teen/Adult Sparring' => 'teen-adult',
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
