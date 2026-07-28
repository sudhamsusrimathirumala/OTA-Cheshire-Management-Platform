import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/firebase/account_deletion_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';

void main() {
  late _FakeDeletionAuth auth;
  late _FakeDeletionStore store;
  late AccountDeletionService service;
  late List<String> events;

  setUp(() {
    events = [];
    auth = _FakeDeletionAuth(events);
    store = _FakeDeletionStore(events);
    service = AccountDeletionService(authGateway: auth, store: store);
  });

  test(
    'password reauthentication succeeds and Auth deletion is last',
    () async {
      final authorization = await service.reauthenticate(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );
      await service.deleteAccount(authorization);

      expect(
        events,
        containsAllInOrder([
          'load-account',
          'reauth-password',
          'load-account',
          'delete-private',
          'delete-profiles-and-user',
          'delete-auth',
        ]),
      );
      expect(store.users, isEmpty);
      expect(store.profiles, isEmpty);
      expect(store.privateDocuments, isEmpty);
    },
  );

  test('incorrect password is safe and deletes nothing', () async {
    await expectLater(
      service.reauthenticate(
        AccountReauthenticationMethod.password,
        password: 'incorrect-secret',
      ),
      throwsA(
        isA<AccountDeletionException>()
            .having(
              (value) => value.error,
              'error',
              AccountDeletionError.incorrectPassword,
            )
            .having(
              (value) => value.toString(),
              'safe message',
              isNot(contains('incorrect-secret')),
            ),
      ),
    );
    expect(store.users, isNotEmpty);
    expect(store.profiles, isNotEmpty);
    expect(auth.deleteCalls, 0);
  });

  test('Google cancellation is safe and deletes nothing', () async {
    auth.googleCancelled = true;
    await expectLater(
      service.reauthenticate(AccountReauthenticationMethod.google),
      throwsA(
        isA<AccountDeletionException>().having(
          (value) => value.error,
          'error',
          AccountDeletionError.cancelled,
        ),
      ),
    );
    expect(events, ['load-account', 'reauth-google']);
    expect(auth.deleteCalls, 0);
  });

  for (final role in [UserAccountRole.admin, UserAccountRole.superAdmin]) {
    test('$role deletion is rejected before reauthentication', () async {
      store.users['member'] = _record(role: role);
      await expectLater(
        service.reauthenticate(
          AccountReauthenticationMethod.password,
          password: 'correct-password',
        ),
        throwsA(
          isA<AccountDeletionException>().having(
            (value) => value.error,
            'error',
            AccountDeletionError.privilegedAccount,
          ),
        ),
      );
      expect(auth.passwordCalls, 0);
      expect(auth.deleteCalls, 0);
    });
  }

  test('repeated deletion calls share one operation', () async {
    final authorization = await service.reauthenticate(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );
    store.pauseDeletion = Completer<void>();
    final first = service.deleteAccount(authorization);
    final second = service.deleteAccount(authorization);
    await Future<void>.delayed(Duration.zero);
    expect(store.privateDeleteCalls, 1);
    store.pauseDeletion!.complete();
    await Future.wait([first, second]);
    expect(store.profileDeleteCalls, 1);
    expect(auth.deleteCalls, 1);
  });

  test(
    'only linked profiles are removed and unlinked profiles remain',
    () async {
      store.profiles.add('unlinked-profile');
      final authorization = await service.reauthenticate(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );
      await service.deleteAccount(authorization);
      expect(store.profiles, {'unlinked-profile'});
    },
  );

  test(
    'Auth failure after Firestore deletion returns safe recovery state',
    () async {
      auth.failAuthDeletion = true;
      final authorization = await service.reauthenticate(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );
      await expectLater(
        service.deleteAccount(authorization),
        throwsA(
          isA<AccountDeletionException>()
              .having(
                (value) => value.firestoreDeletionCompleted,
                'Firestore completed',
                isTrue,
              )
              .having(
                (value) => value.toString(),
                'safe message',
                allOf(
                  isNot(contains('member@example.com')),
                  isNot(contains('correct-password')),
                  isNot(contains('token-value')),
                ),
              ),
        ),
      );
      expect(store.users, isEmpty);
      expect(store.profiles, isEmpty);
      expect(auth.deleteCalls, 1);

      auth.failAuthDeletion = false;
      final recoveryAuthorization = await service.reauthenticateRemainingSignIn(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );
      await service.retryAuthenticationDeletion(recoveryAuthorization);
      expect(auth.deleteCalls, 2);
      expect(auth.currentIdentity, isNull);
    },
  );

  test('password reauthentication then session suspension preserves identity '
      'for deletion', () async {
    final events = <String>[];
    final authentication = _SharedFlowAuthentication(events);
    final flowStore = _FakeDeletionStore(events);
    final flowService = AccountDeletionService(
      authGateway: authentication,
      store: flowStore,
    );
    final controller = FirebaseSessionController(authentication: authentication)
      ..stage = SessionStage.member
      ..authUser = authentication.currentUser;

    final authorization = await flowService.reauthenticate(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );
    final userBeforeSuspension = authentication.currentUser;

    await controller.suspendForAccountDeletion();

    expect(controller.stage, SessionStage.loading);
    expect(controller.authUser, same(userBeforeSuspension));
    expect(authentication.currentUser, same(userBeforeSuspension));
    expect(authentication.currentIdentity?.uid, authorization.uid);
    expect(authentication.signOutCalls, 0);
    expect(controller.authentication, same(authentication));
    expect(flowService.authGateway, same(authentication));

    await flowService.deleteAccount(authorization);

    expect(authentication.deleteCalls, 1);
    expect(flowStore.users, isEmpty);
    expect(
      events,
      containsAllInOrder([
        'reauth-password',
        'delete-private',
        'delete-profiles-and-user',
        'delete-auth',
      ]),
    );
    controller.dispose();
  });
}

AccountDeletionRecord _record({
  UserAccountRole role = UserAccountRole.parent,
}) => AccountDeletionRecord(
  uid: 'member',
  role: role,
  locationId: 'cheshire',
  linkedStudentProfileIds: const ['child', 'self-profile'],
);

class _FakeDeletionAuth implements AccountDeletionAuthGateway {
  _FakeDeletionAuth(this.events);

  final List<String> events;
  AccountDeletionIdentity? identity = const AccountDeletionIdentity(
    uid: 'member',
    email: 'member@example.com',
    methods: {
      AccountReauthenticationMethod.password,
      AccountReauthenticationMethod.google,
    },
  );
  bool googleCancelled = false;
  bool failAuthDeletion = false;
  int passwordCalls = 0;
  int deleteCalls = 0;

  @override
  AccountDeletionIdentity? get currentIdentity => identity;

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    passwordCalls++;
    events.add('reauth-password');
    if (password != 'correct-password') {
      throw const AccountDeletionException(
        AccountDeletionError.incorrectPassword,
        'The current password is incorrect.',
      );
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    events.add('reauth-google');
    if (googleCancelled) {
      throw const AccountDeletionException(
        AccountDeletionError.cancelled,
        'Google verification was cancelled. Nothing was deleted.',
      );
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls++;
    events.add('delete-auth');
    if (failAuthDeletion) {
      throw const AccountDeletionException(
        AccountDeletionError.recentLoginRequired,
        'internal-token-value',
      );
    }
    identity = null;
  }
}

class _FakeDeletionStore implements AccountDeletionStore {
  _FakeDeletionStore(this.events);

  final List<String> events;
  final users = <String, AccountDeletionRecord>{'member': _record()};
  final profiles = <String>{'child', 'self-profile'};
  final privateDocuments = <String>{
    'pushDevices/install',
    'notificationReads/notice',
  };
  int privateDeleteCalls = 0;
  int profileDeleteCalls = 0;
  Completer<void>? pauseDeletion;

  @override
  Future<AccountDeletionRecord?> loadAccount(String uid) async {
    events.add('load-account');
    return users[uid];
  }

  @override
  Future<void> deletePrivateDocuments(String uid) async {
    privateDeleteCalls++;
    events.add('delete-private');
    final pause = pauseDeletion;
    if (pause != null) await pause.future;
    privateDocuments.clear();
  }

  @override
  Future<void> deleteLinkedProfilesAndUser(
    AccountDeletionRecord account,
  ) async {
    profileDeleteCalls++;
    events.add('delete-profiles-and-user');
    profiles.removeAll(account.linkedStudentProfileIds);
    users.remove(account.uid);
  }
}

class _SharedFlowAuthentication
    implements AuthenticationService, AccountDeletionAuthGateway {
  _SharedFlowAuthentication(this.events);

  final List<String> events;
  User? _currentUser = _FlowUser();
  int signOutCalls = 0;
  int deleteCalls = 0;

  @override
  User? get currentUser => _currentUser;

  @override
  AccountDeletionIdentity? get currentIdentity => _currentUser == null
      ? null
      : AccountDeletionIdentity(
          uid: _currentUser!.uid,
          email: 'member@example.com',
          methods: const {AccountReauthenticationMethod.password},
        );

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    events.add('reauth-password');
    if (password != 'correct-password') {
      throw const AccountDeletionException(
        AccountDeletionError.incorrectPassword,
        'The current password is incorrect.',
      );
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() => throw UnimplementedError();

  @override
  Future<void> deleteCurrentUser() async {
    events.add('delete-auth');
    deleteCalls++;
    _currentUser = null;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _currentUser = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FlowUser implements User {
  @override
  String get uid => 'member';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
