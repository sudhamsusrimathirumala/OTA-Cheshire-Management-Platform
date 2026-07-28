import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_students_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_location_controller.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';

void main() {
  const parent = UserAccount(
    id: 'parent-1',
    firstName: 'Pat',
    lastName: 'Parent',
    email: 'parent@example.com',
    role: UserAccountRole.parent,
    locationId: 'ota-cheshire',
    linkedStudentProfileIds: ['child', 'parent-self'],
    selectedStudentProfileId: 'child',
  );
  const studentAccount = UserAccount(
    id: 'student-1',
    firstName: 'Sam',
    lastName: 'Student',
    email: 'student@example.com',
    role: UserAccountRole.student,
    locationId: 'ota-cheshire',
    linkedStudentProfileIds: ['student-self'],
    selectedStudentProfileId: 'student-self',
  );

  test('child with parent account resolves as parent-managed', () {
    final relationship = adminStudentRelationship(
      _profile(id: 'child', guardianUserIds: const ['parent-1']),
      const [parent, studentAccount],
    );

    expect(relationship.type, AdminStudentProfileType.child);
    expect(relationship.account, parent);
  });

  test('parent linked to their own profile resolves as parent self', () {
    final relationship = adminStudentRelationship(
      _profile(id: 'parent-self', linkedUserId: 'parent-1'),
      const [parent, studentAccount],
    );

    expect(relationship.type, AdminStudentProfileType.parentSelf);
    expect(relationship.account?.roleLabel, 'Parent');
  });

  test('student linked to their own profile resolves as self-managed', () {
    final relationship = adminStudentRelationship(
      _profile(id: 'student-self', linkedUserId: 'student-1'),
      const [parent, studentAccount],
    );

    expect(relationship.type, AdminStudentProfileType.studentSelf);
    expect(relationship.account?.roleLabel, 'Student');
  });

  test('legacy guardian email resolves as child without an account role', () {
    final relationship = adminStudentRelationship(
      _profile(id: 'legacy', guardianEmail: 'legacy@example.com'),
      const [],
    );

    expect(relationship.type, AdminStudentProfileType.child);
    expect(relationship.account, isNull);
  });

  test('missing linked account resolves as unknown', () {
    final relationship = adminStudentRelationship(
      _profile(id: 'missing', linkedUserId: 'missing-account'),
      const [],
    );

    expect(relationship.type, AdminStudentProfileType.unknown);
    expect(relationship.account, isNull);
  });

  testWidgets(
    'detail sheet shows relationship and contact labels without role',
    (tester) async {
      final profiles = [
        _profile(
          id: 'child',
          name: 'Child Profile',
          guardianUserIds: const ['parent-1'],
        ),
        _profile(
          id: 'parent-self',
          name: 'Parent Profile',
          linkedUserId: 'parent-1',
        ),
        _profile(
          id: 'student-self',
          name: 'Student Profile',
          linkedUserId: 'student-1',
        ),
        _profile(
          id: 'legacy',
          name: 'Legacy Profile',
          guardianEmail: 'legacy@example.com',
        ),
        _profile(
          id: 'missing',
          name: 'Missing Account Profile',
          linkedUserId: 'missing-account',
        ),
      ];
      appDataService = _AdminStudentService(
        profiles: profiles,
        accounts: const [parent, studentAccount],
      );
      adminLocationController = AdminLocationController.forTesting(
        role: UserAccountRole.admin,
        locations: const [
          AcademyLocation(
            id: 'ota-cheshire',
            name: 'OTA Cheshire',
            timeZoneId: 'America/New_York',
            isActive: true,
          ),
        ],
        assignedLocationId: 'ota-cheshire',
      );
      addTearDown(initializeMockAppDataServiceForTests);

      await tester.pumpWidget(const MaterialApp(home: AdminStudentsScreen()));

      await _open(tester, 'Child Profile');
      expect(find.text('Profile type'), findsOneWidget);
      expect(find.text('Child profile'), findsOneWidget);
      expect(find.text('Account role'), findsNothing);
      expect(find.text('Parent name'), findsOneWidget);
      expect(find.text('Pat Parent'), findsOneWidget);
      expect(find.text('parent@example.com'), findsOneWidget);
      await _close(tester);

      await _open(tester, 'Parent Profile');
      expect(find.text('Profile type'), findsOneWidget);
      expect(find.text('Parent’s own student profile'), findsOneWidget);
      expect(find.text('Account role'), findsNothing);
      expect(find.text('Account holder name'), findsOneWidget);
      expect(find.text('Pat Parent'), findsOneWidget);
      expect(find.text('parent@example.com'), findsOneWidget);
      await _close(tester);

      await _open(tester, 'Student Profile');
      expect(find.text('Profile type'), findsOneWidget);
      expect(find.text('Self-managed student'), findsOneWidget);
      expect(find.text('Account role'), findsNothing);
      expect(find.text('Account holder name'), findsOneWidget);
      expect(find.text('Sam Student'), findsOneWidget);
      expect(find.text('student@example.com'), findsOneWidget);
      await _close(tester);

      await _open(tester, 'Legacy Profile');
      expect(find.text('Profile type'), findsOneWidget);
      expect(find.text('Child profile'), findsOneWidget);
      expect(find.text('legacy@example.com'), findsOneWidget);
      expect(find.text('Account role'), findsNothing);
      await _close(tester);

      await _open(tester, 'Missing Account Profile');
      expect(find.text('Profile type'), findsOneWidget);
      expect(find.text('Unknown relationship'), findsOneWidget);
      expect(find.text('Account role'), findsNothing);
    },
  );
}

Future<void> _open(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text(name).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.text('Close'));
  await tester.pumpAndSettle();
}

Student _profile({
  required String id,
  String? name,
  String? linkedUserId,
  String? guardianEmail,
  List<String> guardianUserIds = const [],
}) => Student(
  id: id,
  name: name ?? id,
  locationId: 'ota-cheshire',
  belt: 'White',
  legacyAge: 12,
  stickerCount: 2,
  stickersRequired: 5,
  nextRank: 'Yellow',
  linkedUserId: linkedUserId,
  guardianEmail: guardianEmail,
  guardianUserIds: guardianUserIds,
);

class _AdminStudentService extends MockAppDataService {
  _AdminStudentService({required this.profiles, required this.accounts});

  final List<Student> profiles;
  final List<UserAccount> accounts;

  @override
  List<Student> get adminStudentProfiles => profiles;

  @override
  List<UserAccount> get adminUserAccounts => accounts;

  @override
  bool get isAdminStudentsLoading => false;
}
