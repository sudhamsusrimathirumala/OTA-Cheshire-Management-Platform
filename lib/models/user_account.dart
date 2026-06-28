enum UserAccountRole { parent, student, instructor, admin }

enum UserAccountApprovalStatus { pending, approved, rejected }

class UserAccount {
  const UserAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.locationId,
    required this.approvalStatus,
    required this.linkedStudentProfileIds,
    this.selectedStudentProfileId,
  });

  final String id;
  final String displayName;
  final String email;
  final UserAccountRole role;
  final String locationId;
  final UserAccountApprovalStatus approvalStatus;
  final List<String> linkedStudentProfileIds;
  final String? selectedStudentProfileId;

  String get approvalStatusLabel {
    return switch (approvalStatus) {
      UserAccountApprovalStatus.pending => 'Pending',
      UserAccountApprovalStatus.approved => 'Approved',
      UserAccountApprovalStatus.rejected => 'Rejected',
    };
  }

  String get roleLabel {
    return switch (role) {
      UserAccountRole.parent => 'Parent',
      UserAccountRole.student => 'Student',
      UserAccountRole.instructor => 'Instructor',
      UserAccountRole.admin => 'Admin',
    };
  }
}
