import '../models/parent.dart';
import '../models/student.dart';

const sampleStudent = Student(
  id: 'student_sudhamsu',
  name: 'Sudhamsu',
  belt: 'Red-Black',
  age: 17,
  stickerCount: 1,
  stickersRequired: 3,
  nextRank: 'Black',
);

const sampleParent = Parent(
  id: 'parent_demo',
  name: 'OTA Parent',
  childIds: ['student_sudhamsu'],
);
