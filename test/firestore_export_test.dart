import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_export_service.dart';

void main() {
  test('exports exactly the seven approved collections', () {
    expect(FirestoreExportService.collectionNames, [
      'locations',
      'users',
      'studentProfiles',
      'classSessions',
      'announcements',
      'events',
      'resources',
    ]);
  });

  test('serializes nested Firestore values without omitting nulls', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 7, 12, 14, 5, 18));
    final serialized =
        serializeFirestoreExportValue(<String, Object?>{
              'timestamp': timestamp,
              'point': const GeoPoint(41.5, -72.9),
              'nullable': null,
              'nested': <String, Object?>{
                'array': <Object?>[1, true, null, timestamp],
              },
            })!
            as Map<String, Object?>;

    expect(serialized, containsPair('nullable', null));
    expect(serialized['timestamp'], {
      '_type': 'Timestamp',
      'value': '2026-07-12T14:05:18.000Z',
    });
    expect(serialized['point'], {
      '_type': 'GeoPoint',
      'latitude': 41.5,
      'longitude': -72.9,
    });
    final nested = serialized['nested']! as Map<String, Object?>;
    expect(nested['array'], hasLength(4));
    expect((nested['array']! as List)[2], isNull);
  });

  test('uses document IDs as JSON object keys and reports counts', () {
    final export = FirestoreDatabaseExport(
      exportedAt: DateTime.utc(2026, 7, 12),
      projectId: 'ota-management-platform',
      collections: <String, Map<String, Map<String, Object?>>>{
        'locations': <String, Map<String, Object?>>{
          'ota-cheshire': <String, Object?>{'name': 'OTA Cheshire'},
        },
        'users': <String, Map<String, Object?>>{
          'user-1': <String, Object?>{'displayName': 'User'},
        },
      },
    );

    final json = jsonDecode(export.toPrettyJson()) as Map<String, Object?>;
    final collections = json['collections']! as Map<String, Object?>;
    expect(
      collections['locations'],
      containsPair('ota-cheshire', <String, Object?>{'name': 'OTA Cheshire'}),
    );
    expect(export.documentCount, 2);
    expect(export.collectionCounts, {'locations': 1, 'users': 1});
  });
}
