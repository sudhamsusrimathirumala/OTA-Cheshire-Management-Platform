import 'package:flutter/foundation.dart';

import '../data/sample_events.dart';
import '../data/sample_curriculum.dart' as curriculum_data;
import '../data/sample_notifications.dart';
import '../data/sample_resources.dart';
import '../data/sample_schedule.dart';
import '../data/sample_student.dart';
import '../models/academy_announcement.dart';
import '../models/academy_event.dart';
import '../models/academy_resource.dart';
import '../models/class_session.dart';
import '../models/curriculum_requirement.dart';
import '../models/notification_item.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';
import 'app_data_service.dart';

class MockAppDataService implements AppDataService {
  const MockAppDataService({this.accountOverride});

  final UserAccount? accountOverride;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  UserAccount get currentUserAccount => accountOverride ?? sampleUserAccount;

  @override
  List<StudentProfile> get linkedStudentProfiles {
    return sampleStudentProfiles
        .where(
          (student) =>
              currentUserAccount.linkedStudentProfileIds.contains(student.id),
        )
        .toList(growable: false);
  }

  @override
  List<StudentProfile> get adminStudentProfiles {
    return sampleStudentProfiles
        .where((student) => student.locationId == currentUserAccount.locationId)
        .toList(growable: false);
  }

  @override
  StudentProfile get selectedStudentProfile {
    final profiles = linkedStudentProfiles;
    final selectedProfileId = currentUserAccount.selectedStudentProfileId;

    return profiles.firstWhere(
      (student) => student.id == selectedProfileId,
      orElse: () => profiles.first,
    );
  }

  @override
  Map<int, List<ClassSession>> get schedule {
    return {
      for (final entry in sampleSummerSchedule.entries)
        entry.key: entry.value
            .where(
              (session) =>
                  session.locationId == selectedStudentProfile.locationId &&
                  session.isPublished,
            )
            .toList(growable: false),
    };
  }

  @override
  bool get isScheduleLoading => false;

  @override
  String? get scheduleErrorMessage => null;

  @override
  bool get isAnnouncementsLoading => false;

  @override
  String? get announcementsErrorMessage => null;

  @override
  bool get isEventsLoading => false;

  @override
  String? get eventsErrorMessage => null;

  @override
  bool get isAdminStudentsLoading => false;

  @override
  String? get adminStudentsErrorMessage => null;

  @override
  bool get isResourcesLoading => false;

  @override
  String? get resourcesErrorMessage => null;

  @override
  List<ClassSession> scheduleForWeekday(int weekday) {
    return schedule[weekday] ?? const <ClassSession>[];
  }

  @override
  ClassSession? nextClassForDashboard() {
    for (final session in schedule[DateTime.monday] ?? const <ClassSession>[]) {
      if (session.className == 'Teen & Black Belt') {
        return session;
      }
    }

    return null;
  }

  @override
  List<String> get curriculumBeltOrder => curriculum_data.curriculumBeltOrder;

  @override
  Map<String, CurriculumRequirement> get curriculum {
    return Map.unmodifiable({
      for (final entry in curriculum_data.sampleCurriculum.entries)
        if (entry.value.locationId == selectedStudentProfile.locationId)
          entry.key: entry.value,
    });
  }

  @override
  CurriculumRequirement curriculumForBelt(String belt) {
    return curriculum[belt] ?? curriculum.values.first;
  }

  @override
  String beltDisplayLabel(String belt) =>
      curriculum_data.beltDisplayLabel(belt);

  @override
  List<NotificationItem> get notifications {
    return sampleNotifications
        .where(
          (notification) =>
              notification.locationId == selectedStudentProfile.locationId,
        )
        .toList(growable: false);
  }

  @override
  List<AcademyAnnouncement> get adminAnnouncements {
    return [
          ...sampleNotifications.map(
            (notification) => AcademyAnnouncement(
              id: notification.id,
              title: notification.title,
              summary: notification.summary,
              body: notification.body,
              announcementType: notification.category.name,
              priority: notification.priority.name,
              status: 'published',
              audienceType: 'everyone',
              locationId: notification.locationId,
              publishedAt: notification.timestamp,
              createdAt: notification.timestamp,
              updatedAt: notification.timestamp,
              requiresAction: notification.requiresAction,
            ),
          ),
          AcademyAnnouncement(
            id: 'draft_parent_night_out',
            title: 'Parent Night Out Registration',
            summary: 'Draft registration reminder for the next academy event.',
            body:
                'Parent Night Out registration details are being prepared. This announcement will include the event time, registration link, and pickup reminders.',
            announcementType: NotificationCategory.reminder.name,
            priority: NotificationPriority.general.name,
            status: 'draft',
            audienceType: 'everyone',
            locationId: currentUserAccount.locationId,
            publishedAt: DateTime(2026, 6, 25, 10),
            createdAt: DateTime(2026, 6, 25, 10),
            updatedAt: DateTime(2026, 6, 25, 10),
          ),
          AcademyAnnouncement(
            id: 'draft_schedule_note',
            title: 'July Schedule Note',
            summary:
                'Draft note for families about upcoming July schedule changes.',
            body:
                'July schedule adjustments are being reviewed. Families will receive the final version after class times are confirmed.',
            announcementType: NotificationCategory.scheduleChange.name,
            priority: NotificationPriority.important.name,
            status: 'draft',
            audienceType: 'everyone',
            locationId: currentUserAccount.locationId,
            publishedAt: DateTime(2026, 6, 24, 15),
            createdAt: DateTime(2026, 6, 24, 15),
            updatedAt: DateTime(2026, 6, 24, 15),
          ),
        ]
        .where((item) => item.locationId == currentUserAccount.locationId)
        .toList(growable: false)
      ..sort((a, b) => b.displayDate.compareTo(a.displayDate));
  }

  @override
  List<AcademyEvent> get events {
    return sampleAcademyEvents
        .where(
          (event) =>
              event.locationId == currentUserAccount.locationId &&
              event.eventType != 'closure',
        )
        .toList(growable: false);
  }

  @override
  List<AcademyResource> get resources {
    return sampleAcademyResources
        .where(
          (resource) => resource.locationId == currentUserAccount.locationId,
        )
        .toList(growable: false)
      ..sort((a, b) {
        final category = a.categoryLabel.compareTo(b.categoryLabel);
        if (category != 0) {
          return category;
        }
        return a.title.compareTo(b.title);
      });
  }
}
