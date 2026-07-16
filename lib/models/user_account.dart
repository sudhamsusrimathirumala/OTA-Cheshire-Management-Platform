enum UserAccountRole { student, parent, admin, superAdmin }

class StudentProfileDefaults {
  const StudentProfileDefaults({
    this.dateOfBirth,
    this.beltRank,
    this.guardianEmail,
    this.stickerCurrent = 0,
    this.stickerRequired = 0,
    this.nextRank,
  });

  final DateTime? dateOfBirth;
  final String? beltRank;
  final String? guardianEmail;
  final int stickerCurrent;
  final int stickerRequired;
  final String? nextRank;
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.isActive = true,
    required this.linkedStudentProfileIds,
    this.createdAt,
    this.updatedAt,
    this.phoneNumber,
    this.locationId = '',
    this.selectedStudentProfileId,
    this.googleAccountId,
    this.studentProfileDefaults,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserAccountRole role;
  final bool isActive;
  final List<String> linkedStudentProfileIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? phoneNumber;
  final String locationId;
  final String? selectedStudentProfileId;
  final String? googleAccountId;
  final StudentProfileDefaults? studentProfileDefaults;

  String get displayName => '$firstName $lastName'.trim();

  String get roleLabel {
    return switch (role) {
      UserAccountRole.parent => 'Parent',
      UserAccountRole.student => 'Student',
      UserAccountRole.admin => 'Admin',
      UserAccountRole.superAdmin => 'Super Admin',
    };
  }
}
