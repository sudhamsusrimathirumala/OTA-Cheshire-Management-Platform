import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../services/firebase/firebase_admin_write_service.dart';
import 'firestore_collections.dart';

enum FirestoreAuditSeverity { info, warning, error }

class FirestoreAuditIssue {
  const FirestoreAuditIssue({
    required this.collection,
    required this.documentId,
    required this.issueCode,
    required this.severity,
    required this.message,
    required this.recommendedAction,
  });

  final String collection;
  final String documentId;
  final String issueCode;
  final FirestoreAuditSeverity severity;
  final String message;
  final String recommendedAction;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentId': documentId,
    'issueCode': issueCode,
    'severity': severity.name,
    'message': message,
    'recommendedAction': recommendedAction,
  };
}

class CollectionAuditReport {
  const CollectionAuditReport({
    required this.collection,
    required this.documentCount,
    required this.issues,
  });

  final String collection;
  final int documentCount;
  final List<FirestoreAuditIssue> issues;

  Map<String, Object?> toJson() => <String, Object?>{
    'collection': collection,
    'documentCount': documentCount,
    'issueCount': issues.length,
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

class FirestoreAuditReport {
  const FirestoreAuditReport({
    required this.generatedAt,
    required this.collections,
  });

  final DateTime generatedAt;
  final List<CollectionAuditReport> collections;

  int get totalIssueCount => collections.fold(
    0,
    (total, collection) => total + collection.issues.length,
  );

  Map<FirestoreAuditSeverity, int> get countsBySeverity {
    final counts = <FirestoreAuditSeverity, int>{
      for (final severity in FirestoreAuditSeverity.values) severity: 0,
    };
    for (final collection in collections) {
      for (final issue in collection.issues) {
        counts[issue.severity] = counts[issue.severity]! + 1;
      }
    }
    return counts;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'readOnly': true,
    'totalIssueCount': totalIssueCount,
    'countsBySeverity': <String, int>{
      for (final entry in countsBySeverity.entries) entry.key.name: entry.value,
    },
    'collections': collections
        .map((collection) => collection.toJson())
        .toList(),
  };
}

typedef FirestoreDocumentMap = Map<String, Map<String, Object?>>;
typedef FirestoreCollectionMap = Map<String, FirestoreDocumentMap>;

class FirestoreAuditService {
  FirestoreAuditService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<FirestoreAuditReport> run() async {
    const collectionNames = <String>[
      FirestoreCollections.locations,
      FirestoreCollections.users,
      FirestoreCollections.studentProfiles,
      FirestoreCollections.classSessions,
      FirestoreCollections.announcements,
      FirestoreCollections.events,
      FirestoreCollections.resources,
    ];
    final snapshots = await Future.wait(
      collectionNames.map((name) => _firestore.collection(name).get()),
    );
    final documents = <String, FirestoreDocumentMap>{};
    for (var index = 0; index < collectionNames.length; index += 1) {
      documents[collectionNames[index]] = <String, Map<String, Object?>>{
        for (final document in snapshots[index].docs)
          document.id: Map<String, Object?>.from(document.data()),
      };
    }
    return auditFirestoreDocuments(documents);
  }
}

FirestoreAuditReport auditFirestoreDocuments(
  FirestoreCollectionMap collections, {
  DateTime? generatedAt,
}) {
  final issues = <FirestoreAuditIssue>[];
  final locations = _documents(collections, FirestoreCollections.locations);
  final users = _documents(collections, FirestoreCollections.users);
  final profiles = _documents(
    collections,
    FirestoreCollections.studentProfiles,
  );
  final sessions = _documents(collections, FirestoreCollections.classSessions);
  final announcements = _documents(
    collections,
    FirestoreCollections.announcements,
  );
  final events = _documents(collections, FirestoreCollections.events);
  final resources = _documents(collections, FirestoreCollections.resources);

  _auditLocations(locations, issues);
  _auditClassSessions(sessions, issues);
  _auditResources(resources, issues);
  _auditEvents(events, resources, issues);
  _auditAnnouncements(announcements, users, profiles, issues);
  _auditStudentProfiles(profiles, users, issues);
  _auditUsers(users, profiles, issues);
  issues.addAll(validateUserStudentBidirectionalRelationships(users, profiles));
  _auditLocationReferences(collections, locations, issues);

  const orderedCollections = <String>[
    FirestoreCollections.locations,
    FirestoreCollections.users,
    FirestoreCollections.studentProfiles,
    FirestoreCollections.classSessions,
    FirestoreCollections.announcements,
    FirestoreCollections.events,
    FirestoreCollections.resources,
  ];
  return FirestoreAuditReport(
    generatedAt: generatedAt ?? DateTime.now().toUtc(),
    collections: [
      for (final name in orderedCollections)
        CollectionAuditReport(
          collection: name,
          documentCount: _documents(collections, name).length,
          issues: List<FirestoreAuditIssue>.unmodifiable(
            issues.where((issue) => issue.collection == name),
          ),
        ),
    ],
  );
}

bool hasRepeatedStandardSuffix(String value) =>
    RegExp(r'(?:-standard){2,}$').hasMatch(value.trim().toLowerCase());

bool isValidMinute(Object? value) =>
    value is int && value >= 0 && value <= 1439;

String? classSessionSemanticKey(Map<String, Object?> data) {
  final locationId = _nonEmptyString(data['locationId']);
  final weekday = data['weekday'];
  final startMinutes = data['startMinutes'];
  final classTypeId = _nonEmptyString(data['classTypeId']);
  if (locationId == null ||
      weekday is! int ||
      startMinutes is! int ||
      classTypeId == null) {
    return null;
  }
  return '${locationId.toLowerCase()}|$weekday|$startMinutes|${classTypeId.toLowerCase()}';
}

bool isPlaceholderUrl(Object? value) {
  final url = _nonEmptyString(value)?.toLowerCase();
  if (url == null) return false;
  return url.contains('example.com') ||
      url.contains('placeholder') ||
      RegExp(r'^https?://forms\.gle/ota-', caseSensitive: false).hasMatch(url);
}

bool isPlaceholderDescription(Object? value) {
  final description = _nonEmptyString(value)?.toLowerCase();
  if (description == null) return false;
  return description.contains('placeholder') ||
      description == 'description' ||
      description == 'todo' ||
      description == 'tbd';
}

List<FirestoreAuditIssue> validateEventResourceReferences(
  String eventId,
  Map<String, Object?> event,
  FirestoreDocumentMap resources,
) {
  final issues = <FirestoreAuditIssue>[];
  final linkedIds = _stringList(event['linkedResourceIds']);
  final primaryId = _nonEmptyString(event['primaryRegistrationResourceId']);
  final locationId = _nonEmptyString(event['locationId']);
  final isPublished = event['isPublished'] == true;
  for (final resourceId in linkedIds.toSet()) {
    final resource = resources[resourceId];
    if (resource == null) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          eventId,
          'event.linked_resource_missing',
          FirestoreAuditSeverity.error,
          'A linked resource ID does not resolve to a resource document.',
          'Review and repair the event-resource relationship.',
        ),
      );
      continue;
    }
    if (locationId != null &&
        _nonEmptyString(resource['locationId']) != locationId) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          eventId,
          'event.linked_resource_wrong_location',
          FirestoreAuditSeverity.error,
          'A linked resource belongs to another location.',
          'Link a General Resource from the event location.',
        ),
      );
    }
    if (resource['resourceSection'] != 'general') {
      issues.add(
        _issue(
          FirestoreCollections.events,
          eventId,
          'event.linked_resource_not_general',
          FirestoreAuditSeverity.error,
          'A linked resource is not in the general resource section.',
          'Review the relationship and link a General Resource.',
        ),
      );
    }
    if (isPublished && resource['isPublished'] != true) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          eventId,
          'event.published_with_draft_resource',
          FirestoreAuditSeverity.error,
          'A published event is linked to a draft resource.',
          'Publish the resource or revise the relationship.',
        ),
      );
    }
    if (isPublished && resource['isArchived'] == true) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          eventId,
          'event.published_with_archived_resource',
          FirestoreAuditSeverity.error,
          'A published event is linked to an archived resource.',
          'Restore the resource or revise the relationship.',
        ),
      );
    }
  }
  if (primaryId != null && !resources.containsKey(primaryId)) {
    issues.add(
      _issue(
        FirestoreCollections.events,
        eventId,
        'event.primary_resource_missing',
        FirestoreAuditSeverity.error,
        'The primary registration resource does not resolve.',
        'Select an existing General Resource.',
      ),
    );
  }
  if (primaryId != null && !linkedIds.contains(primaryId)) {
    issues.add(
      _issue(
        FirestoreCollections.events,
        eventId,
        'event.primary_not_linked',
        FirestoreAuditSeverity.error,
        'The primary registration resource is absent from linkedResourceIds.',
        'Add the primary resource ID to linkedResourceIds.',
      ),
    );
  }
  return issues;
}

List<FirestoreAuditIssue> validateUserStudentBidirectionalRelationships(
  FirestoreDocumentMap users,
  FirestoreDocumentMap profiles,
) {
  final issues = <FirestoreAuditIssue>[];
  for (final profileEntry in profiles.entries) {
    final claimedUsers = <String>{
      ..._stringList(profileEntry.value['guardianUserIds']),
      ?_nonEmptyString(profileEntry.value['selfUserId']),
    };
    for (final userId in claimedUsers) {
      final user = users[userId];
      if (user != null &&
          !_stringList(
            user['linkedStudentProfileIds'],
          ).contains(profileEntry.key)) {
        issues.add(
          _issue(
            FirestoreCollections.studentProfiles,
            profileEntry.key,
            'student_profile.user_missing_backlink',
            FirestoreAuditSeverity.error,
            'A claimed user does not link back to this student profile.',
            'Review both sides of the user-profile relationship.',
          ),
        );
      }
    }
  }
  for (final userEntry in users.entries) {
    for (final profileId in _stringList(
      userEntry.value['linkedStudentProfileIds'],
    )) {
      final profile = profiles[profileId];
      if (profile == null) continue;
      final claimsUser =
          _stringList(profile['guardianUserIds']).contains(userEntry.key) ||
          _nonEmptyString(profile['selfUserId']) == userEntry.key;
      if (!claimsUser) {
        issues.add(
          _issue(
            FirestoreCollections.users,
            userEntry.key,
            'user.student_profile_missing_backlink',
            FirestoreAuditSeverity.warning,
            'A linked student profile does not claim this user as guardian or self.',
            'Review both sides of the user-profile relationship.',
          ),
        );
      }
    }
  }
  return issues;
}

void _auditClassSessions(
  FirestoreDocumentMap sessions,
  List<FirestoreAuditIssue> issues,
) {
  final semanticGroups = <String, List<String>>{};
  for (final entry in sessions.entries) {
    final id = entry.key;
    final data = entry.value;
    _requireInt(
      data,
      'weekday',
      id,
      FirestoreCollections.classSessions,
      issues,
    );
    final weekday = data['weekday'];
    if (weekday is int && (weekday < 1 || weekday > 7)) {
      issues.add(
        _issue(
          FirestoreCollections.classSessions,
          id,
          'class_session.invalid_weekday',
          FirestoreAuditSeverity.error,
          'weekday is outside 1 through 7.',
          'Set a valid weekday.',
        ),
      );
    }
    for (final field in const ['startMinutes', 'endMinutes']) {
      if (!data.containsKey(field)) {
        issues.add(
          _issue(
            FirestoreCollections.classSessions,
            id,
            'class_session.missing_$field',
            FirestoreAuditSeverity.error,
            '$field is missing.',
            'Set canonical recurring schedule minutes.',
          ),
        );
      } else if (!isValidMinute(data[field])) {
        issues.add(
          _issue(
            FirestoreCollections.classSessions,
            id,
            'class_session.invalid_$field',
            FirestoreAuditSeverity.error,
            '$field is outside 0 through 1439.',
            'Set a valid minute value.',
          ),
        );
      }
    }
    if (data['startMinutes'] is int &&
        data['endMinutes'] is int &&
        (data['endMinutes'] as int) <= (data['startMinutes'] as int)) {
      issues.add(
        _issue(
          FirestoreCollections.classSessions,
          id,
          'class_session.invalid_range',
          FirestoreAuditSeverity.error,
          'endMinutes is not after startMinutes.',
          'Correct the recurring time range.',
        ),
      );
    }
    for (final field in const ['classTypeId', 'bulkGroupId', 'locationId']) {
      _requireString(
        data,
        field,
        id,
        FirestoreCollections.classSessions,
        issues,
      );
    }
    if (hasRepeatedStandardSuffix(_nonEmptyString(data['bulkGroupId']) ?? '')) {
      issues.add(
        _issue(
          FirestoreCollections.classSessions,
          id,
          'class_session.repeated_standard_suffix',
          FirestoreAuditSeverity.warning,
          'bulkGroupId has a repeated -standard suffix.',
          'Normalize the bulk group ID during a future migration.',
        ),
      );
    }
    _requireList(
      data,
      'eligibleBelts',
      id,
      FirestoreCollections.classSessions,
      issues,
    );
    for (final field in const ['startTime', 'endTime']) {
      if (data.containsKey(field)) {
        issues.add(
          _issue(
            FirestoreCollections.classSessions,
            id,
            'class_session.legacy_$field',
            FirestoreAuditSeverity.info,
            'Legacy field $field is present.',
            'Remove it only in the future cleanup migration.',
          ),
        );
      }
    }
    for (final field in const ['eligibilityNote', 'resumesOn']) {
      if (data.containsKey(field) && data[field] == null) {
        issues.add(
          _issue(
            FirestoreCollections.classSessions,
            id,
            'class_session.null_$field',
            FirestoreAuditSeverity.info,
            '$field is explicitly null.',
            'Omit this optional field in a future migration.',
          ),
        );
      }
    }
    final key = classSessionSemanticKey(data);
    if (key != null) (semanticGroups[key] ??= <String>[]).add(id);
  }
  for (final ids in semanticGroups.values.where((ids) => ids.length > 1)) {
    for (final id in ids) {
      issues.add(
        _issue(
          FirestoreCollections.classSessions,
          id,
          'class_session.duplicate_candidate',
          FirestoreAuditSeverity.warning,
          'Another session has the same location, weekday, start minutes, and class type.',
          'Review the candidates; do not delete automatically.',
        ),
      );
    }
  }
}

void _auditResources(
  FirestoreDocumentMap resources,
  List<FirestoreAuditIssue> issues,
) {
  final duplicateGroups = <String, List<String>>{};
  for (final entry in resources.entries) {
    final id = entry.key;
    final data = entry.value;
    _requireString(
      data,
      'resourceSection',
      id,
      FirestoreCollections.resources,
      issues,
    );
    if (data.containsKey('resourceSection') &&
        data['resourceSection'] != 'general') {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.non_general_section',
          FirestoreAuditSeverity.error,
          'resourceSection is not general.',
          'Review whether this belongs in General Resources.',
        ),
      );
    }
    for (final field in const ['resourceType', 'category', 'locationId']) {
      _requireString(data, field, id, FirestoreCollections.resources, issues);
    }
    final category = _nonEmptyString(data['category']);
    if (category != null && normalizeResourceCategory(category) != category) {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.noncanonical_category',
          FirestoreAuditSeverity.warning,
          'category is not canonical.',
          'Normalize the category in a future migration.',
        ),
      );
    }
    for (final field in const ['isPublished', 'isArchived']) {
      _requireBool(data, field, id, FirestoreCollections.resources, issues);
    }
    if (data.containsKey('url')) {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.legacy_url',
          FirestoreAuditSeverity.info,
          'Legacy url field is present.',
          'Keep reading it until the cleanup migration removes it.',
        ),
      );
    }
    if (_nonEmptyString(data['url']) != null &&
        _nonEmptyString(data['linkUrl']) == null) {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.link_url_missing_with_legacy_url',
          FirestoreAuditSeverity.warning,
          'linkUrl is missing while legacy url contains a value.',
          'Copy the verified URL into linkUrl during migration.',
        ),
      );
    }
    for (final field in const ['linkUrl', 'url']) {
      if (data.containsKey(field) && data[field] == null) {
        issues.add(
          _issue(
            FirestoreCollections.resources,
            id,
            'resource.null_$field',
            FirestoreAuditSeverity.info,
            '$field is explicitly null.',
            'Omit the optional field during cleanup.',
          ),
        );
      }
    }
    if (isPlaceholderDescription(data['description'])) {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.placeholder_description',
          FirestoreAuditSeverity.warning,
          'The description looks like placeholder content.',
          'Review the content manually.',
        ),
      );
    }
    if (isPlaceholderUrl(data['linkUrl']) || isPlaceholderUrl(data['url'])) {
      issues.add(
        _issue(
          FirestoreCollections.resources,
          id,
          'resource.placeholder_url',
          FirestoreAuditSeverity.warning,
          'A resource URL looks like sample or placeholder data.',
          'Review the URL manually.',
        ),
      );
    }
    final key =
        '${_normalized(data['locationId'])}|${_normalized(data['title'])}|${_normalized(data['linkUrl'] ?? data['url'])}';
    if (!key.endsWith('|')) (duplicateGroups[key] ??= <String>[]).add(id);
  }
  _addDuplicateIssues(
    duplicateGroups,
    FirestoreCollections.resources,
    'resource.duplicate_candidate',
    issues,
  );
}

void _auditEvents(
  FirestoreDocumentMap events,
  FirestoreDocumentMap resources,
  List<FirestoreAuditIssue> issues,
) {
  final duplicateGroups = <String, List<String>>{};
  for (final entry in events.entries) {
    final id = entry.key;
    final data = entry.value;
    for (final field in const [
      'startDateTime',
      'endDateTime',
      'createdAt',
      'updatedAt',
    ]) {
      if (_dateTime(data[field]) == null) {
        issues.add(
          _issue(
            FirestoreCollections.events,
            id,
            'event.missing_$field',
            FirestoreAuditSeverity.error,
            '$field is missing or invalid.',
            'Set the required timestamp.',
          ),
        );
      }
    }
    final start = _dateTime(data['startDateTime']);
    final end = _dateTime(data['endDateTime']);
    if (start != null && end != null && !end.isAfter(start)) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          id,
          'event.invalid_range',
          FirestoreAuditSeverity.error,
          'endDateTime is not after startDateTime.',
          'Correct the event date range.',
        ),
      );
    }
    _requireString(data, 'locationId', id, FirestoreCollections.events, issues);
    _requireList(
      data,
      'linkedResourceIds',
      id,
      FirestoreCollections.events,
      issues,
    );
    if (!data.containsKey('primaryRegistrationResourceId')) {
      issues.add(
        _issue(
          FirestoreCollections.events,
          id,
          'event.missing_primary_resource_field',
          FirestoreAuditSeverity.warning,
          'primaryRegistrationResourceId field is missing.',
          'Add the canonical relationship field during migration.',
        ),
      );
    }
    issues.addAll(validateEventResourceReferences(id, data, resources));
    if (start != null) {
      final key =
          '${_normalized(data['locationId'])}|${_normalized(data['title'])}|${start.toUtc().toIso8601String()}';
      (duplicateGroups[key] ??= <String>[]).add(id);
    }
  }
  _addDuplicateIssues(
    duplicateGroups,
    FirestoreCollections.events,
    'event.duplicate_candidate',
    issues,
  );
}

void _auditAnnouncements(
  FirestoreDocumentMap announcements,
  FirestoreDocumentMap users,
  FirestoreDocumentMap profiles,
  List<FirestoreAuditIssue> issues,
) {
  const statuses = {'draft', 'published', 'archived'};
  const audienceTypes = {
    'everyone',
    'belt',
    'classType',
    'students',
    'parents',
    'specificUsers',
    'mixed',
  };
  for (final entry in announcements.entries) {
    final id = entry.key;
    final data = entry.value;
    if (data['priority'] == 'critical') {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.critical_priority',
          FirestoreAuditSeverity.warning,
          'priority uses the legacy critical value.',
          'Normalize it to important.',
        ),
      );
    }
    _requireBool(
      data,
      'requiresAction',
      id,
      FirestoreCollections.announcements,
      issues,
    );
    for (final field in const [
      'targetBelts',
      'targetClassTypeIds',
      'targetStudentProfileIds',
      'targetUserIds',
    ]) {
      _requireList(data, field, id, FirestoreCollections.announcements, issues);
    }
    final status = _nonEmptyString(data['status']);
    final publishedAt = _dateTime(data['publishedAt']);
    if (status == 'draft' && publishedAt != null) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.draft_has_published_at',
          FirestoreAuditSeverity.error,
          'A draft has a non-null publishedAt.',
          'Review publication history before cleanup.',
        ),
      );
    }
    if (status == 'published' && publishedAt == null) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.published_missing_published_at',
          FirestoreAuditSeverity.error,
          'A published announcement has no publishedAt.',
          'Restore the first publication timestamp if known.',
        ),
      );
    }
    if (status == 'archived' &&
        publishedAt == null &&
        data['isPublished'] == true) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.archived_missing_publication_date',
          FirestoreAuditSeverity.warning,
          'An archived announcement appears published but has no publication date.',
          'Review publication history manually.',
        ),
      );
    }
    if (status == null || !statuses.contains(status)) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.invalid_status',
          FirestoreAuditSeverity.error,
          'status is missing or invalid.',
          'Set draft, published, or archived.',
        ),
      );
    }
    final audience = _nonEmptyString(data['audienceType']);
    if (audience == null || !audienceTypes.contains(audience)) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.invalid_audience_type',
          FirestoreAuditSeverity.error,
          'audienceType is missing or invalid.',
          'Set a supported audience type.',
        ),
      );
    }
    _requireString(
      data,
      'locationId',
      id,
      FirestoreCollections.announcements,
      issues,
    );
    for (final profileId in _stringList(data['targetStudentProfileIds'])) {
      if (!profiles.containsKey(profileId)) {
        issues.add(
          _issue(
            FirestoreCollections.announcements,
            id,
            'announcement.student_reference_missing',
            FirestoreAuditSeverity.error,
            'A targeted student profile does not exist.',
            'Review the target ID.',
          ),
        );
      }
    }
    for (final userId in _stringList(data['targetUserIds'])) {
      if (!users.containsKey(userId)) {
        issues.add(
          _issue(
            FirestoreCollections.announcements,
            id,
            'announcement.user_reference_missing',
            FirestoreAuditSeverity.error,
            'A targeted user does not exist.',
            'Review the target ID.',
          ),
        );
      }
    }
    if (isPlaceholderDescription(data['title']) ||
        isPlaceholderDescription(data['summary']) ||
        isPlaceholderDescription(data['body'])) {
      issues.add(
        _issue(
          FirestoreCollections.announcements,
          id,
          'announcement.placeholder_content',
          FirestoreAuditSeverity.warning,
          'Title or content looks like placeholder data.',
          'Review the announcement manually.',
        ),
      );
    }
  }
}

void _auditStudentProfiles(
  FirestoreDocumentMap profiles,
  FirestoreDocumentMap users,
  List<FirestoreAuditIssue> issues,
) {
  for (final entry in profiles.entries) {
    final id = entry.key;
    final data = entry.value;
    for (final field in const ['fullName', 'beltRank', 'locationId']) {
      _requireString(
        data,
        field,
        id,
        FirestoreCollections.studentProfiles,
        issues,
      );
    }
    for (final field in const ['guardianUserIds', 'preferredClassGroupIds']) {
      _requireList(
        data,
        field,
        id,
        FirestoreCollections.studentProfiles,
        issues,
      );
    }
    for (final userId in _stringList(data['guardianUserIds'])) {
      if (!users.containsKey(userId)) {
        issues.add(
          _issue(
            FirestoreCollections.studentProfiles,
            id,
            'student_profile.guardian_missing',
            FirestoreAuditSeverity.error,
            'A guardian user reference does not exist.',
            'Review the guardian relationship.',
          ),
        );
      }
    }
    final selfUserId = _nonEmptyString(data['selfUserId']);
    if (selfUserId != null && !users.containsKey(selfUserId)) {
      issues.add(
        _issue(
          FirestoreCollections.studentProfiles,
          id,
          'student_profile.self_user_missing',
          FirestoreAuditSeverity.error,
          'selfUserId does not resolve to a user.',
          'Review the self relationship.',
        ),
      );
    }
    final sticker = data['stickerProgress'];
    if (sticker is! Map ||
        !sticker.containsKey('current') ||
        !sticker.containsKey('required') ||
        !sticker.containsKey('nextRank')) {
      issues.add(
        _issue(
          FirestoreCollections.studentProfiles,
          id,
          'student_profile.sticker_progress_incomplete',
          FirestoreAuditSeverity.error,
          'stickerProgress is missing required fields.',
          'Add current, required, and nextRank during cleanup.',
        ),
      );
    }
    for (final field in const ['selfUserId', 'dateOfBirth']) {
      if (data.containsKey(field) && data[field] == null) {
        issues.add(
          _issue(
            FirestoreCollections.studentProfiles,
            id,
            'student_profile.null_$field',
            FirestoreAuditSeverity.info,
            '$field is explicitly null.',
            'Omit the optional reference during cleanup.',
          ),
        );
      }
    }
    if (data.containsKey('age') && !data.containsKey('dateOfBirth')) {
      issues.add(
        _issue(
          FirestoreCollections.studentProfiles,
          id,
          'student_profile.age_without_date_of_birth',
          FirestoreAuditSeverity.info,
          'age is present without dateOfBirth.',
          'Keep age for now; consider a future date-of-birth migration.',
        ),
      );
    }
  }
}

void _auditUsers(
  FirestoreDocumentMap users,
  FirestoreDocumentMap profiles,
  List<FirestoreAuditIssue> issues,
) {
  const approvalStatuses = {'pending', 'approved', 'rejected'};
  for (final entry in users.entries) {
    final id = entry.key;
    final data = entry.value;
    for (final field in const ['displayName', 'email', 'role', 'locationId']) {
      _requireString(data, field, id, FirestoreCollections.users, issues);
    }
    final approval = _nonEmptyString(data['approvalStatus']);
    if (approval == null || !approvalStatuses.contains(approval)) {
      issues.add(
        _issue(
          FirestoreCollections.users,
          id,
          'user.invalid_approval_status',
          FirestoreAuditSeverity.error,
          'approvalStatus is missing or invalid.',
          'Set pending, approved, or rejected.',
        ),
      );
    }
    _requireList(
      data,
      'linkedStudentProfileIds',
      id,
      FirestoreCollections.users,
      issues,
    );
    final linked = _stringList(data['linkedStudentProfileIds']);
    for (final profileId in linked) {
      if (!profiles.containsKey(profileId)) {
        issues.add(
          _issue(
            FirestoreCollections.users,
            id,
            'user.student_profile_missing',
            FirestoreAuditSeverity.error,
            'A linked student profile does not exist.',
            'Review the linked profile ID.',
          ),
        );
      }
    }
    final selected = _nonEmptyString(data['selectedStudentProfileId']);
    if (selected != null && !profiles.containsKey(selected)) {
      issues.add(
        _issue(
          FirestoreCollections.users,
          id,
          'user.selected_profile_missing',
          FirestoreAuditSeverity.error,
          'selectedStudentProfileId does not resolve.',
          'Select an existing linked profile.',
        ),
      );
    }
    if (selected != null && !linked.contains(selected)) {
      issues.add(
        _issue(
          FirestoreCollections.users,
          id,
          'user.selected_profile_not_linked',
          FirestoreAuditSeverity.error,
          'selectedStudentProfileId is not in linkedStudentProfileIds.',
          'Synchronize the user profile references.',
        ),
      );
    }
  }
}

void _auditLocations(
  FirestoreDocumentMap locations,
  List<FirestoreAuditIssue> issues,
) {
  for (final entry in locations.entries) {
    final id = entry.key;
    final data = entry.value;
    _requireString(data, 'name', id, FirestoreCollections.locations, issues);
    _requireString(
      data,
      'timeZoneId',
      id,
      FirestoreCollections.locations,
      issues,
    );
    _requireBool(data, 'isActive', id, FirestoreCollections.locations, issues);
    final timeZoneId = _nonEmptyString(data['timeZoneId']);
    if (timeZoneId != null) {
      try {
        tz.getLocation(timeZoneId);
      } catch (_) {
        issues.add(
          _issue(
            FirestoreCollections.locations,
            id,
            'location.invalid_timezone',
            FirestoreAuditSeverity.error,
            'timeZoneId is not a recognized IANA timezone ID.',
            'Set a valid IANA timezone identifier.',
          ),
        );
      }
    }
  }
}

void _auditLocationReferences(
  FirestoreCollectionMap collections,
  FirestoreDocumentMap locations,
  List<FirestoreAuditIssue> issues,
) {
  for (final collection in collections.entries) {
    if (collection.key == FirestoreCollections.locations) continue;
    for (final document in collection.value.entries) {
      final locationId = _nonEmptyString(document.value['locationId']);
      if (locationId != null && !locations.containsKey(locationId)) {
        issues.add(
          _issue(
            FirestoreCollections.locations,
            '${collection.key}/${document.key}',
            'location.reference_missing',
            FirestoreAuditSeverity.error,
            'A document references a nonexistent location.',
            'Create the location or repair the reference during cleanup.',
          ),
        );
      }
    }
  }
}

void _addDuplicateIssues(
  Map<String, List<String>> groups,
  String collection,
  String code,
  List<FirestoreAuditIssue> issues,
) {
  for (final ids in groups.values.where((ids) => ids.length > 1)) {
    for (final id in ids) {
      issues.add(
        _issue(
          collection,
          id,
          code,
          FirestoreAuditSeverity.warning,
          'This document is a likely semantic duplicate.',
          'Review the candidates; do not delete automatically.',
        ),
      );
    }
  }
}

void _requireString(
  Map<String, Object?> data,
  String field,
  String id,
  String collection,
  List<FirestoreAuditIssue> issues,
) {
  if (_nonEmptyString(data[field]) == null) {
    issues.add(
      _issue(
        collection,
        id,
        '$collection.missing_$field',
        FirestoreAuditSeverity.error,
        '$field is missing or empty.',
        'Set the required field.',
      ),
    );
  }
}

void _requireInt(
  Map<String, Object?> data,
  String field,
  String id,
  String collection,
  List<FirestoreAuditIssue> issues,
) {
  if (data[field] is! int) {
    issues.add(
      _issue(
        collection,
        id,
        '$collection.missing_$field',
        FirestoreAuditSeverity.error,
        '$field is missing or invalid.',
        'Set the required integer field.',
      ),
    );
  }
}

void _requireBool(
  Map<String, Object?> data,
  String field,
  String id,
  String collection,
  List<FirestoreAuditIssue> issues,
) {
  if (data[field] is! bool) {
    issues.add(
      _issue(
        collection,
        id,
        '$collection.missing_$field',
        FirestoreAuditSeverity.error,
        '$field is missing or invalid.',
        'Set the required boolean field.',
      ),
    );
  }
}

void _requireList(
  Map<String, Object?> data,
  String field,
  String id,
  String collection,
  List<FirestoreAuditIssue> issues,
) {
  if (data[field] is! List) {
    issues.add(
      _issue(
        collection,
        id,
        '$collection.missing_$field',
        FirestoreAuditSeverity.error,
        '$field is missing or invalid.',
        'Set the required array field.',
      ),
    );
  }
}

FirestoreAuditIssue _issue(
  String collection,
  String documentId,
  String issueCode,
  FirestoreAuditSeverity severity,
  String message,
  String recommendedAction,
) => FirestoreAuditIssue(
  collection: collection,
  documentId: documentId,
  issueCode: issueCode,
  severity: severity,
  message: message,
  recommendedAction: recommendedAction,
);

FirestoreDocumentMap _documents(
  FirestoreCollectionMap collections,
  String name,
) => collections[name] ?? <String, Map<String, Object?>>{};

String? _nonEmptyString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String _normalized(Object? value) =>
    _nonEmptyString(value)?.toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().where((item) => item.trim().isNotEmpty).toList()
    : <String>[];

DateTime? _dateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
