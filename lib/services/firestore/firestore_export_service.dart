import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firestore_collections.dart';

class FirestoreDatabaseExport {
  const FirestoreDatabaseExport({
    required this.exportedAt,
    required this.projectId,
    required this.collections,
  });

  final DateTime exportedAt;
  final String projectId;
  final Map<String, Map<String, Map<String, Object?>>> collections;

  int get documentCount => collectionCounts.values.fold(0, (a, b) => a + b);

  Map<String, int> get collectionCounts => <String, int>{
    for (final entry in collections.entries) entry.key: entry.value.length,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'projectId': projectId,
    'collections': collections,
  };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class FirestoreExportService {
  FirestoreExportService({this.firestore, this.projectId});

  static const collectionNames = <String>[
    FirestoreCollections.locations,
    FirestoreCollections.users,
    FirestoreCollections.studentProfiles,
    FirestoreCollections.classSessions,
    FirestoreCollections.announcements,
    FirestoreCollections.events,
    FirestoreCollections.resources,
  ];

  final FirebaseFirestore? firestore;
  final String? projectId;

  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

  Future<FirestoreDatabaseExport> readDatabase() async {
    final snapshots = await Future.wait(
      collectionNames.map((name) => _database.collection(name).get()),
    );
    final collections = <String, Map<String, Map<String, Object?>>>{};
    for (var index = 0; index < collectionNames.length; index += 1) {
      collections[collectionNames[index]] = <String, Map<String, Object?>>{
        for (final document in snapshots[index].docs)
          document.id: <String, Object?>{
            for (final entry in document.data().entries)
              entry.key: serializeFirestoreExportValue(entry.value),
          },
      };
    }
    return FirestoreDatabaseExport(
      exportedAt: DateTime.now().toUtc(),
      projectId: projectId ?? Firebase.app().options.projectId,
      collections: collections,
    );
  }
}

Object? serializeFirestoreExportValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Timestamp) {
    return <String, Object?>{
      '_type': 'Timestamp',
      'value': value.toDate().toUtc().toIso8601String(),
    };
  }
  if (value is GeoPoint) {
    return <String, Object?>{
      '_type': 'GeoPoint',
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  }
  if (value is DocumentReference) {
    return <String, Object?>{'_type': 'DocumentReference', 'path': value.path};
  }
  if (value is Blob) {
    return <String, Object?>{
      '_type': 'Blob',
      'base64': base64Encode(value.bytes),
    };
  }
  if (value is DateTime) {
    return <String, Object?>{
      '_type': 'DateTime',
      'value': value.toUtc().toIso8601String(),
    };
  }
  if (value is Iterable) {
    return value.map(serializeFirestoreExportValue).toList();
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): serializeFirestoreExportValue(entry.value),
    };
  }
  throw FormatException(
    'Unsupported Firestore export value type: ${value.runtimeType}.',
  );
}
