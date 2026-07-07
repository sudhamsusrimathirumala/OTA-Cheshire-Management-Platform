import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/sample_events.dart';
import '../../data/sample_notifications.dart';
import '../../data/sample_schedule.dart';
import '../../data/sample_student.dart';
import '../../models/academy_event.dart';
import '../../models/class_session.dart';
import '../../models/notification_item.dart';
import '../../models/student.dart';
import '../../models/user_account.dart';
import 'firestore_collections.dart';

const bool _enableDevelopmentFirestoreSeed = false;

class FirestoreSeedService {
  FirestoreSeedService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> seedAll() async {
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
        _studentProfileData(profile),
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
    final now = FieldValue.serverTimestamp();

    // TODO: Replace placeholder resource seed data with real resource models.
    final resources = {
      'student_handbook': {
        'locationId': sampleUserAccount.locationId,
        'title': 'Student Handbook',
        'description': 'Placeholder family resource.',
        'url': null,
        'category': 'general',
        'isPublished': false,
        'createdAt': now,
        'updatedAt': now,
      },
      'belt_testing_checklist': {
        'locationId': sampleUserAccount.locationId,
        'title': 'Belt Testing Checklist',
        'description': 'Placeholder testing preparation resource.',
        'url': null,
        'category': 'beltTesting',
        'isPublished': false,
        'createdAt': now,
        'updatedAt': now,
      },
    };

    for (final resource in resources.entries) {
      batch.set(
        _firestore.collection(FirestoreCollections.resources).doc(resource.key),
        resource.value,
      );
    }

    await batch.commit();
  }
}

Map<String, Object?> _userAccountData(UserAccount account) {
  // TODO: Replace mock seed data with production Firebase Auth-linked users.
  final now = FieldValue.serverTimestamp();

  return {
    'displayName': account.displayName,
    'email': account.email,
    'role': account.role.name,
    'locationId': account.locationId,
    'approvalStatus': account.approvalStatus.name,
    'linkedStudentProfileIds': account.linkedStudentProfileIds,
    'selectedStudentProfileId': account.selectedStudentProfileId,
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, Object?> _studentProfileData(Student profile) {
  // TODO: Replace mock seed data with production student profile records.
  final now = FieldValue.serverTimestamp();

  return {
    'fullName': profile.name,
    'age': profile.age,
    'beltRank': profile.belt,
    'locationId': profile.locationId,
    'guardianUserIds': profile.guardianUserIds,
    'selfUserId': profile.selfUserId,
    'stickerProgress': {
      'current': profile.stickerCount,
      'required': profile.stickersRequired,
      'nextRank': profile.nextRank,
    },
    'promotionHistory': profile.promotionHistory,
    'testingNotes': profile.testingNotes,
    'isActive': profile.isActive,
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
    'registrationUrl': event.registrationUrl,
    'registrationDeadline': event.registrationDeadline == null
        ? null
        : Timestamp.fromDate(event.registrationDeadline!),
    'isPublished': event.isPublished,
    'showInResources': event.showInResources,
    'isArchived': event.isArchived,
    'createdAt': Timestamp.fromDate(event.createdAt),
    'updatedAt': Timestamp.fromDate(event.updatedAt),
  };
}
