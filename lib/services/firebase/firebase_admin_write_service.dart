import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/academy_announcement.dart';
import '../../models/academy_event.dart';
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
    final createdAt = data.createdAt ?? now;
    final publishedAt = data.publishedAt ?? now;

    await document.set({
      'title': data.title,
      'summary': data.summary,
      'body': data.body,
      'announcementType': data.announcementType,
      'priority': data.priority,
      'requiresAction': data.requiresAction,
      'status': data.status,
      'audienceType': data.audienceType,
      'locationId': data.locationId,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(now),
      'targetBelts': List<String>.from(data.targetBelts),
      'targetClassTypeIds': List<String>.from(data.targetClassTypeIds),
      'targetStudentProfileIds': List<String>.from(
        data.targetStudentProfileIds,
      ),
      'targetUserIds': List<String>.from(data.targetUserIds),
    }, SetOptions(merge: true));
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
    final createdAt = data.createdAt ?? now;

    await document.set({
      'title': data.title,
      'description': data.description,
      'locationId': data.locationId,
      'eventType': data.eventType,
      'startDateTime': Timestamp.fromDate(data.startDateTime),
      'endDateTime': Timestamp.fromDate(data.endDateTime),
      'registrationUrl': data.registrationUrl,
      'registrationDeadline': data.registrationDeadline == null
          ? null
          : Timestamp.fromDate(data.registrationDeadline!),
      'isPublished': data.isPublished,
      'showInResources': data.showInResources,
      'isArchived': false,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
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
    required this.showInResources,
    this.id,
    this.registrationUrl,
    this.registrationDeadline,
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
    required bool showInResources,
    String? registrationUrl,
    DateTime? registrationDeadline,
  }) {
    return EventWriteData(
      id: event.id,
      title: title,
      description: description,
      locationId: locationId,
      eventType: eventType,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      registrationUrl: registrationUrl,
      registrationDeadline: registrationDeadline,
      isPublished: isPublished,
      showInResources: showInResources,
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
  final String? registrationUrl;
  final DateTime? registrationDeadline;
  final bool isPublished;
  final bool showInResources;
  final DateTime? createdAt;
}
