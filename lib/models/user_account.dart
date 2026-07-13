enum UserAccountRole { student, parent, admin, superAdmin }

enum UserAccountApprovalStatus {
  incomplete,
  pending,
  approved,
  rejected,
  disabled,
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.approvalStatus,
    required this.linkedStudentProfileIds,
    this.createdAt,
    this.updatedAt,
    this.phoneNumber,
    this.locationId = '',
    this.selectedStudentProfileId,
    this.googleAccountId,
    this.familyApplicationId,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserAccountRole role;
  final UserAccountApprovalStatus approvalStatus;
  final List<String> linkedStudentProfileIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? phoneNumber;
  final String locationId;
  final String? selectedStudentProfileId;
  final String? googleAccountId;
  final String? familyApplicationId;

  String get displayName => '$firstName $lastName'.trim();

  String get approvalStatusLabel {
    return switch (approvalStatus) {
      UserAccountApprovalStatus.incomplete => 'Incomplete',
      UserAccountApprovalStatus.pending => 'Pending',
      UserAccountApprovalStatus.approved => 'Approved',
      UserAccountApprovalStatus.rejected => 'Rejected',
      UserAccountApprovalStatus.disabled => 'Disabled',
    };
  }

  String get roleLabel {
    return switch (role) {
      UserAccountRole.parent => 'Parent',
      UserAccountRole.student => 'Student',
      UserAccountRole.admin => 'Admin',
      UserAccountRole.superAdmin => 'Super Admin',
    };
  }
}
