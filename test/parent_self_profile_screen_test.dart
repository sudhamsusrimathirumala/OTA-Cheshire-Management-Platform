import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_service.dart';
import 'package:ota_cheshire_management_platform/widgets/profile/profile_edit_sheets.dart';

void main() {
  UserAccount account({StudentProfileDefaults? defaults}) => UserAccount(
    id: 'parent-uid',
    firstName: 'Parent',
    lastName: 'Member',
    email: 'parent@example.com',
    phoneNumber: '203-555-0100',
    role: UserAccountRole.parent,
    linkedStudentProfileIds: const ['child-profile'],
    locationId: 'cheshire',
    studentProfileDefaults: defaults,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    UserAccount user, {
    Future<String> Function(ParentSelfProfileInput input)? create,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddParentStudentProfileScreen(
          key: UniqueKey(),
          account: user,
          createProfile: create ?? (_) async => 'self-profile',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('complete defaults produce confirmation-only UI', (tester) async {
    await pumpScreen(
      tester,
      account(
        defaults: StudentProfileDefaults(
          dateOfBirth: DateTime(1990, 2, 3),
          beltRank: 'Green',
          guardianEmail: 'contact@example.com',
          stickerCurrent: 4,
          stickerRequired: 7,
          nextRank: 'Green-Blue',
        ),
      ),
    );

    expect(find.text('Name: Parent Member'), findsOneWidget);
    expect(find.text('Account email: parent@example.com'), findsOneWidget);
    expect(find.text('Phone: 203-555-0100'), findsOneWidget);
    expect(find.text('Academy location: cheshire'), findsOneWidget);
    expect(find.text('Belt rank: Green'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Create My Student Profile'), findsOneWidget);
  });

  testWidgets('only genuinely missing required fields are requested', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      account(
        defaults: StudentProfileDefaults(dateOfBirth: DateTime(1990, 2, 3)),
      ),
    );
    expect(find.text('Date of birth'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await pumpScreen(
      tester,
      account(defaults: const StudentProfileDefaults(beltRank: 'Green')),
    );
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('creation uses saved data and returns to management screen', (
    tester,
  ) async {
    ParentSelfProfileInput? submitted;
    final user = account(
      defaults: StudentProfileDefaults(
        dateOfBirth: DateTime(1990, 2, 3),
        beltRank: 'Green',
        guardianEmail: 'contact@example.com',
        stickerCurrent: 4,
        stickerRequired: 7,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('Manage Account & Student Profiles'),
                FilledButton(
                  onPressed: () => Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddParentStudentProfileScreen(
                        account: user,
                        createProfile: (input) async {
                          submitted = input;
                          return 'self-profile';
                        },
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create My Student Profile'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.dateOfBirth, DateTime(1990, 2, 3));
    expect(submitted!.beltRank, 'Green');
    expect(submitted!.guardianEmail, 'contact@example.com');
    expect(submitted!.stickerCurrent, 4);
    expect(submitted!.stickerRequired, 7);
    expect(find.text('Manage Account & Student Profiles'), findsOneWidget);
  });
}
