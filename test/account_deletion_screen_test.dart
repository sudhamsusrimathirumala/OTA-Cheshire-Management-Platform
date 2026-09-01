import 'package:firebase_auth/firebase_auth.dart';
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
      expect(find.text('Permanently delete account'), findsNothing);
    });
  }

  testWidgets('single screen contains warning, profiles, and password', (
    tester,
  ) async {
    final fixture = _Fixture();
    await _pumpDeletionScreen(tester, fixture);

    expect(find.text('Permanent account deletion'), findsOneWidget);
    expect(find.textContaining('every student profile linked'), findsOneWidget);
    expect(find.textContaining('Belt, sticker, testing'), findsOneWidget);
    expect(find.text('This cannot be undone'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Permanently delete account'), findsOneWidget);
    expect(find.textContaining('Step '), findsNothing);
    expect(find.text('Final confirmation'), findsNothing);
    expect(find.text('Verify and continue'), findsNothing);
  });

  testWidgets('correct password immediately deletes and returns signed out', (
    tester,
  ) async {
    final fixture = _Fixture();
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
          completeSession: () async => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'correct-password');
    final deleteButton = find.widgetWithText(
      FilledButton,
      'Permanently delete account',
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(fixture.authentication.reauthenticateCalls, 1);
    expect(fixture.authentication.deleteCalls, 1);
    expect(fixture.authentication.signOutCalls, 0);
    expect(completed, 1);
    expect(find.text('Signed-out entry'), findsOneWidget);
    expect(find.byType(AccountDeletionScreen), findsNothing);
  });

  testWidgets('incorrect password changes nothing', (tester) async {
    final fixture = _Fixture();
    await _pumpDeletionScreen(tester, fixture);

    await tester.enterText(find.byType(TextField), 'incorrect-password');
    await tester.ensureVisible(find.text('Permanently delete account'));
    await tester.tap(find.text('Permanently delete account'));
    await tester.pumpAndSettle();

    expect(find.text('The current password is incorrect.'), findsOneWidget);
    expect(fixture.store.users, isNotEmpty);
    expect(fixture.authentication.deleteCalls, 0);
  });

  testWidgets('Google verification immediately deletes', (tester) async {
    final fixture = _Fixture(
      methods: const {AccountReauthenticationMethod.google},
    );
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          completeSession: () async => completed++,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Permanently delete account'));
    await tester.tap(find.text('Permanently delete account'));
    await tester.pumpAndSettle();

    expect(
      fixture.authentication.lastMethod,
      AccountReauthenticationMethod.google,
    );
    expect(fixture.authentication.deleteCalls, 1);
    expect(completed, 1);
  });

  testWidgets('Google cancellation changes nothing', (tester) async {
    final fixture = _Fixture(
      methods: const {AccountReauthenticationMethod.google},
    )..authentication.googleCancelled = true;
    await _pumpDeletionScreen(tester, fixture);

    await tester.ensureVisible(find.text('Permanently delete account'));
    await tester.tap(find.text('Permanently delete account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Google verification was cancelled. Nothing was deleted.'),
      findsOneWidget,
    );
    expect(fixture.store.users, isNotEmpty);
    expect(fixture.authentication.deleteCalls, 0);
  });

  testWidgets('Apple verification immediately deletes', (tester) async {
    final fixture = _Fixture(
      methods: const {AccountReauthenticationMethod.apple},
    );
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          completeSession: () async => completed++,
        ),
      ),
    );

    expect(find.text('Apple verification'), findsOneWidget);
    await tester.ensureVisible(find.text('Permanently delete account'));
    await tester.tap(find.text('Permanently delete account'));
    await tester.pumpAndSettle();

    expect(
      fixture.authentication.lastMethod,
      AccountReauthenticationMethod.apple,
    );
    expect(fixture.authentication.deleteCalls, 1);
    expect(completed, 1);
  });

  testWidgets('raw deletion failures are not displayed', (tester) async {
    final fixture = _Fixture()..store.failPrivateDeletion = true;
    await _pumpDeletionScreen(tester, fixture);

    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.ensureVisible(find.text('Permanently delete account'));
    await tester.tap(find.text('Permanently delete account'));
    await tester.pumpAndSettle();

    expect(
      find.text('Account deletion failed safely. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-token-value'), findsNothing);
  });

  for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.5]) {
      testWidgets(
        'deletion screen fits ${size.width}x${size.height} at $scale',
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

Future<void> _pumpDeletionScreen(WidgetTester tester, _Fixture fixture) =>
    tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: fixture.service,
          accountOverride: fixture.account,
          completeSession: () async {},
        ),
      ),
    );

class _Fixture {
  _Fixture({
    UserAccountRole role = UserAccountRole.parent,
    Set<AccountReauthenticationMethod> methods = const {
      AccountReauthenticationMethod.password,
    },
  }) : account = UserAccount(
         id: 'member',
         firstName: 'OTA',
         lastName: 'Member',
         email: 'member@example.com',
         role: role,
         linkedStudentProfileIds: const ['child', 'self-profile'],
         selectedStudentProfileId: 'child',
         locationId: 'cheshire',
       ),
       authentication = _WidgetAuthentication(methods),
       store = _WidgetStore(role: role) {
    service = AccountDeletionService(
      authentication: authentication,
      store: store,
    );
  }

  final UserAccount account;
  final _WidgetAuthentication authentication;
  final _WidgetStore store;
  late final AccountDeletionService service;
}

class _WidgetAuthentication implements AccountDeletionAuthentication {
  _WidgetAuthentication(this.methods);

  final Set<AccountReauthenticationMethod> methods;
  final User user = _WidgetUser();
  int reauthenticateCalls = 0;
  int deleteCalls = 0;
  int signOutCalls = 0;
  bool googleCancelled = false;
  AccountReauthenticationMethod? lastMethod;

  @override
  User? get currentUser => user;

  @override
  Set<AccountReauthenticationMethod> methodsFor(User user) => methods;

  @override
  Future<AccountDeletionProviderProof?> reauthenticate(
    User user,
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    reauthenticateCalls++;
    lastMethod = method;
    if (method == AccountReauthenticationMethod.password &&
        password != 'correct-password') {
      throw const AccountDeletionException(
        AccountDeletionError.incorrectPassword,
        'The current password is incorrect.',
      );
    }
    if (method == AccountReauthenticationMethod.google && googleCancelled) {
      throw const AccountDeletionException(
        AccountDeletionError.cancelled,
        'Google verification was cancelled. Nothing was deleted.',
      );
    }
    return method == AccountReauthenticationMethod.apple
        ? const AccountDeletionProviderProof.apple('authorization-code')
        : null;
  }

  @override
  Future<void> revokeProviderToken(
    User user,
    AccountReauthenticationMethod method,
    AccountDeletionProviderProof? proof,
  ) async {}

  @override
  Future<void> delete(User user) async => deleteCalls++;
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

class _WidgetUser implements User {
  @override
  String get uid => 'member';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
