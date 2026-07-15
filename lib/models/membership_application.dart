import 'student_profile.dart';

enum MembershipApplicationStatus { pending, approved, rejected }

class MembershipApplicantSnapshot {
  const MembershipApplicantSnapshot({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? phoneNumber;

  String get displayName => '$firstName $lastName'.trim();
}

class MembershipApplication {
  const MembershipApplication({
    required this.id,
    required this.applicantUserId,
    required this.applicant,
    required this.locationId,
    required this.studentProfileIds,
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.isLegacy = false,
  });

  final String id;
  final String applicantUserId;
  final MembershipApplicantSnapshot applicant;
  final String locationId;
  final List<String> studentProfileIds;
  final MembershipApplicationStatus status;
  final DateTime appliedAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final bool isLegacy;

  List<StudentProfile> profilesFrom(List<StudentProfile> profiles) => [
    for (final id in studentProfileIds)
      ...profiles.where((profile) => profile.id == id),
  ];
}
