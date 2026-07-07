import 'package:flutter/foundation.dart';

import '../data/sample_curriculum.dart' as curriculum_data;
import '../data/sample_notifications.dart';
import '../data/sample_schedule.dart';
import '../data/sample_student.dart';
import '../models/class_session.dart';
import '../models/curriculum_requirement.dart';
import '../models/notification_item.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';
import 'app_data_service.dart';

class MockAppDataService implements AppDataService {
  const MockAppDataService();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  UserAccount get currentUserAccount => sampleUserAccount;

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
}
