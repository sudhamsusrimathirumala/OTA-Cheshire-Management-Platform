import '../models/student.dart';
import '../models/user_account.dart';
import 'sample_constants.dart';

const sampleStudent = Student(
  id: 'student_sudhamsu',
  name: 'Sudhamsu',
  locationId: otaCheshireLocationId,
  belt: 'Red-Black',
  age: 17,
  stickerCount: 1,
  stickersRequired: 3,
  nextRank: 'Black',
);

const sampleStudentProfiles = [sampleStudent];

const sampleUserAccount = UserAccount(
  id: 'user_parent_demo',
  displayName: 'OTA Parent',
  email: 'parent@example.com',
  role: UserAccountRole.parent,
  locationId: otaCheshireLocationId,
  approvalStatus: UserAccountApprovalStatus.approved,
  linkedStudentProfileIds: ['student_sudhamsu'],
  selectedStudentProfileId: 'student_sudhamsu',
);
