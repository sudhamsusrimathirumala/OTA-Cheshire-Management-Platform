import 'package:flutter/foundation.dart';

import '../models/academy_event.dart';
import '../models/class_session.dart';
import '../models/curriculum_requirement.dart';
import '../models/notification_item.dart';
import '../models/student_profile.dart';
import '../models/user_account.dart';

abstract class AppDataService implements Listenable {
  UserAccount get currentUserAccount;

  List<StudentProfile> get linkedStudentProfiles;

  List<StudentProfile> get adminStudentProfiles;

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

  List<ClassSession> scheduleForWeekday(int weekday);

  ClassSession? nextClassForDashboard();

  List<String> get curriculumBeltOrder;

  Map<String, CurriculumRequirement> get curriculum;

  CurriculumRequirement curriculumForBelt(String belt);

  String beltDisplayLabel(String belt);

  List<NotificationItem> get notifications;

  List<AcademyEvent> get events;
}
