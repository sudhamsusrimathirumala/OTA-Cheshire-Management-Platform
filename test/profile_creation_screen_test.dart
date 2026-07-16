import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/screens/auth/profile_creation_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_service.dart';

void main() {
  const cheshire = AcademyLocation(
    id: 'cheshire',
    name: 'OTA Cheshire',
    timeZoneId: 'America/New_York',
    isActive: true,
  );
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
          loadLocations: () async => const [cheshire],
          createProfiles: (_) async {},
          onProfilesCreated: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
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
    await tapInStepper(
      tester,
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

  testWidgets('parent to student switch ignores hidden children on submit', (
    tester,
  ) async {
    ProfileCreationRequest? submitted;
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileCreationScreen(
          accountEmail: 'student@example.com',
          loadLocations: () async => const [cheshire],
          createProfiles: (request) async => submitted = request,
          onProfilesCreated: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name').first,
      'Independent',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name').first,
      'Student',
    );
    await tester.tap(find.text('Date of birth').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-0')),
    );

    final roleSelector = find.byType(SegmentedButton<ProfileAccountRole>);
    await tapInStepper(
      tester,
      find.descendant(of: roleSelector, matching: find.text('Parent')),
    );
    await tapInStepper(tester, find.byKey(const ValueKey('add-student')));
    await tapInStepper(
      tester,
      find.descendant(of: roleSelector, matching: find.text('Student')),
    );
    await tester.pumpAndSettle();
    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-1')),
    );
    expect(find.text('Review and create'), findsWidgets);
    expect(find.text('Student 1'), findsNothing);

    await tapInStepper(tester, find.byType(CheckboxListTile));
    await tapInStepper(
      tester,
      find.byKey(const ValueKey('profile-continue-2')),
    );
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.role, ProfileAccountRole.student);
    expect(submitted!.additionalStudents, isEmpty);
    expect(submitted!.guardianEmail?.trim() ?? '', isEmpty);
  });

  test('completed additional student is included in the creation plan', () {
    final plan = buildProfileCreationPlan(
      request: ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1990, 1, 1),
        applicantBeltRank: 'White',
        role: ProfileAccountRole.parent,
        locationId: 'cheshire',
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
    );

    expect(plan.profiles['child-profile']!['firstName'], 'Child');
    expect(plan.profiles['child-profile']!['guardianUserIds'], ['parent-uid']);
    expect(plan.user['locationId'], 'cheshire');
    expect(plan.profiles['child-profile']!['locationId'], 'cheshire');
    expect(plan.profiles['child-profile']!['isActive'], isTrue);
    expect(plan.user['studentProfileDefaults'], {
      'dateOfBirth': isA<Object>(),
      'beltRank': 'White',
      'stickerProgress': {
        'current': 0,
        'required': 0,
        'nextRank': 'White-Yellow',
      },
    });
  });

  test('parent onboarding retains optional self-profile information', () {
    final plan = buildProfileCreationPlan(
      request: ProfileCreationRequest(
        firstName: 'Parent',
        lastName: 'Member',
        dateOfBirth: DateTime(1990, 2, 3),
        applicantBeltRank: 'Green',
        guardianEmail: ' Contact@Example.com ',
        role: ProfileAccountRole.parent,
        locationId: 'cheshire',
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
      today: DateTime(2026, 7, 16),
    );

    final defaults = plan.user['studentProfileDefaults']! as Map;
    expect(defaults['dateOfBirth'], isA<Object>());
    expect(defaults['beltRank'], 'Green');
    expect(defaults['guardianEmail'], 'contact@example.com');
    expect(defaults['stickerProgress'], {
      'current': 0,
      'required': 0,
      'nextRank': 'Green-Blue',
    });
  });

  test('sole active location is selected automatically', () {
    expect(initialLocationSelection(const [cheshire], null), 'cheshire');
  });

  test('multiple active locations require one account-level selection', () {
    const second = AcademyLocation(
      id: 'second',
      name: 'Second Academy',
      timeZoneId: 'America/Chicago',
      isActive: true,
    );
    expect(initialLocationSelection(const [cheshire, second], null), isNull);
    expect(
      initialLocationSelection(const [cheshire, second], 'second'),
      'second',
    );
  });

  testWidgets('no active location blocks setup with retry and sign out', (
    tester,
  ) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileCreationScreen(
          loadLocations: () async => const [],
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No active academy location'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sign out'), findsNWidgets(2));
    expect(find.byType(Stepper), findsNothing);
    await tester.tap(find.text('Sign out').last);
    expect(signedOut, isTrue);
  });
}
