import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/sample_events.dart';
import '../../data/sample_notifications.dart';
import '../../data/sample_resources.dart';
import '../../data/sample_schedule.dart';
import '../../data/sample_student.dart';
import '../../models/academy_event.dart';
import '../../models/academy_resource.dart';
import '../../models/class_session.dart';
import '../../models/notification_item.dart';
import '../../models/student.dart';
import '../../models/user_account.dart';
import 'firestore_collections.dart';

const bool _enableDevelopmentFirestoreSeed = false;

// WARNING: This full development seeder writes complete sample documents and
// may overwrite documents that use the same fixed IDs. Do not run it against
// the current shared database. Use FirestoreMigrationService for merge-only
// compatibility updates.
class FirestoreSeedService {
  FirestoreSeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> seedAll() async {
    // This method is intentionally never called by the migration entrypoint.
    await seedUsers();
    await seedStudentProfiles();
    await seedClassSessions();
    await seedAnnouncements();
    await _seedEvents();
    await _seedResources();
  }

  Future<void> seedUsers() async {
    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection(FirestoreCollections.users)
          .doc(sampleUserAccount.id),
      _userAccountData(sampleUserAccount),
    );

    await batch.commit();
  }

  Future<void> seedStudentProfiles() async {
    final batch = _firestore.batch();

    for (final profile in sampleStudentProfiles) {
      batch.set(
        _firestore
            .collection(FirestoreCollections.studentProfiles)
            .doc(profile.id),
        studentProfileWriteFields(profile),
      );
    }

    await batch.commit();
  }

  Future<void> seedClassSessions() async {
    final batch = _firestore.batch();

    for (final entry in sampleSummerSchedule.entries) {
      final weekday = entry.key;
      for (final session in entry.value) {
        batch.set(
          _firestore
              .collection(FirestoreCollections.classSessions)
              .doc(session.id),
          _classSessionData(session, weekday),
        );
      }
    }

    await batch.commit();
  }

  Future<void> seedAnnouncements() async {
    final batch = _firestore.batch();

    for (final notification in sampleNotifications) {
      batch.set(
        _firestore
            .collection(FirestoreCollections.announcements)
            .doc(notification.id),
        _announcementData(notification),
      );
    }

    await batch.commit();
  }

  static Future<void> seedAllForDevelopmentIfEnabled() async {
    if (!_enableDevelopmentFirestoreSeed) {
      return;
    }

    await FirestoreSeedService().seedAll();
  }

  Future<void> _seedEvents() async {
    final batch = _firestore.batch();

    for (final event in sampleAcademyEvents) {
      batch.set(
        _firestore.collection(FirestoreCollections.events).doc(event.id),
        _eventData(event),
      );
    }

    await batch.commit();
  }

  Future<void> _seedResources() async {
    final batch = _firestore.batch();

    for (final resource in sampleAcademyResources) {
      batch.set(
        _firestore.collection(FirestoreCollections.resources).doc(resource.id),
        _resourceData(resource),
      );
    }

    await batch.commit();
  }
}

Map<String, Object?> _userAccountData(UserAccount account) {
  // TODO: Replace mock seed data with production Firebase Auth-linked users.
  final now = FieldValue.serverTimestamp();

  return {
    'firstName': account.firstName,
    'lastName': account.lastName,
    'email': account.email,
    'role': account.role.name,
    if (account.locationId.isNotEmpty) 'locationId': account.locationId,
    'isActive': account.isActive,
    'linkedStudentProfileIds': account.linkedStudentProfileIds,
    if (account.selectedStudentProfileId != null)
      'selectedStudentProfileId': account.selectedStudentProfileId,
    if (account.googleAccountId != null)
      'googleAccountId': account.googleAccountId,
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, Object?> studentProfileWriteFields(Student profile) {
  final now = FieldValue.serverTimestamp();

  return {
    'firstName': profile.firstName,
    'lastName': profile.lastName,
    'dateOfBirth': Timestamp.fromDate(profile.dateOfBirth!),
    'beltRank': profile.beltRank,
    if (profile.locationId.trim().isNotEmpty) 'locationId': profile.locationId,
    if (profile.guardianEmail != null) 'guardianEmail': profile.guardianEmail,
    'guardianUserIds': profile.guardianUserIds,
    'isActive': profile.isActive,
    if (profile.linkedUserId != null) 'linkedUserId': profile.linkedUserId,
    'preferredClassGroupIds': profile.preferredClassGroupIds,
    'stickerProgress': {
      'current': profile.stickerCount,
      'required': profile.stickersRequired,
      'nextRank': profile.nextRank,
    },
    'promotionHistory': profile.promotionHistory,
    'testingNotes': profile.testingNotes,
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, Object?> _classSessionData(ClassSession session, int weekday) {
  // TODO: Replace mock seed data with production schedule records.
  final now = FieldValue.serverTimestamp();

  return {
    'className': session.className,
    // Used for future bulk actions, such as editing or deleting all sessions of
    // the same class type while keeping each scheduled occurrence separate.
    'classTypeId': session.classTypeId,
    'bulkGroupId': session.bulkGroupId,
    'locationId': session.locationId,
    'weekday': weekday,
    'startTime': Timestamp.fromDate(session.startTime),
    'endTime': Timestamp.fromDate(session.endTime),
    'startMinutes': session.startMinutes,
    'endMinutes': session.endMinutes,
    'eligibleBelts': session.eligibleBelts,
    'description': session.description,
    'eligibilityNote': session.eligibilityNote,
    'isActive': session.isPublished,
    'isPreferred': session.isPreferred,
    'resumesOn': session.resumesOn == null
        ? null
        : Timestamp.fromDate(session.resumesOn!),
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, Object?> _announcementData(NotificationItem notification) {
  // TODO: Replace mock seed data with production announcement records.
  final publishedAt = Timestamp.fromDate(notification.timestamp);

  return {
    'locationId': notification.locationId,
    'title': notification.title,
    'summary': notification.summary,
    'body': notification.body,
    'announcementType': notification.category.name,
    'priority': notification.priority.name,
    'requiresAction': notification.requiresAction,
    'status': 'published',
    'audienceType': 'everyone',
    'targetBelts': <String>[],
    'targetClassTypeIds': <String>[],
    'targetStudentProfileIds': <String>[],
    'targetUserIds': <String>[],
    'createdAt': publishedAt,
    'updatedAt': publishedAt,
    'publishedAt': publishedAt,
  };
}

Map<String, Object?> _eventData(AcademyEvent event) {
  // TODO: Replace mock seed data with production event records.
  return {
    'title': event.title,
    'description': event.description,
    'locationId': event.locationId,
    'eventType': event.eventType,
    'startDateTime': Timestamp.fromDate(event.startDateTime),
    'endDateTime': Timestamp.fromDate(event.endDateTime),
    'registrationDeadline': event.registrationDeadline == null
        ? null
        : Timestamp.fromDate(event.registrationDeadline!),
    'linkedResourceIds': event.linkedResourceIds,
    'primaryRegistrationResourceId': event.primaryRegistrationResourceId,
    'isPublished': event.isPublished,
    'isArchived': event.isArchived,
    'createdAt': Timestamp.fromDate(event.createdAt),
    'updatedAt': Timestamp.fromDate(event.updatedAt),
  };
}

Map<String, Object?> _resourceData(AcademyResource resource) {
  // TODO: Replace sample resource seed data with production academy resources.
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
