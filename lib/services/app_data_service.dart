import 'package:flutter/foundation.dart';

import '../models/academy_announcement.dart';
import '../models/academy_event.dart';
import '../models/academy_resource.dart';
import '../models/class_session.dart';
import '../models/curriculum_requirement.dart';
import '../models/notification_item.dart';
import '../models/membership_application.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';

abstract class AppDataService implements Listenable {
  UserAccount get currentUserAccount;

  List<StudentProfile> get linkedStudentProfiles;

  List<StudentProfile> get adminStudentProfiles;

  List<MembershipApplication> get adminMembershipApplications;

  StudentProfile get selectedStudentProfile;

  Map<int, List<ClassSession>> get schedule;

  bool get isScheduleLoading;

  String? get scheduleErrorMessage;

  bool get isAnnouncementsLoading;

  String? get announcementsErrorMessage;

  bool get isEventsLoading;

  String? get eventsErrorMessage;

  bool get isAdminStudentsLoading;

  String? get adminStudentsErrorMessage;

  bool get isMembershipApplicationsLoading;

  String? get membershipApplicationsErrorMessage;

  void retryLiveData();

  bool get isResourcesLoading;

  String? get resourcesErrorMessage;

  List<ClassSession> scheduleForWeekday(int weekday);

  ClassSession? nextClassForDashboard();

  List<String> get curriculumBeltOrder;

  Map<String, CurriculumRequirement> get curriculum;

  CurriculumRequirement curriculumForBelt(String belt);

  String beltDisplayLabel(String belt);

  List<NotificationItem> get notifications;

  List<AcademyAnnouncement> get adminAnnouncements;

  List<AcademyEvent> get events;

  List<AcademyResource> get resources;
}

ClassSession? nextEligibleClassFromSchedule(
  Map<int, List<ClassSession>> schedule,
  StudentProfile student, {
  required int currentWeekday,
  required int currentMinutes,
}) {
  for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
    final weekday = ((currentWeekday + offset - 1) % DateTime.daysPerWeek) + 1;
    for (final session in schedule[weekday] ?? const <ClassSession>[]) {
      if (offset == 0 && session.endMinutes <= currentMinutes) continue;
      if (session.isEligibleFor(student)) return session;
    }
  }
  return null;
}
