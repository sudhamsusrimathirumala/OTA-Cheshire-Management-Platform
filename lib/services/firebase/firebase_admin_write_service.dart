import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/academy_announcement.dart';
import '../../models/academy_event.dart';
import '../../models/academy_resource.dart';
import '../firestore/firestore_collections.dart';

class FirebaseAdminWriteService {
  FirebaseAdminWriteService({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _database => firestore ?? FirebaseFirestore.instance;

  Future<void> saveAnnouncement(AnnouncementWriteData data) async {
    final collection = _database.collection(FirestoreCollections.announcements);
    final document = data.id == null
        ? collection.doc()
        : collection.doc(data.id);
    final now = DateTime.now();
    await document.set(
      announcementWriteFields(data, now: now),
      SetOptions(merge: true),
    );
  }

  Future<void> archiveAnnouncement(String announcementId) async {
    await _database
        .collection(FirestoreCollections.announcements)
        .doc(announcementId)
        .set({
          'status': 'archived',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _database
        .collection(FirestoreCollections.announcements)
        .doc(announcementId)
        .delete();
  }

  Future<void> saveEvent(EventWriteData data) async {
    final collection = _database.collection(FirestoreCollections.events);
    final document = data.id == null
        ? collection.doc()
        : collection.doc(data.id);
    final now = DateTime.now();
    await document.set(
      eventWriteFields(data, now: now),
      SetOptions(merge: true),
    );
  }

  Future<void> archiveEvent(String eventId) async {
    await _database.collection(FirestoreCollections.events).doc(eventId).set({
      'isArchived': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> deleteEvent(String eventId) async {
    await _database
        .collection(FirestoreCollections.events)
        .doc(eventId)
        .delete();
  }

  Future<void> saveClassSession(ClassSessionWriteData data) async {
    final collection = _database.collection(FirestoreCollections.classSessions);
    final document = data.id == null
        ? collection.doc()
        : collection.doc(data.id);
    final now = DateTime.now();
    await document.set(
      classSessionWriteFields(data, now: now),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteClassSession(String classSessionId) async {
    await _database
        .collection(FirestoreCollections.classSessions)
        .doc(classSessionId)
        .delete();
  }

  Future<void> saveResource(ResourceWriteData data) async {
    final collection = _database.collection(FirestoreCollections.resources);
    final document = data.id == null
        ? collection.doc()
        : collection.doc(data.id);
    final now = DateTime.now();
    await document.set(
      resourceWriteFields(data, now: now),
      SetOptions(merge: true),
    );
  }

  Future<void> archiveResource(String resourceId) async {
    await _database
        .collection(FirestoreCollections.resources)
        .doc(resourceId)
        .set({
          'isArchived': true,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
  }

  Future<void> deleteResource(String resourceId) async {
    await _database
        .collection(FirestoreCollections.resources)
        .doc(resourceId)
        .delete();
  }
}

Map<String, Object?> resourceWriteFields(
  ResourceWriteData data, {
  required DateTime now,
}) {
  final category = data.category.trim();
  if (!canonicalResourceCategories.contains(category)) {
    throw ArgumentError.value(
      data.category,
      'category',
      'Unsupported category.',
    );
  }
  final link = data.linkUrl?.trim();
  if (link != null && link.isNotEmpty && validResourceLinkUri(link) == null) {
    throw ArgumentError.value(
      data.linkUrl,
      'linkUrl',
      'Resource link must be an absolute HTTP or HTTPS URL.',
    );
  }
  return <String, Object?>{
    'title': data.title,
    'description': data.description,
    'resourceSection': 'general',
    'category': category,
    if (link != null && link.isNotEmpty)
      'linkUrl': link
    else if (data.id != null)
      'linkUrl': FieldValue.delete(),
    'locationId': data.locationId,
    'isPublished': data.isPublished,
    'isArchived': data.isArchived,
    'createdAt': Timestamp.fromDate(data.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

String normalizeResourceCategory(String value) {
  final trimmed = value.trim();
  final compact = trimmed.replaceAll(RegExp(r'[_\s-]+'), '').toLowerCase();
  return switch (compact) {
    'belttesting' => 'testing',
    'testing' => 'testing',
    'registration' => 'registration',
    'event' || 'events' || 'form' || 'forms' => 'general',
    'academyinformation' => 'academy-information',
    'general' => 'general',
    _ => trimmed.toLowerCase().replaceAll(RegExp(r'[_\s]+'), '-'),
  };
}

Map<String, Object?> announcementWriteFields(
  AnnouncementWriteData data, {
  required DateTime now,
}) {
  final publishedAt =
      data.publishedAt ?? (data.status == 'published' ? now : null);
  return <String, Object?>{
    'title': data.title,
    'summary': data.summary,
    'body': data.body,
    'announcementType': data.announcementType,
    'priority': data.priority == 'critical' ? 'important' : data.priority,
    'requiresAction': data.requiresAction,
    'status': data.status,
    'audienceType': data.audienceType,
    'locationId': data.locationId,
    if (publishedAt != null)
      'publishedAt': Timestamp.fromDate(publishedAt)
    else if (data.id != null && data.status == 'draft')
      'publishedAt': FieldValue.delete(),
    'createdAt': Timestamp.fromDate(data.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
    'targetBelts': List<String>.from(data.targetBelts),
    'targetClassTypeIds': List<String>.from(data.targetClassTypeIds),
    'targetStudentProfileIds': List<String>.from(data.targetStudentProfileIds),
    'targetUserIds': List<String>.from(data.targetUserIds),
  };
}

Map<String, Object?> eventWriteFields(
  EventWriteData data, {
  required DateTime now,
}) {
  if (data.linkedResourceIds.any((id) => id.trim().isEmpty)) {
    throw ArgumentError.value(
      data.linkedResourceIds,
      'linkedResourceIds',
      'Resource IDs cannot be blank.',
    );
  }
  if (data.primaryRegistrationResourceId != null &&
      data.primaryRegistrationResourceId!.trim().isEmpty) {
    throw ArgumentError.value(
      data.primaryRegistrationResourceId,
      'primaryRegistrationResourceId',
      'The primary resource ID cannot be blank.',
    );
  }
  final linkedResourceIds = data.linkedResourceIds
      .map((id) => id.trim())
      .toList();
  final primaryRegistrationResourceId = data.primaryRegistrationResourceId
      ?.trim();
  final hasPrimary =
      primaryRegistrationResourceId != null &&
      primaryRegistrationResourceId.isNotEmpty;
  if (linkedResourceIds.length > 1) {
    throw ArgumentError.value(
      data.linkedResourceIds,
      'linkedResourceIds',
      'Events may link to at most one General Resource.',
    );
  }
  if (linkedResourceIds.isNotEmpty != hasPrimary ||
      (hasPrimary &&
          linkedResourceIds.single != primaryRegistrationResourceId)) {
    throw ArgumentError(
      'linkedResourceIds and primaryRegistrationResourceId must contain the same resource ID.',
    );
  }
  return {
    'title': data.title,
    'description': data.description,
    'locationId': data.locationId,
    'eventType': data.eventType,
    'startDateTime': Timestamp.fromDate(data.startDateTime),
    'endDateTime': Timestamp.fromDate(data.endDateTime),
    if (data.registrationDeadline != null)
      'registrationDeadline': Timestamp.fromDate(data.registrationDeadline!)
    else if (data.id != null)
      'registrationDeadline': FieldValue.delete(),
    'linkedResourceIds': linkedResourceIds,
    if (hasPrimary)
      'primaryRegistrationResourceId': primaryRegistrationResourceId
    else if (data.id != null)
      'primaryRegistrationResourceId': FieldValue.delete(),
    'isPublished': data.isPublished,
    'isArchived': data.isArchived,
    'createdAt': Timestamp.fromDate(data.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

Map<String, Object?> classSessionWriteFields(
  ClassSessionWriteData data, {
  required DateTime now,
}) {
  return {
    'className': data.className,
    'classTypeId': data.classTypeId,
    'bulkGroupId': data.bulkGroupId,
    'locationId': data.locationId,
    'weekday': data.weekday,
    'startMinutes': data.startMinutes,
    'endMinutes': data.endMinutes,
    'eligibleBelts': List<String>.from(data.eligibleBelts),
    'description': data.description,
    if (data.eligibilityNote != null && data.eligibilityNote!.trim().isNotEmpty)
      'eligibilityNote': data.eligibilityNote!.trim()
    else if (data.id != null)
      'eligibilityNote': FieldValue.delete(),
    'isActive': data.isActive,
    'isPreferred': data.isPreferred,
    if (data.resumesOn != null)
      'resumesOn': Timestamp.fromDate(data.resumesOn!)
    else if (data.id != null)
      'resumesOn': FieldValue.delete(),
    'createdAt': Timestamp.fromDate(data.createdAt ?? now),
    'updatedAt': Timestamp.fromDate(now),
  };
}

class AnnouncementWriteData {
  const AnnouncementWriteData({
    required this.title,
    required this.summary,
    required this.body,
    required this.announcementType,
    required this.priority,
    required this.status,
    required this.locationId,
    required this.requiresAction,
    this.audienceType = 'everyone',
    this.targetBelts = const <String>[],
    this.targetClassTypeIds = const <String>[],
    this.targetStudentProfileIds = const <String>[],
    this.targetUserIds = const <String>[],
    this.id,
    this.publishedAt,
    this.createdAt,
  });

  factory AnnouncementWriteData.fromAnnouncement(
    AcademyAnnouncement announcement, {
    required String title,
    required String summary,
    required String body,
    required String announcementType,
    required String priority,
    required String status,
    required String locationId,
    bool? requiresAction,
    String? audienceType,
    List<String>? targetBelts,
    List<String>? targetClassTypeIds,
    List<String>? targetStudentProfileIds,
    List<String>? targetUserIds,
  }) {
    return AnnouncementWriteData(
      id: announcement.id,
      title: title,
      summary: summary,
      body: body,
      announcementType: announcementType,
      priority: priority,
      status: status,
      locationId: locationId,
      requiresAction: requiresAction ?? announcement.requiresAction,
      audienceType: audienceType ?? announcement.audienceType,
      targetBelts: targetBelts ?? announcement.targetBelts,
      targetClassTypeIds: targetClassTypeIds ?? announcement.targetClassTypeIds,
      targetStudentProfileIds:
          targetStudentProfileIds ?? announcement.targetStudentProfileIds,
      targetUserIds: targetUserIds ?? announcement.targetUserIds,
      publishedAt: announcement.publishedAt,
      createdAt: announcement.createdAt,
    );
  }

  final String? id;
  final String title;
  final String summary;
  final String body;
  final String announcementType;
  final String priority;
  final String status;
  final String locationId;
  final bool requiresAction;
  final String audienceType;
  final List<String> targetBelts;
  final List<String> targetClassTypeIds;
  final List<String> targetStudentProfileIds;
  final List<String> targetUserIds;
  final DateTime? publishedAt;
  final DateTime? createdAt;
}

class EventWriteData {
  const EventWriteData({
    required this.title,
    required this.description,
    required this.locationId,
    required this.eventType,
    required this.startDateTime,
    required this.endDateTime,
    required this.isPublished,
    this.id,
    this.registrationDeadline,
    this.linkedResourceIds = const <String>[],
    this.primaryRegistrationResourceId,
    this.isArchived = false,
    this.createdAt,
  });

  factory EventWriteData.fromEvent(
    AcademyEvent event, {
    required String title,
    required String description,
    required String locationId,
    required String eventType,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required bool isPublished,
    DateTime? registrationDeadline,
    List<String>? linkedResourceIds,
    String? primaryRegistrationResourceId,
  }) {
    final synchronizedResourceIds = <String>{
      ...(linkedResourceIds ?? event.linkedResourceIds),
    };
    if (primaryRegistrationResourceId == null &&
        event.primaryRegistrationResourceId != null) {
      synchronizedResourceIds.remove(event.primaryRegistrationResourceId);
    }
    return EventWriteData(
      id: event.id,
      title: title,
      description: description,
      locationId: locationId,
      eventType: eventType,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      registrationDeadline: registrationDeadline,
      linkedResourceIds: synchronizedResourceIds.toList(),
      primaryRegistrationResourceId: primaryRegistrationResourceId,
      isPublished: isPublished,
      isArchived: event.isArchived,
      createdAt: event.createdAt,
    );
  }

  final String? id;
  final String title;
  final String description;
  final String locationId;
  final String eventType;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final DateTime? registrationDeadline;
  final List<String> linkedResourceIds;
  final String? primaryRegistrationResourceId;
  final bool isPublished;
  final bool isArchived;
  final DateTime? createdAt;
}

class ResourceWriteData {
  const ResourceWriteData({
    required this.title,
    required this.description,
    required this.category,
    required this.locationId,
    required this.isPublished,
    this.resourceSection = 'general',
    this.id,
    this.linkUrl,
    this.isArchived = false,
    this.createdAt,
  });

  factory ResourceWriteData.fromResource(
    AcademyResource resource, {
    required String title,
    required String description,
    required String category,
    required String locationId,
    required bool isPublished,
    String? linkUrl,
    bool? isArchived,
  }) {
    return ResourceWriteData(
      id: resource.id,
      title: title,
      description: description,
      resourceSection: resource.resourceSection,
      category: category,
      locationId: locationId,
      linkUrl: linkUrl,
      isPublished: isPublished,
      isArchived: isArchived ?? resource.isArchived,
      createdAt: resource.createdAt,
    );
  }

  final String? id;
  final String title;
  final String description;
  final String resourceSection;
  final String category;
  final String? linkUrl;
  final String locationId;
  final bool isPublished;
  final bool isArchived;
  final DateTime? createdAt;
}

class ClassSessionWriteData {
  const ClassSessionWriteData({
    required this.className,
    required this.classTypeId,
    String? bulkGroupId,
    required this.locationId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.eligibleBelts,
    required this.description,
    required this.isActive,
    required this.isPreferred,
    this.id,
    this.eligibilityNote,
    this.resumesOn,
    this.createdAt,
  }) : bulkGroupId = bulkGroupId ?? '$classTypeId-standard';

  final String? id;
  final String className;
  final String classTypeId;
  final String bulkGroupId;
  final String locationId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final List<String> eligibleBelts;
  final String description;
  final String? eligibilityNote;
  final bool isActive;
  final bool isPreferred;
  final DateTime? resumesOn;
  final DateTime? createdAt;

  DateTime get startTime =>
      DateTime(2026, 6, 21 + weekday, startMinutes ~/ 60, startMinutes % 60);

  DateTime get endTime =>
      DateTime(2026, 6, 21 + weekday, endMinutes ~/ 60, endMinutes % 60);
}
