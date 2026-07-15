import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/auth/profile_creation_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_membership_service.dart';

void main() {
  Future<void> tapInStepper(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> openParentStep(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileCreationScreen(
          accountEmail: 'parent@example.com',
          createProfiles: (_) async {},
          onProfilesCreated: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name').first,
      'Parent',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name').first,
      'Member',
    );
    await tester.tap(find.text('Date of birth').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-0')),
    );
    await tester.pumpAndSettle();
    final roleSelector = find.byType(SegmentedButton<ProfileAccountRole>);
    final parent = find.descendant(
      of: roleSelector,
      matching: find.text('Parent'),
    );
    await tester.ensureVisible(parent);
    await tester.tap(parent);
    await tester.pumpAndSettle();
  }

  testWidgets('blank added students render safe review placeholders', (
    tester,
  ) async {
    await openParentStep(tester);

    await tapInStepper(tester, find.byKey(const ValueKey('add-student')));
    expect(find.textContaining('Date of birth not selected'), findsOneWidget);

    await tapInStepper(tester, find.byKey(const ValueKey('add-student')));
    expect(find.textContaining('Date of birth not selected'), findsNWidgets(2));

    await tapInStepper(tester, find.text('I am also an OTA student'));
    final roleSelector = find.byType(SegmentedButton<ProfileAccountRole>);
    await tester.tap(
      find.descendant(of: roleSelector, matching: find.text('Student')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: roleSelector, matching: find.text('Parent')),
    );
    await tester.pump();
    expect(find.text('Add student (2/10)'), findsOneWidget);
  });

  testWidgets('incomplete children survive backward and forward navigation', (
    tester,
  ) async {
    await openParentStep(tester);
    await tapInStepper(tester, find.byKey(const ValueKey('add-student')));

    await tapInStepper(tester, find.byKey(const ValueKey('profile-back-1')));
    await tester.pumpAndSettle();
    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add student (1/10)'), findsOneWidget);
    expect(find.textContaining('Date of birth not selected'), findsOneWidget);
  });

  testWidgets('submission path rejects a child without a birth date', (
    tester,
  ) async {
    await openParentStep(tester);
    await tapInStepper(tester, find.byKey(const ValueKey('add-student')));
    final childCard = find.ancestor(
      of: find.text('Student 1').first,
      matching: find.byType(Card),
    );
    final fields = find.descendant(
      of: childCard,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Child');
    await tester.enterText(fields.at(1), 'Member');
    await tester.enterText(fields.at(2), 'guardian@example.com');

    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-1')),
    );
    await tester.pump();

    expect(find.text('Every student needs a date of birth.'), findsOneWidget);
    expect(find.text('Create profiles'), findsNothing);
  });

  test('completed additional student is included in the creation plan', () {
    final plan = buildProfileCreationPlan(
      request: ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1990, 1, 1),
        applicantBeltRank: 'White',
        role: ProfileAccountRole.parent,
        additionalStudents: [
          StudentProfileInput(
            firstName: 'Child',
            lastName: 'Member',
            dateOfBirth: DateTime(2015, 1, 1),
            beltRank: 'White',
            guardianEmail: 'parent@example.com',
          ),
        ],
      ),
      identity: const AuthProfileIdentity(
        uid: 'parent-uid',
        email: 'parent@example.com',
      ),
      profileIds: const ['child-profile'],
      timestamp: 'server-time',
      today: DateTime(2026, 7, 15),
      familyApplicationId: 'family-1',
    );

    expect(plan.profiles['child-profile']!['firstName'], 'Child');
    expect(plan.profiles['child-profile']!['guardianUserIds'], ['parent-uid']);
  });
}
