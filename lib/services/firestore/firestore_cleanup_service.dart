import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_admin_write_service.dart';
import 'firestore_audit_service.dart';
import 'firestore_collections.dart';

const String otaFirestoreProjectId = 'ota-management-platform';

typedef FirestoreCleanupAffectedDocumentsReader =
    Future<FirestoreCollectionMap> Function(FirestoreCleanupPlan plan);
typedef FirestoreCleanupDocumentUpdater =
    Future<void> Function(
      String collection,
      String documentId,
      Map<String, Object?> fieldsToSet,
      List<String> fieldsToDelete,
    );
typedef FirestoreCleanupAuditRunner = Future<FirestoreAuditReport> Function();

enum FirestoreCleanupOperationType { updateFields, deleteFields }

enum FirestoreCleanupRiskLevel { low, medium, high }

enum GuardianRelationshipAction {
  replaceMissingGuardian,
  removeMissingGuardian,
  createKnownUserReference,
}

class GuardianRelationshipResolution {
  const GuardianRelationshipResolution({
    required this.action,
    required this.missingGuardianUserId,
    this.replacementUserId,
  });

  final GuardianRelationshipAction action;
  final String missingGuardianUserId;
  final String? replacementUserId;
}

const guardianRelationshipResolutions =
    <String, GuardianRelationshipResolution>{};

class FirestoreCleanupOperation {
  const FirestoreCleanupOperation({
    required this.collection,
    required this.documentId,
    required this.operationType,
    required this.fieldsToSet,
    required this.fieldsToDelete,
    required this.reason,
    required this.preconditions,
    required this.riskLevel,
  });

  final String collection;
  final String documentId;
  final FirestoreCleanupOperationType operationType;
  final Map<String, Object?> fieldsToSet;
  final List<String> fieldsToDelete;
  final String reason;
  final Map<String, Object?> preconditions;
  final FirestoreCleanupRiskLevel riskLevel;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentId': documentId,
    'operationType': operationType.name,
    'fieldsToSet': serializeFirestoreValue(fieldsToSet),
    'fieldsToDelete': fieldsToDelete,
    'reason': reason,
    'preconditions': serializeFirestoreValue(preconditions),
    'riskLevel': riskLevel.name,
  };
}

class FirestoreCleanupUnresolvedFinding {
  const FirestoreCleanupUnresolvedFinding({
    required this.collection,
    required this.documentId,
    required this.issueCode,
    required this.message,
    required this.recommendedAction,
  });

  final String collection;
  final String documentId;
  final String issueCode;
  final String message;
  final String recommendedAction;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentId': documentId,
    'issueCode': issueCode,
    'message': message,
    'recommendedAction': recommendedAction,
  };
}

class FirestoreCleanupWarning {
  const FirestoreCleanupWarning({
    required this.collection,
    required this.documentId,
    required this.code,
    required this.message,
    this.failedPlannedOperationPrecondition = false,
  });

  final String collection;
  final String documentId;
  final String code;
  final String message;
  final bool failedPlannedOperationPrecondition;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentId': documentId,
    'code': code,
    'message': message,
    'failedPlannedOperationPrecondition': failedPlannedOperationPrecondition,
  };
}

class FirestoreCleanupPlan {
  const FirestoreCleanupPlan({
    required this.projectId,
    required this.generatedAt,
    required this.operations,
    required this.unresolvedFindings,
    required this.warnings,
    this.sourceAuditIssueCount,
  });

  final String projectId;
  final DateTime generatedAt;
  final List<FirestoreCleanupOperation> operations;
  final List<FirestoreCleanupUnresolvedFinding> unresolvedFindings;
  final List<FirestoreCleanupWarning> warnings;
  final int? sourceAuditIssueCount;

  int get affectedDocumentCount => operations
      .map((operation) => '${operation.collection}/${operation.documentId}')
      .toSet()
      .length;

  int get fieldsToSetCount => operations.fold(
    0,
    (total, operation) => total + operation.fieldsToSet.length,
  );

  int get fieldsToDeleteCount => operations.fold(
    0,
    (total, operation) => total + operation.fieldsToDelete.length,
  );

  bool get hasFailedPlannedOperationPreconditions =>
      warnings.any((warning) => warning.failedPlannedOperationPrecondition);

  Map<String, List<FirestoreCleanupOperation>> get operationsByCollection {
    final grouped = <String, List<FirestoreCleanupOperation>>{};
    for (final operation in operations) {
      (grouped[operation.collection] ??= <FirestoreCleanupOperation>[]).add(
        operation,
      );
    }
    return grouped;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'projectId': projectId,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'dryRun': true,
    'supportsDocumentDeletion': false,
    'sourceAuditIssueCount': sourceAuditIssueCount,
    'affectedDocumentCount': affectedDocumentCount,
    'operationCount': operations.length,
    'fieldsToSetCount': fieldsToSetCount,
    'fieldsToDeleteCount': fieldsToDeleteCount,
    'operationsByCollection': <String, Object?>{
      for (final entry in operationsByCollection.entries)
        entry.key: entry.value.map((operation) => operation.toJson()).toList(),
    },
    'unresolvedFindings': unresolvedFindings
        .map((finding) => finding.toJson())
        .toList(),
    'warnings': warnings.map((warning) => warning.toJson()).toList(),
  };
}

class FirestoreCleanupResult {
  const FirestoreCleanupResult({
    required this.success,
    required this.startedAt,
    required this.completedAt,
    required this.affectedDocumentCount,
    required this.appliedOperationCount,
    required this.beforeIssueCount,
    this.afterIssueCount,
    this.failedCollection,
    this.failedDocumentId,
    this.errorMessage,
    this.remainingErrorsAndWarnings = const <FirestoreAuditIssue>[],
  });

  final bool success;
  final DateTime startedAt;
  final DateTime completedAt;
  final int affectedDocumentCount;
  final int appliedOperationCount;
  final int? beforeIssueCount;
  final int? afterIssueCount;
  final String? failedCollection;
  final String? failedDocumentId;
  final String? errorMessage;
  final List<FirestoreAuditIssue> remainingErrorsAndWarnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'success': success,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'affectedDocumentCount': affectedDocumentCount,
    'appliedOperationCount': appliedOperationCount,
    'beforeIssueCount': beforeIssueCount,
    'afterIssueCount': afterIssueCount,
    'failedCollection': failedCollection,
    'failedDocumentId': failedDocumentId,
    'errorMessage': errorMessage,
    'remainingErrorsAndWarnings': remainingErrorsAndWarnings
        .map((issue) => issue.toJson())
        .toList(),
  };
}

class FirestoreCleanupService {
  FirestoreCleanupService({
    this.firestore,
    this.projectId = otaFirestoreProjectId,
    this.affectedDocumentsReader,
    this.documentUpdater,
    this.auditRunner,
  });

  final FirebaseFirestore? firestore;
  final String projectId;
  final FirestoreCleanupAffectedDocumentsReader? affectedDocumentsReader;
  final FirestoreCleanupDocumentUpdater? documentUpdater;
  final FirestoreCleanupAuditRunner? auditRunner;

  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

  Future<FirestoreCleanupPlan> generatePlan() async {
    final documents = await _readPlanningCollections();
    final audit = auditFirestoreDocuments(documents);
    return generateFirestoreCleanupPlan(
      documents,
      projectId: projectId,
      sourceAuditIssueCount: audit.totalIssueCount,
    );
  }

  Future<FirestoreCleanupResult> applyPlan(
    FirestoreCleanupPlan plan, {
    required bool enableApply,
    required String confirmationText,
    required String requiredConfirmationText,
  }) async {
    if (!enableApply) {
      throw StateError('Firestore cleanup apply mode is disabled.');
    }
    if (!isFirestoreCleanupConfirmationValid(
      confirmationText,
      requiredConfirmationText: requiredConfirmationText,
    )) {
      throw StateError('Firestore cleanup confirmation text does not match.');
    }
    if (plan.projectId != projectId) {
      throw StateError('Cleanup plan project ID does not match $projectId.');
    }
    if (plan.operations.isEmpty) {
      throw StateError('Cleanup plan contains no operations.');
    }
    if (plan.hasFailedPlannedOperationPreconditions) {
      throw StateError('Cleanup plan has failed operation preconditions.');
    }

    final current = await _readAffectedDocuments(plan);
    for (final operation in plan.operations) {
      final document = current[operation.collection]?[operation.documentId];
      if (document == null || !_preconditionsMatch(operation, document)) {
        throw StateError(
          'Precondition failed for '
          '${operation.collection}/${operation.documentId}.',
        );
      }
    }

    final startedAt = DateTime.now().toUtc();
    var appliedOperationCount = 0;
    final grouped = _groupOperationsByDocument(plan.operations);
    for (final entry in grouped.entries) {
      final separator = entry.key.indexOf('/');
      final collection = entry.key.substring(0, separator);
      final documentId = entry.key.substring(separator + 1);
      final fieldsToSet = <String, Object?>{};
      final fieldsToDelete = <String>[];
      for (final operation in entry.value) {
        fieldsToSet.addAll(operation.fieldsToSet);
        fieldsToDelete.addAll(operation.fieldsToDelete);
      }
      try {
        await _applyTargetedUpdate(
          collection,
          documentId,
          fieldsToSet,
          fieldsToDelete.toSet().toList(),
        );
        appliedOperationCount += entry.value.length;
      } catch (error) {
        return FirestoreCleanupResult(
          success: false,
          startedAt: startedAt,
          completedAt: DateTime.now().toUtc(),
          affectedDocumentCount: plan.affectedDocumentCount,
          appliedOperationCount: appliedOperationCount,
          beforeIssueCount: plan.sourceAuditIssueCount,
          failedCollection: collection,
          failedDocumentId: documentId,
          errorMessage: error.toString(),
        );
      }
    }

    final afterAudit = await _runPostCleanupAudit();
    final remaining = afterAudit.collections
        .expand((collection) => collection.issues)
        .where(
          (issue) =>
              issue.severity == FirestoreAuditSeverity.error ||
              issue.severity == FirestoreAuditSeverity.warning,
        )
        .toList();
    return FirestoreCleanupResult(
      success: true,
      startedAt: startedAt,
      completedAt: DateTime.now().toUtc(),
      affectedDocumentCount: plan.affectedDocumentCount,
      appliedOperationCount: appliedOperationCount,
      beforeIssueCount: plan.sourceAuditIssueCount,
      afterIssueCount: afterAudit.totalIssueCount,
      remainingErrorsAndWarnings: remaining,
    );
  }

  Future<FirestoreCollectionMap> _readPlanningCollections() async {
    const names = <String>[
      FirestoreCollections.locations,
      FirestoreCollections.users,
      FirestoreCollections.studentProfiles,
      FirestoreCollections.classSessions,
      FirestoreCollections.announcements,
      FirestoreCollections.events,
      FirestoreCollections.resources,
    ];
    final snapshots = await Future.wait(
      names.map((name) => _database.collection(name).get()),
    );
    return <String, FirestoreDocumentMap>{
      for (var index = 0; index < names.length; index += 1)
        names[index]: <String, Map<String, Object?>>{
          for (final document in snapshots[index].docs)
            document.id: Map<String, Object?>.from(document.data()),
        },
    };
  }

  Future<FirestoreCollectionMap> _readAffectedDocuments(
    FirestoreCleanupPlan plan,
  ) async {
    final reader = affectedDocumentsReader;
    if (reader != null) return reader(plan);
    final documents = <String, FirestoreDocumentMap>{};
    final keys = plan.operations
        .map((operation) => '${operation.collection}/${operation.documentId}')
        .toSet();
    for (final key in keys) {
      final separator = key.indexOf('/');
      final collection = key.substring(0, separator);
      final documentId = key.substring(separator + 1);
      final snapshot = await _database
          .collection(collection)
          .doc(documentId)
          .get();
      final data = snapshot.data();
      if (data == null) {
        throw StateError('Affected document $key no longer exists.');
      }
      (documents[collection] ??= <String, Map<String, Object?>>{})[documentId] =
          Map<String, Object?>.from(data);
    }
    return documents;
  }

  Future<void> _applyTargetedUpdate(
    String collection,
    String documentId,
    Map<String, Object?> fieldsToSet,
    List<String> fieldsToDelete,
  ) async {
    final updater = documentUpdater;
    if (updater != null) {
      await updater(collection, documentId, fieldsToSet, fieldsToDelete);
      return;
    }
    final update = <String, Object?>{...fieldsToSet};
    for (final field in fieldsToDelete) {
      update[field] = FieldValue.delete();
    }
    // A one-document batch stays safely below Firestore's platform limit and
    // allows an exact failed document to be reported.
    final batch = _database.batch();
    batch.update(_database.collection(collection).doc(documentId), update);
    await batch.commit();
  }

  Future<FirestoreAuditReport> _runPostCleanupAudit() {
    final runner = auditRunner;
    if (runner != null) return runner();
    return FirestoreAuditService(firestore: _database).run();
  }
}

FirestoreCleanupPlan generateFirestoreCleanupPlan(
  FirestoreCollectionMap collections, {
  String projectId = otaFirestoreProjectId,
  DateTime? generatedAt,
  int? sourceAuditIssueCount,
}) {
  final operations = <FirestoreCleanupOperation>[];
  final unresolved = <FirestoreCleanupUnresolvedFinding>[];
  final warnings = <FirestoreCleanupWarning>[];
  final sessions = collections[FirestoreCollections.classSessions] ?? {};
  final resources = collections[FirestoreCollections.resources] ?? {};
  final profiles = collections[FirestoreCollections.studentProfiles] ?? {};
  final users = collections[FirestoreCollections.users] ?? {};
  final events = collections[FirestoreCollections.events] ?? {};
  final announcements = collections[FirestoreCollections.announcements] ?? {};

  for (final entry in sessions.entries) {
    _planClassSession(entry.key, entry.value, operations, warnings);
  }
  for (final entry in resources.entries) {
    _planResource(entry.key, entry.value, operations);
  }
  for (final entry in profiles.entries) {
    _planStudentProfile(entry.key, entry.value, operations);
  }
  _addUnresolvedRelationships(profiles, users, unresolved);
  _addContentAndEventUnresolved(resources, events, announcements, unresolved);

  operations.sort(_compareOperations);
  unresolved.sort((a, b) {
    final collection = a.collection.compareTo(b.collection);
    return collection != 0 ? collection : a.documentId.compareTo(b.documentId);
  });
  return FirestoreCleanupPlan(
    projectId: projectId,
    generatedAt: generatedAt ?? DateTime.now().toUtc(),
    operations: List.unmodifiable(operations),
    unresolvedFindings: List.unmodifiable(unresolved),
    warnings: List.unmodifiable(warnings),
    sourceAuditIssueCount: sourceAuditIssueCount,
  );
}

FirestoreCollectionMap simulateFirestoreCleanup(
  FirestoreCollectionMap source,
  FirestoreCleanupPlan plan,
) {
  final result = <String, FirestoreDocumentMap>{
    for (final collection in source.entries)
      collection.key: <String, Map<String, Object?>>{
        for (final document in collection.value.entries)
          document.key: _deepCloneMap(document.value),
      },
  };
  final applicable = plan.operations.where((operation) {
    final original = source[operation.collection]?[operation.documentId];
    return original != null && _preconditionsMatch(operation, original);
  }).toList();
  for (final operation in applicable) {
    final document = result[operation.collection]![operation.documentId]!;
    document.addAll(operation.fieldsToSet);
    for (final field in operation.fieldsToDelete) {
      document.remove(field);
    }
  }
  return result;
}

bool isFirestoreCleanupConfirmationValid(
  String value, {
  required String requiredConfirmationText,
}) => value == requiredConfirmationText;

Object? serializeFirestoreValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Timestamp) {
    return <String, Object?>{
      '__type': 'Timestamp',
      'seconds': value.seconds,
      'nanoseconds': value.nanoseconds,
    };
  }
  if (value is DateTime) {
    return <String, Object?>{
      '__type': 'DateTime',
      'value': value.toUtc().toIso8601String(),
    };
  }
  if (value is GeoPoint) {
    return <String, Object?>{
      '__type': 'GeoPoint',
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  }
  if (value is DocumentReference) {
    return <String, Object?>{'__type': 'DocumentReference', 'path': value.path};
  }
  if (value is Iterable) {
    return value.map(serializeFirestoreValue).toList();
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): serializeFirestoreValue(entry.value),
    };
  }
  throw FormatException(
    'Unsupported Firestore value type: ${value.runtimeType}.',
  );
}

void _planClassSession(
  String id,
  Map<String, Object?> data,
  List<FirestoreCleanupOperation> operations,
  List<FirestoreCleanupWarning> warnings,
) {
  final failed = <String>[];
  final weekday = data['weekday'];
  final start = data['startMinutes'];
  final end = data['endMinutes'];
  if (weekday is! int || weekday < 1 || weekday > 7) failed.add('weekday');
  if (start is! int || start < 0 || start > 1439) {
    failed.add('startMinutes');
  }
  if (end is! int || end < 0 || end > 1439) failed.add('endMinutes');
  if (start is int && end is int && end <= start) failed.add('timeRange');
  for (final field in const ['locationId', 'classTypeId', 'bulkGroupId']) {
    if (_nonEmptyString(data[field]) == null) failed.add(field);
  }
  final cleanupFieldsPresent = const [
    'startTime',
    'endTime',
    'eligibilityNote',
    'resumesOn',
  ].any(data.containsKey);
  if (failed.isNotEmpty) {
    if (cleanupFieldsPresent) {
      warnings.add(
        FirestoreCleanupWarning(
          collection: FirestoreCollections.classSessions,
          documentId: id,
          code: 'class_session_cleanup_precondition_failed',
          message:
              'Skipped deterministic cleanup because these canonical '
              'preconditions failed: ${failed.join(', ')}.',
        ),
      );
    }
    return;
  }

  final fieldsToDelete = <String>[
    if (data.containsKey('startTime')) 'startTime',
    if (data.containsKey('endTime')) 'endTime',
    if (data.containsKey('eligibilityNote') && data['eligibilityNote'] == null)
      'eligibilityNote',
    if (data.containsKey('resumesOn') && data['resumesOn'] == null) 'resumesOn',
  ];
  if (fieldsToDelete.isEmpty) return;
  operations.add(
    FirestoreCleanupOperation(
      collection: FirestoreCollections.classSessions,
      documentId: id,
      operationType: FirestoreCleanupOperationType.deleteFields,
      fieldsToSet: const <String, Object?>{},
      fieldsToDelete: fieldsToDelete,
      reason: 'Remove validated legacy schedule and null optional fields.',
      preconditions: _preconditionsFor(data, const [
        'weekday',
        'startMinutes',
        'endMinutes',
        'locationId',
        'classTypeId',
        'bulkGroupId',
        'startTime',
        'endTime',
        'eligibilityNote',
        'resumesOn',
      ]),
      riskLevel: FirestoreCleanupRiskLevel.low,
    ),
  );
}

void _planResource(
  String id,
  Map<String, Object?> data,
  List<FirestoreCleanupOperation> operations,
) {
  final fieldsToSet = <String, Object?>{};
  final fieldsToDelete = <String>[];
  if (data['resourceSection'] != 'general') {
    fieldsToSet['resourceSection'] = 'general';
  }
  final category = _nonEmptyString(data['category']);
  if (category != null) {
    final normalized = normalizeResourceCategory(category);
    if (normalized != category) fieldsToSet['category'] = normalized;
  }
  final hasUrl = data.containsKey('url');
  final url = _nonEmptyString(data['url']);
  final linkUrl = _nonEmptyString(data['linkUrl']);
  if (hasUrl && data['url'] == null) {
    fieldsToDelete.add('url');
  } else if (url != null) {
    if (linkUrl == null) fieldsToSet['linkUrl'] = url;
    fieldsToDelete.add('url');
  }
  if (data.containsKey('linkUrl') && data['linkUrl'] == null) {
    fieldsToDelete.add('linkUrl');
  }

  final preconditions = _preconditionsFor(data, const [
    'resourceSection',
    'category',
    'url',
    'linkUrl',
  ]);
  if (fieldsToSet.isNotEmpty) {
    operations.add(
      FirestoreCleanupOperation(
        collection: FirestoreCollections.resources,
        documentId: id,
        operationType: FirestoreCleanupOperationType.updateFields,
        fieldsToSet: fieldsToSet,
        fieldsToDelete: const <String>[],
        reason: 'Apply deterministic canonical resource field values.',
        preconditions: preconditions,
        riskLevel: FirestoreCleanupRiskLevel.low,
      ),
    );
  }
  if (fieldsToDelete.isNotEmpty) {
    operations.add(
      FirestoreCleanupOperation(
        collection: FirestoreCollections.resources,
        documentId: id,
        operationType: FirestoreCleanupOperationType.deleteFields,
        fieldsToSet: const <String, Object?>{},
        fieldsToDelete: fieldsToDelete.toSet().toList()..sort(),
        reason: 'Remove deterministic legacy or explicitly-null URL fields.',
        preconditions: preconditions,
        riskLevel: FirestoreCleanupRiskLevel.low,
      ),
    );
  }
}

void _planStudentProfile(
  String id,
  Map<String, Object?> data,
  List<FirestoreCleanupOperation> operations,
) {
  if (!data.containsKey('selfUserId') || data['selfUserId'] != null) return;
  operations.add(
    FirestoreCleanupOperation(
      collection: FirestoreCollections.studentProfiles,
      documentId: id,
      operationType: FirestoreCleanupOperationType.deleteFields,
      fieldsToSet: const <String, Object?>{},
      fieldsToDelete: const ['selfUserId'],
      reason: 'Remove an explicitly-null optional self user reference.',
      preconditions: _preconditionsFor(data, const ['selfUserId']),
      riskLevel: FirestoreCleanupRiskLevel.low,
    ),
  );
}

void _addUnresolvedRelationships(
  FirestoreDocumentMap profiles,
  FirestoreDocumentMap users,
  List<FirestoreCleanupUnresolvedFinding> unresolved,
) {
  for (final id in const ['student_aarav', 'student_elena', 'student_maya']) {
    final profile = profiles[id];
    if (profile == null) continue;
    final missing = _stringList(
      profile['guardianUserIds'],
    ).where((userId) => !users.containsKey(userId));
    if (missing.isEmpty) continue;
    unresolved.add(
      FirestoreCleanupUnresolvedFinding(
        collection: FirestoreCollections.studentProfiles,
        documentId: id,
        issueCode: 'student_profile.missing_guardian_requires_approval',
        message: 'One or more guardian user references do not resolve.',
        recommendedAction:
            'Approve an explicit guardianRelationshipResolutions entry later.',
      ),
    );
  }
}

void _addContentAndEventUnresolved(
  FirestoreDocumentMap resources,
  FirestoreDocumentMap events,
  FirestoreDocumentMap announcements,
  List<FirestoreCleanupUnresolvedFinding> unresolved,
) {
  for (final id in const ['belt_testing_checklist', 'student_handbook']) {
    if (resources.containsKey(id)) {
      unresolved.add(
        FirestoreCleanupUnresolvedFinding(
          collection: FirestoreCollections.resources,
          documentId: id,
          issueCode: 'resource.placeholder_description_requires_review',
          message: 'The description remains flagged as placeholder content.',
          recommendedAction: 'Review and approve replacement content manually.',
        ),
      );
    }
  }
  if (resources.containsKey('parent_night_out_registration')) {
    unresolved.add(
      const FirestoreCleanupUnresolvedFinding(
        collection: FirestoreCollections.resources,
        documentId: 'parent_night_out_registration',
        issueCode: 'resource.placeholder_url_requires_review',
        message: 'The placeholder-looking URL is intentionally preserved.',
        recommendedAction: 'Review and approve a real URL manually.',
      ),
    );
  }
  if (announcements.containsKey('curriculum_videos_available')) {
    unresolved.add(
      const FirestoreCleanupUnresolvedFinding(
        collection: FirestoreCollections.announcements,
        documentId: 'curriculum_videos_available',
        issueCode: 'announcement.placeholder_content_requires_review',
        message: 'Placeholder-looking announcement content is preserved.',
        recommendedAction: 'Review and rewrite content manually if approved.',
      ),
    );
  }
  if (events.containsKey('fall_tournament')) {
    unresolved.add(
      const FirestoreCleanupUnresolvedFinding(
        collection: FirestoreCollections.events,
        documentId: 'fall_tournament',
        issueCode: 'event.resource_relationship_requires_approval',
        message:
            'The event has a registration URL but no resource relationship.',
        recommendedAction: 'Approve a specific General Resource relationship.',
      ),
    );
  }
}

Map<String, Object?> _preconditionsFor(
  Map<String, Object?> data,
  List<String> fields,
) {
  return <String, Object?>{
    '__documentFingerprint': _documentFingerprint(data),
    for (final field in fields) ...{
      '$field.__present': data.containsKey(field),
      if (data.containsKey(field)) field: data[field],
    },
  };
}

bool _preconditionsMatch(
  FirestoreCleanupOperation operation,
  Map<String, Object?> current,
) {
  for (final entry in operation.preconditions.entries) {
    if (entry.key == '__documentFingerprint') {
      if (_documentFingerprint(current) != entry.value) return false;
    } else if (entry.key.endsWith('.__present')) {
      final field = entry.key.substring(0, entry.key.length - 10);
      if (current.containsKey(field) != entry.value) return false;
    } else if (_canonicalValue(current[entry.key]) !=
        _canonicalValue(entry.value)) {
      return false;
    }
  }
  return true;
}

String _documentFingerprint(Map<String, Object?> document) {
  final canonical = _canonicalValue(document);
  var first = 0x811c9dc5;
  var second = 0x9e3779b9;
  for (final codeUnit in canonical.codeUnits) {
    first = ((first ^ codeUnit) * 0x01000193) & 0xffffffff;
    second = ((second ^ codeUnit) * 0x85ebca6b) & 0xffffffff;
  }
  return '${canonical.length}:'
      '${first.toRadixString(16).padLeft(8, '0')}:'
      '${second.toRadixString(16).padLeft(8, '0')}';
}

String _canonicalValue(Object? value) =>
    jsonEncode(_sortSerializedValue(serializeFirestoreValue(value)));

Object? _sortSerializedValue(Object? value) {
  if (value is List) return value.map(_sortSerializedValue).toList();
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _sortSerializedValue(value[key]),
    };
  }
  return value;
}

Map<String, List<FirestoreCleanupOperation>> _groupOperationsByDocument(
  List<FirestoreCleanupOperation> operations,
) {
  final grouped = <String, List<FirestoreCleanupOperation>>{};
  for (final operation in operations) {
    final key = '${operation.collection}/${operation.documentId}';
    (grouped[key] ??= <FirestoreCleanupOperation>[]).add(operation);
  }
  return grouped;
}

int _compareOperations(
  FirestoreCleanupOperation a,
  FirestoreCleanupOperation b,
) {
  final collection = a.collection.compareTo(b.collection);
  if (collection != 0) return collection;
  final document = a.documentId.compareTo(b.documentId);
  if (document != 0) return document;
  return a.operationType.index.compareTo(b.operationType.index);
}

Map<String, Object?> _deepCloneMap(Map<String, Object?> source) =>
    <String, Object?>{
      for (final entry in source.entries) entry.key: _deepClone(entry.value),
    };

Object? _deepClone(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _deepClone(entry.value),
    };
  }
  if (value is List) return value.map(_deepClone).toList();
  return value;
}

String? _nonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().where((item) => item.trim().isNotEmpty).toList()
    : const <String>[];
