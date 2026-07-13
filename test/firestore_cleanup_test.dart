import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/firestore_cleanup_main.dart'
    as cleanup_main;
import 'package:ota_cheshire_management_platform/services/firestore/firestore_audit_service.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_cleanup_service.dart';

void main() {
  group('class session cleanup planning', () {
    test('valid session plans deletion of legacy times', () {
      final plan = _plan(classSessions: {'session': _validClassSession()});
      final operation = _operation(plan, 'classSessions', 'session');
      expect(operation.fieldsToDelete, containsAll(['startTime', 'endTime']));
      expect(operation.fieldsToSet, isEmpty);
    });

    test('invalid session does not plan destructive deletion', () {
      final session = _validClassSession()..['weekday'] = 8;
      final plan = _plan(classSessions: {'session': session});
      expect(plan.operations, isEmpty);
      expect(plan.warnings, hasLength(1));
      expect(plan.warnings.single.failedPlannedOperationPrecondition, isFalse);
    });

    test('null eligibilityNote is deleted', () {
      final operation = _operation(
        _plan(classSessions: {'session': _validClassSession()}),
        'classSessions',
        'session',
      );
      expect(operation.fieldsToDelete, contains('eligibilityNote'));
    });

    test('non-null eligibilityNote is preserved', () {
      final session = _validClassSession()
        ..['eligibilityNote'] = 'Black belts only';
      final cleaned = simulateFirestoreCleanup(
        _collections(classSessions: {'session': session}),
        _plan(classSessions: {'session': session}),
      );
      expect(
        cleaned['classSessions']!['session']!['eligibilityNote'],
        'Black belts only',
      );
    });

    test('null resumesOn is deleted', () {
      final operation = _operation(
        _plan(classSessions: {'session': _validClassSession()}),
        'classSessions',
        'session',
      );
      expect(operation.fieldsToDelete, contains('resumesOn'));
    });

    test('non-null resumesOn is preserved', () {
      final resumesOn = Timestamp.fromDate(DateTime.utc(2026, 8, 1));
      final session = _validClassSession()..['resumesOn'] = resumesOn;
      final cleaned = simulateFirestoreCleanup(
        _collections(classSessions: {'session': session}),
        _plan(classSessions: {'session': session}),
      );
      expect(cleaned['classSessions']!['session']!['resumesOn'], resumesOn);
    });

    test('cleanup never changes schedule minutes or updatedAt', () {
      final updatedAt = Timestamp.fromDate(DateTime.utc(2026, 7, 1));
      final session = _validClassSession()..['updatedAt'] = updatedAt;
      final cleaned = simulateFirestoreCleanup(
        _collections(classSessions: {'session': session}),
        _plan(classSessions: {'session': session}),
      )['classSessions']!['session']!;
      expect(cleaned['startMinutes'], 600);
      expect(cleaned['endMinutes'], 660);
      expect(cleaned['updatedAt'], updatedAt);
    });
  });

  group('resource cleanup planning', () {
    test('legacy URL copies to linkUrl and deletes url', () {
      final plan = _plan(
        resources: {'resource': _resource(url: 'https://ota.example/register')},
      );
      final operations = _operations(plan, 'resources', 'resource');
      expect(
        operations.expand((operation) => operation.fieldsToDelete),
        contains('url'),
      );
      expect(
        operations
            .expand((operation) => operation.fieldsToSet.entries)
            .firstWhere((entry) => entry.key == 'linkUrl')
            .value,
        'https://ota.example/register',
      );
    });

    test('existing linkUrl is not overwritten', () {
      final plan = _plan(
        resources: {
          'resource': _resource(
            url: 'https://legacy.example/form',
            linkUrl: 'https://canonical.example/form',
          ),
        },
      );
      final cleaned = simulateFirestoreCleanup(
        _collections(
          resources: {
            'resource': _resource(
              url: 'https://legacy.example/form',
              linkUrl: 'https://canonical.example/form',
            ),
          },
        ),
        plan,
      );
      expect(
        cleaned['resources']!['resource']!['linkUrl'],
        'https://canonical.example/form',
      );
      expect(cleaned['resources']!['resource'], isNot(contains('url')));
    });

    test('null url is deleted', () {
      final resource = _resource()..['url'] = null;
      final cleaned = simulateFirestoreCleanup(
        _collections(resources: {'resource': resource}),
        _plan(resources: {'resource': resource}),
      );
      expect(cleaned['resources']!['resource'], isNot(contains('url')));
    });

    test('null linkUrl is deleted', () {
      final resource = _resource()..['linkUrl'] = null;
      final cleaned = simulateFirestoreCleanup(
        _collections(resources: {'resource': resource}),
        _plan(resources: {'resource': resource}),
      );
      expect(cleaned['resources']!['resource'], isNot(contains('linkUrl')));
    });

    test('beltTesting normalizes to testing', () {
      final resource = _resource()..['category'] = 'beltTesting';
      final cleaned = simulateFirestoreCleanup(
        _collections(resources: {'resource': resource}),
        _plan(resources: {'resource': resource}),
      );
      expect(cleaned['resources']!['resource']!['category'], 'testing');
    });

    test(
      'resource publication, archive, timestamps, and content are preserved',
      () {
        final createdAt = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
        final resource = _resource()
          ..['description'] = 'Placeholder description'
          ..['url'] = null
          ..['isPublished'] = true
          ..['isArchived'] = true
          ..['createdAt'] = createdAt;
        final cleaned = simulateFirestoreCleanup(
          _collections(resources: {'student_handbook': resource}),
          _plan(resources: {'student_handbook': resource}),
        )['resources']!['student_handbook']!;
        expect(cleaned['description'], 'Placeholder description');
        expect(cleaned['isPublished'], isTrue);
        expect(cleaned['isArchived'], isTrue);
        expect(cleaned['createdAt'], createdAt);
      },
    );
  });

  group('student, content, and relationship safety', () {
    test('null selfUserId is deleted', () {
      final profile = _profile()..['selfUserId'] = null;
      final cleaned = simulateFirestoreCleanup(
        _collections(studentProfiles: {'student': profile}),
        _plan(studentProfiles: {'student': profile}),
      );
      expect(
        cleaned['studentProfiles']!['student'],
        isNot(contains('selfUserId')),
      );
    });

    test('guardian references are not changed automatically', () {
      final profile = _profile()
        ..['selfUserId'] = null
        ..['guardianUserIds'] = <String>['missing-guardian'];
      final cleaned = simulateFirestoreCleanup(
        _collections(studentProfiles: {'student_aarav': profile}),
        _plan(studentProfiles: {'student_aarav': profile}),
      );
      expect(cleaned['studentProfiles']!['student_aarav']!['guardianUserIds'], [
        'missing-guardian',
      ]);
      expect(guardianRelationshipResolutions, isEmpty);
    });

    test('known missing guardians are separated as unresolved', () {
      final profile = _profile()
        ..['guardianUserIds'] = <String>['missing-guardian'];
      final plan = _plan(studentProfiles: {'student_aarav': profile});
      expect(
        plan.unresolvedFindings.map((finding) => finding.issueCode),
        contains('student_profile.missing_guardian_requires_approval'),
      );
      expect(
        plan.operations.expand((operation) => operation.fieldsToSet.keys),
        isNot(contains('guardianUserIds')),
      );
    });

    test('placeholder content is not changed', () {
      final resource = _resource()..['description'] = 'Placeholder description';
      final announcement = <String, Object?>{
        'title': 'Placeholder title',
        'body': 'Placeholder body',
      };
      final source = _collections(
        resources: {'belt_testing_checklist': resource},
        announcements: {'curriculum_videos_available': announcement},
      );
      final cleaned = simulateFirestoreCleanup(
        source,
        generateFirestoreCleanupPlan(source),
      );
      expect(
        cleaned['resources']!['belt_testing_checklist']!['description'],
        'Placeholder description',
      );
      expect(
        cleaned['announcements']!['curriculum_videos_available'],
        announcement,
      );
    });

    test('events are not automatically relinked or rewritten', () {
      final event = <String, Object?>{
        'registrationUrl': 'https://example.com/register',
        'showInResources': true,
        'linkedResourceIds': <String>[],
        'primaryRegistrationResourceId': null,
      };
      final plan = _plan(events: {'fall_tournament': event});
      expect(
        plan.operations.where((operation) => operation.collection == 'events'),
        isEmpty,
      );
      expect(
        plan.unresolvedFindings.map((finding) => finding.issueCode),
        contains('event.resource_relationship_requires_approval'),
      );
    });
  });

  group('determinism and safeguards', () {
    test('plan generation is deterministic and idempotent', () {
      final source = _collections(
        classSessions: {'session': _validClassSession()},
      );
      final generatedAt = DateTime.utc(2026, 7, 12);
      final first = generateFirestoreCleanupPlan(
        source,
        generatedAt: generatedAt,
      );
      final second = generateFirestoreCleanupPlan(
        source,
        generatedAt: generatedAt,
      );
      expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
    });

    test('same cleanup applied twice produces no second change', () {
      final source = _collections(
        classSessions: {'session': _validClassSession()},
      );
      final plan = generateFirestoreCleanupPlan(source);
      final first = simulateFirestoreCleanup(source, plan);
      final second = simulateFirestoreCleanup(first, plan);
      expect(
        jsonEncode(serializeFirestoreValue(second)),
        jsonEncode(serializeFirestoreValue(first)),
      );
      expect(generateFirestoreCleanupPlan(first).operations, isEmpty);
    });

    test('confirmation text must match exactly', () {
      expect(
        isFirestoreCleanupConfirmationValid(
          cleanup_main.requiredConfirmationText,
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        isTrue,
      );
      expect(
        isFirestoreCleanupConfirmationValid(
          'apply ota firestore cleanup',
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        isFalse,
      );
      expect(
        isFirestoreCleanupConfirmationValid(
          '${cleanup_main.requiredConfirmationText} ',
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        isFalse,
      );
    });

    test('no operation type supports document deletion', () {
      expect(FirestoreCleanupOperationType.values, hasLength(2));
      expect(FirestoreCleanupOperationType.values.map((value) => value.name), [
        'updateFields',
        'deleteFields',
      ]);
    });
  });

  group('direct apply safety', () {
    test('apply is blocked when flag is false', () async {
      final plan = _plan(classSessions: {'session': _validClassSession()});
      final service = _fakeApplyService(_validClassSession());
      await expectLater(
        service.applyPlan(
          plan,
          enableApply: false,
          confirmationText: cleanup_main.requiredConfirmationText,
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        throwsStateError,
      );
    });

    test('apply is blocked with wrong confirmation text', () async {
      final plan = _plan(classSessions: {'session': _validClassSession()});
      final service = _fakeApplyService(_validClassSession());
      await expectLater(
        service.applyPlan(
          plan,
          enableApply: true,
          confirmationText: 'WRONG',
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        throwsStateError,
      );
    });

    test('apply is blocked when a planned precondition failed', () async {
      final base = _plan(classSessions: {'session': _validClassSession()});
      final plan = FirestoreCleanupPlan(
        projectId: base.projectId,
        generatedAt: base.generatedAt,
        operations: base.operations,
        unresolvedFindings: base.unresolvedFindings,
        warnings: const [
          FirestoreCleanupWarning(
            collection: 'classSessions',
            documentId: 'session',
            code: 'failed',
            message: 'failed',
            failedPlannedOperationPrecondition: true,
          ),
        ],
      );
      await expectLater(
        _fakeApplyService(_validClassSession()).applyPlan(
          plan,
          enableApply: true,
          confirmationText: cleanup_main.requiredConfirmationText,
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        throwsStateError,
      );
    });

    test('apply is blocked when any document changed', () async {
      final original = _validClassSession();
      final changed = _validClassSession()..['description'] = 'Changed';
      final plan = _plan(classSessions: {'session': original});
      var writes = 0;
      final service = _fakeApplyService(changed, onWrite: () => writes += 1);
      await expectLater(
        service.applyPlan(
          plan,
          enableApply: true,
          confirmationText: cleanup_main.requiredConfirmationText,
          requiredConfirmationText: cleanup_main.requiredConfirmationText,
        ),
        throwsStateError,
      );
      expect(writes, 0);
    });

    test('apply succeeds without backup and reruns audit', () async {
      final original = _validClassSession();
      final plan = _plan(classSessions: {'session': original});
      var writes = 0;
      var audits = 0;
      final service = _fakeApplyService(
        original,
        onWrite: () => writes += 1,
        onAudit: () => audits += 1,
      );
      final result = await service.applyPlan(
        plan,
        enableApply: true,
        confirmationText: cleanup_main.requiredConfirmationText,
        requiredConfirmationText: cleanup_main.requiredConfirmationText,
      );
      expect(result.success, isTrue);
      expect(writes, 1);
      expect(audits, 1);
      expect(result.afterIssueCount, 0);
      expect(result.toJson(), isNot(contains('backupPath')));
    });
  });
}

FirestoreCleanupService _fakeApplyService(
  Map<String, Object?> currentDocument, {
  void Function()? onWrite,
  void Function()? onAudit,
}) {
  return FirestoreCleanupService(
    affectedDocumentsReader: (_) async => <String, FirestoreDocumentMap>{
      'classSessions': <String, Map<String, Object?>>{
        'session': Map<String, Object?>.from(currentDocument),
      },
    },
    documentUpdater: (_, _, _, _) async => onWrite?.call(),
    auditRunner: () async {
      onAudit?.call();
      return FirestoreAuditReport(
        generatedAt: DateTime.utc(2026, 7, 12),
        collections: const <CollectionAuditReport>[],
      );
    },
  );
}

FirestoreCleanupPlan _plan({
  Map<String, Map<String, Object?>> classSessions = const {},
  Map<String, Map<String, Object?>> resources = const {},
  Map<String, Map<String, Object?>> studentProfiles = const {},
  Map<String, Map<String, Object?>> users = const {},
  Map<String, Map<String, Object?>> events = const {},
  Map<String, Map<String, Object?>> announcements = const {},
}) => generateFirestoreCleanupPlan(
  _collections(
    classSessions: classSessions,
    resources: resources,
    studentProfiles: studentProfiles,
    users: users,
    events: events,
    announcements: announcements,
  ),
  generatedAt: DateTime.utc(2026, 7, 12),
);

FirestoreCollectionMap _collections({
  Map<String, Map<String, Object?>> classSessions = const {},
  Map<String, Map<String, Object?>> resources = const {},
  Map<String, Map<String, Object?>> studentProfiles = const {},
  Map<String, Map<String, Object?>> users = const {},
  Map<String, Map<String, Object?>> events = const {},
  Map<String, Map<String, Object?>> announcements = const {},
}) => <String, FirestoreDocumentMap>{
  'classSessions': classSessions,
  'resources': resources,
  'studentProfiles': studentProfiles,
  'users': users,
  'events': events,
  'announcements': announcements,
};

FirestoreCleanupOperation _operation(
  FirestoreCleanupPlan plan,
  String collection,
  String documentId,
) => _operations(plan, collection, documentId).single;

List<FirestoreCleanupOperation> _operations(
  FirestoreCleanupPlan plan,
  String collection,
  String documentId,
) => plan.operations
    .where(
      (operation) =>
          operation.collection == collection &&
          operation.documentId == documentId,
    )
    .toList();

Map<String, Object?> _validClassSession() => <String, Object?>{
  'className': 'Level 1',
  'classTypeId': 'level-1',
  'bulkGroupId': 'level-1-standard',
  'locationId': 'ota-cheshire',
  'weekday': 1,
  'startMinutes': 600,
  'endMinutes': 660,
  'startTime': Timestamp.fromDate(DateTime.utc(2026, 7, 13, 10)),
  'endTime': Timestamp.fromDate(DateTime.utc(2026, 7, 13, 11)),
  'eligibilityNote': null,
  'resumesOn': null,
  'eligibleBelts': <String>[],
  'description': 'Class',
  'isActive': true,
  'isPreferred': false,
};

Map<String, Object?> _resource({String? url, String? linkUrl}) =>
    <String, Object?>{
      'title': 'Resource',
      'description': 'Description',
      'resourceSection': 'general',
      'resourceType': 'document',
      'category': 'general',
      'locationId': 'ota-cheshire',
      'isPublished': false,
      'isArchived': false,
      'url': ?url,
      'linkUrl': ?linkUrl,
    };

Map<String, Object?> _profile() => <String, Object?>{
  'fullName': 'Student',
  'beltRank': 'White',
  'locationId': 'ota-cheshire',
  'guardianUserIds': <String>[],
  'preferredClassGroupIds': <String>[],
  'promotionHistory': <Object?>[],
  'testingNotes': <Object?>[],
  'stickerProgress': <String, Object?>{
    'current': 0,
    'required': 10,
    'nextRank': 'Yellow',
  },
  'age': 10,
};
