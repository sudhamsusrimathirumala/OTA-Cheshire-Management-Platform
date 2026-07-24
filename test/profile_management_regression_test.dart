import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/data/sample_student.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/student_profile.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/manage_profiles_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/profile_service.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';
import 'package:ota_cheshire_management_platform/widgets/profile/profile_edit_sheets.dart';

void main() {
  setUp(() => initializeMockAppDataServiceForTests());

  testWidgets('account save pops only edit route and refreshes management', (
    tester,
  ) async {
    final service = _MutableProfileDataService();
    final observer = _PopObserver();
    appDataService = service;
    final saveCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: ManageProfilesScreen(
          updateAccountContact: (input) async {
            await saveCompleter.future;
            service.updateAccount(input);
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Phone'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Updated',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ManageProfilesScreen), findsOneWidget);
    expect(find.text('Updated Parent'), findsOneWidget);
    expect(find.text('Edit account information'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(observer.popCount, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'Updated Again',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(ManageProfilesScreen), findsOneWidget);
    expect(find.text('Updated Again Parent'), findsOneWidget);
    expect(observer.popCount, 2);
  });

  testWidgets('failed account save stays on edit route with safe error', (
    tester,
  ) async {
    appDataService = _MutableProfileDataService();
    await tester.pumpWidget(
      MaterialApp(
        home: ManageProfilesScreen(
          updateAccountContact: (_) async =>
              throw const ProfileServiceException(
                ProfileServiceError.permissionDenied,
                'Unable to save account changes.',
              ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Edit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit account information'), findsOneWidget);
    expect(find.text('Unable to save account changes.'), findsOneWidget);
    expect(find.byType(ManageProfilesScreen), findsNothing);
  });

  testWidgets('displaced edit route cannot pop the replacement root', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AccountEditScreen(
                    account: sampleUserAccount,
                    updateAccountContact: (_) => saveCompleter.future,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('REPLACEMENT ROOT')),
      ),
      (_) => false,
    );
    await tester.pumpAndSettle();
    saveCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('REPLACEMENT ROOT'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('add child returns to management and preserves selection', (
    tester,
  ) async {
    final service = _MutableProfileDataService();
    appDataService = service;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageProfilesScreen(
          createChild: (input) async {
            service.addChild(input);
            return 'new-child';
          },
        ),
      ),
    );

    final addChild = find.widgetWithText(OutlinedButton, 'Add child');
    await tester.scrollUntilVisible(
      addChild,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addChild);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'First name'),
      'QA',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Last name'),
      'Child',
    );
    await tester.tap(find.text('Date of birth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(ManageProfilesScreen), findsOneWidget);
    expect(find.text('QA Child'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(service.selectedStudentProfile.id, sampleStudent.id);
    expect(find.text('DASHBOARD'), findsNothing);
  });
}

class _MutableProfileDataService extends MockAppDataService {
  UserAccount _account = sampleUserAccount;
  final List<StudentProfile> _profiles = [sampleStudent];

  @override
  UserAccount get currentUserAccount => _account;

  @override
  List<StudentProfile> get linkedStudentProfiles =>
      List.unmodifiable(_profiles);

  @override
  StudentProfile get selectedStudentProfile => _profiles.firstWhere(
    (profile) => profile.id == _account.selectedStudentProfileId,
  );

  void updateAccount(AccountContactInput input) {
    _account = UserAccount(
      id: _account.id,
      firstName: input.firstName.trim(),
      lastName: input.lastName.trim(),
      email: _account.email,
      role: _account.role,
      isActive: _account.isActive,
      linkedStudentProfileIds: _account.linkedStudentProfileIds,
      createdAt: _account.createdAt,
      updatedAt: DateTime.now(),
      locationId: _account.locationId,
      selectedStudentProfileId: _account.selectedStudentProfileId,
    );
    notifyListeners();
  }

  void addChild(StudentProfileInput input) {
    _profiles.add(
      Student(
        id: 'new-child',
        name: '${input.firstName.trim()} ${input.lastName.trim()}'.trim(),
        locationId: _account.locationId,
        belt: input.beltRank,
        dateOfBirth: input.dateOfBirth,
        stickerCount: 0,
        stickersRequired: 4,
        nextRank: 'Yellow',
        guardianEmail: input.guardianEmail,
      ),
    );
    _account = UserAccount(
      id: _account.id,
      firstName: _account.firstName,
      lastName: _account.lastName,
      email: _account.email,
      role: _account.role,
      isActive: _account.isActive,
      linkedStudentProfileIds: [
        ..._account.linkedStudentProfileIds,
        'new-child',
      ],
      createdAt: _account.createdAt,
      updatedAt: DateTime.now(),
      locationId: _account.locationId,
      selectedStudentProfileId: _account.selectedStudentProfileId,
    );
    notifyListeners();
  }
}

class _PopObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}
