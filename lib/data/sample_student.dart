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
  guardianUserIds: ['user_parent_demo'],
  preferredClassGroupIds: ['teen-adult', 'level-4'],
);

const sampleStudentProfiles = [
  sampleStudent,
  Student(
    id: 'student_maya',
    name: 'Maya Patel',
    locationId: otaCheshireLocationId,
    belt: 'Yellow-Green',
    age: 9,
    stickerCount: 2,
    stickersRequired: 4,
    nextRank: 'Green',
    guardianUserIds: ['guardian_patel'],
    preferredClassGroupIds: ['level-2'],
  ),
  Student(
    id: 'student_aarav',
    name: 'Aarav Patel',
    locationId: otaCheshireLocationId,
    belt: 'White-Yellow',
    age: 6,
    stickerCount: 1,
    stickersRequired: 3,
    nextRank: 'Yellow',
    guardianUserIds: ['guardian_patel'],
    preferredClassGroupIds: ['level-1'],
  ),
  Student(
    id: 'student_elena',
    name: 'Elena Rivera',
    locationId: otaCheshireLocationId,
    belt: 'Blue',
    age: 13,
    stickerCount: 3,
    stickersRequired: 4,
    nextRank: 'Blue-Red',
    guardianUserIds: ['guardian_rivera'],
    preferredClassGroupIds: ['level-3'],
  ),
  Student(
    id: 'student_daniel',
    name: 'Daniel Kim',
    locationId: otaCheshireLocationId,
    belt: 'Black',
    age: 21,
    stickerCount: 0,
    stickersRequired: 0,
    nextRank: 'Second Dan',
    preferredClassGroupIds: ['teen-adult'],
  ),
];

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
