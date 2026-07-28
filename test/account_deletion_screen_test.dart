import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/account_deletion_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/account_deletion_service.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  testWidgets('Delete Account appears in member profile settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(
          managementAvailableOverride: false,
          accountDeletionAvailableOverride: true,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Delete Account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  for (final role in [UserAccountRole.admin, UserAccountRole.superAdmin]) {
    testWidgets('$role receives privileged-account restriction', (
      tester,
    ) async {
      final fixture = _Fixture(role: role);
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDeletionScreen(
            service: fixture.service,
            accountOverride: fixture.account,
          ),
        ),
      );
      expect(
        find.text('Privileged account deletion is restricted'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'must be removed by another authorized administrator',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('warning covers linked profiles progress and permanence', (
    tester,
  ) async {
    final fixture = _Fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
        ),
      ),
    );
    expect(find.text('Permanent account deletion'), findsOneWidget);
    expect(find.textContaining('every student profile linked'), findsOneWidget);
    expect(find.textContaining('Belt, sticker, testing'), findsOneWidget);
    expect(find.text('This cannot be undone'), findsOneWidget);
    expect(find.textContaining('recreated manually'), findsOneWidget);
  });

  testWidgets('typing DELETE is required and success returns signed out', (
    tester,
  ) async {
    final fixture = _Fixture();
    var suspended = 0;
    var completed = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Signed-out entry')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          suspendSession: () async => suspended++,
          completeSession: () async => completed++,
          restoreSession: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _reachConfirmation(tester);

    final destructiveButton = find.widgetWithText(
      FilledButton,
      'Permanently delete account',
    );
    expect(tester.widget<FilledButton>(destructiveButton).onPressed, isNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(destructiveButton).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(destructiveButton).onPressed, isNotNull);
    await tester.ensureVisible(destructiveButton);
    await tester.tap(destructiveButton);
    await tester.pumpAndSettle();

    expect(suspended, 1);
    expect(completed, 1);
    expect(find.text('Signed-out entry'), findsOneWidget);
    expect(find.byType(AccountDeletionScreen), findsNothing);
    expect(fixture.auth.deleteCalls, 1);
    expect(fixture.store.users, isEmpty);
  });

  testWidgets('cancellation leaves all data unchanged', (tester) async {
    final fixture = _Fixture();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Profile settings')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Profile settings'), findsOneWidget);
    expect(fixture.store.users, isNotEmpty);
    expect(fixture.auth.deleteCalls, 0);
  });

  testWidgets('failure displays a safe message and preserves account', (
    tester,
  ) async {
    final fixture = _Fixture()..store.failPrivateDeletion = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          suspendSession: () async {},
          completeSession: () async {},
          restoreSession: () async {},
        ),
      ),
    );
    await _reachConfirmation(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Permanently delete account'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Permanently delete account'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Account deletion failed safely. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-token-value'), findsNothing);
    expect(fixture.store.users, isNotEmpty);
    expect(fixture.auth.deleteCalls, 0);
  });

  testWidgets('debug diagnostics capture identity around session suspension', (
    tester,
  ) async {
    final fixture = _Fixture();
    String? firebaseUid = 'member';
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          currentFirebaseUid: () => firebaseUid,
          suspendSession: () async {
            firebaseUid = null;
            fixture.auth.identity = null;
          },
          completeSession: () async {},
          restoreSession: () async {},
        ),
      ),
    );
    await _reachConfirmation(tester);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    final deleteButton = find.widgetWithText(
      FilledButton,
      'Permanently delete account',
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Sign in again before deleting your account.'),
      findsOneWidget,
    );
    expect(find.text('Authorization UID: member'), findsOneWidget);
    expect(find.text('Firebase UID before suspension: member'), findsOneWidget);
    expect(find.text('Firebase UID after suspension: null'), findsOneWidget);
    expect(
      find.text('FirebaseAuth.currentUser became null: Yes'),
      findsOneWidget,
    );
    expect(
      find.text('Deletion service UID after suspension: null'),
      findsOneWidget,
    );
    expect(fixture.store.users, isNotEmpty);
    expect(fixture.auth.deleteCalls, 0);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5]) {
      testWidgets(
        'deletion explanation fits ${size.width}x${size.height} at $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = _Fixture();
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: AccountDeletionScreen(
                  service: fixture.service,
                  accountOverride: fixture.account,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Object? error;
          while ((error = tester.takeException()) != null) {
            expect(error.toString(), isNot(contains('overflowed')));
          }
        },
      );
    }
  }
}

Future<void> _reachConfirmation(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Continue to verification'));
  await tester.tap(find.text('Continue to verification'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(TextField));
  await tester.enterText(find.byType(TextField), 'correct-password');
  await tester.ensureVisible(find.text('Verify and continue'));
  await tester.tap(find.text('Verify and continue'));
  await tester.pumpAndSettle();
  expect(find.text('Final confirmation'), findsOneWidget);
}

class _Fixture {
  _Fixture({UserAccountRole role = UserAccountRole.parent})
    : account = UserAccount(
        id: 'member',
        firstName: 'OTA',
        lastName: 'Member',
        email: 'member@example.com',
        role: role,
        linkedStudentProfileIds: const ['child', 'self-profile'],
        selectedStudentProfileId: 'child',
        locationId: 'cheshire',
      ),
      auth = _WidgetAuth(),
      store = _WidgetStore(role: role) {
    service = AccountDeletionService(authGateway: auth, store: store);
  }

  final UserAccount account;
  final _WidgetAuth auth;
  final _WidgetStore store;
  late final AccountDeletionService service;
}

class _WidgetAuth implements AccountDeletionAuthGateway {
  AccountDeletionIdentity? identity = const AccountDeletionIdentity(
    uid: 'member',
    email: 'member@example.com',
    methods: {AccountReauthenticationMethod.password},
  );
  int deleteCalls = 0;

  @override
  AccountDeletionIdentity? get currentIdentity => identity;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    if (password != 'correct-password') {
      throw const AccountDeletionException(
        AccountDeletionError.incorrectPassword,
        'The current password is incorrect.',
      );
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls++;
    identity = null;
  }
}

class _WidgetStore implements AccountDeletionStore {
  _WidgetStore({required UserAccountRole role})
    : users = {
        'member': AccountDeletionRecord(
          uid: 'member',
          role: role,
          locationId: 'cheshire',
          linkedStudentProfileIds: const ['child', 'self-profile'],
        ),
      };

  final Map<String, AccountDeletionRecord> users;
  bool failPrivateDeletion = false;

  @override
  Future<AccountDeletionRecord?> loadAccount(String uid) async => users[uid];

  @override
  Future<void> deletePrivateDocuments(String uid) async {
    if (failPrivateDeletion) throw StateError('private-token-value');
  }

  @override
  Future<void> deleteLinkedProfilesAndUser(
    AccountDeletionRecord account,
  ) async {
    users.remove(account.uid);
  }
}
