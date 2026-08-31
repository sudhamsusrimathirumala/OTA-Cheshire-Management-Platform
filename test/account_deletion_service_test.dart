import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/firebase/account_deletion_service.dart';

void main() {
  late List<String> events;
  late _FakeDeletionAuthentication authentication;
  late _FakeDeletionStore store;
  late AccountDeletionService service;

  setUp(() {
    events = [];
    authentication = _FakeDeletionAuthentication(events);
    store = _FakeDeletionStore(events);
    service = AccountDeletionService(
      authentication: authentication,
      store: store,
    );
  });

  test('correct password immediately reauthenticates and deletes', () async {
    await service.deleteAccount(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );

    expect(authentication.reauthenticatedUser, same(authentication.user));
    expect(authentication.deletedUser, same(authentication.user));
    expect(authentication.currentUserReads, 1);
    expect(store.users, isEmpty);
    expect(store.profiles, {'unlinked-profile'});
    expect(store.privateDocuments, isEmpty);
    expect(
      events,
      orderedEquals([
        'load-account',
        'reauth-password',
        'delete-private',
        'delete-profiles-and-user',
        'delete-auth',
      ]),
    );
  });

  test('incorrect password changes nothing', () async {
    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.password,
        password: 'incorrect-password',
      ),
      throwsA(
        isA<AccountDeletionException>().having(
          (value) => value.error,
          'error',
          AccountDeletionError.incorrectPassword,
        ),
      ),
    );

    expect(store.users, isNotEmpty);
    expect(store.profiles, containsAll(['child', 'self-profile']));
    expect(store.privateDocuments, isNotEmpty);
    expect(authentication.deletedUser, isNull);
  });

  test('deletion has no separate authorization or expiration step', () async {
    final operation = service.deleteAccount(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );

    await operation;

    expect(authentication.reauthenticateCalls, 1);
    expect(authentication.deleteCalls, 1);
  });

  test(
    'current Firebase user is captured once without session suspension',
    () async {
      await service.deleteAccount(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );

      expect(authentication.currentUserReads, 1);
      expect(authentication.signOutCalls, 0);
      expect(authentication.reauthenticatedUser, same(authentication.user));
      expect(authentication.deletedUser, same(authentication.user));
    },
  );

  test('Google verification immediately proceeds to deletion', () async {
    await service.deleteAccount(AccountReauthenticationMethod.google);

    expect(authentication.reauthenticatedUser, same(authentication.user));
    expect(authentication.deletedUser, same(authentication.user));
    expect(
      events.indexOf('reauth-google'),
      lessThan(events.indexOf('delete-private')),
    );
  });

  test('Google cancellation changes nothing', () async {
    authentication.googleCancelled = true;

    await expectLater(
      service.deleteAccount(AccountReauthenticationMethod.google),
      throwsA(
        isA<AccountDeletionException>().having(
          (value) => value.error,
          'error',
          AccountDeletionError.cancelled,
        ),
      ),
    );

    expect(store.users, isNotEmpty);
    expect(store.profiles, containsAll(['child', 'self-profile']));
    expect(store.privateDocuments, isNotEmpty);
    expect(authentication.deletedUser, isNull);
  });

  for (final role in [UserAccountRole.admin, UserAccountRole.superAdmin]) {
    test('$role deletion is blocked before reauthentication', () async {
      store.users['member'] = _record(role: role);

      await expectLater(
        service.deleteAccount(
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

      expect(authentication.reauthenticateCalls, 0);
      expect(store.privateDeleteCalls, 0);
      expect(authentication.deleteCalls, 0);
    });
  }

  test('repeated calls share one deletion operation', () async {
    store.pauseDeletion = Completer<void>();
    final first = service.deleteAccount(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );
    final second = service.deleteAccount(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );

    expect(second, same(first));
    await Future<void>.delayed(Duration.zero);
    expect(authentication.reauthenticateCalls, 1);
    store.pauseDeletion!.complete();
    await Future.wait([first, second]);
    expect(authentication.deleteCalls, 1);
  });

  test('unlinked profiles are not deleted', () async {
    await service.deleteAccount(
      AccountReauthenticationMethod.password,
      password: 'correct-password',
    );

    expect(store.profiles, {'unlinked-profile'});
  });

  test(
    'Auth deletion failure is safe and does not expose credentials',
    () async {
      authentication.failAuthDeletion = true;

      await expectLater(
        service.deleteAccount(
          AccountReauthenticationMethod.password,
          password: 'correct-password',
        ),
        throwsA(
          isA<AccountDeletionException>()
              .having(
                (value) => value.firestoreDeletionCompleted,
                'Firestore completed',
                isTrue,
              )
              .having(
                (value) => value.message,
                'safe message',
                allOf(
                  isNot(contains('correct-password')),
                  isNot(contains('member@example.com')),
                  isNot(contains('token-value')),
                ),
              ),
        ),
      );

      expect(events.last, 'delete-auth');
    },
  );
  test('account deletion ownership is exclusive and location-bound', () {
    final account = _record();
    expect(
      accountOwnsDeletionProfile(account, {
        'locationId': 'cheshire',
        'guardianUserIds': ['member'],
      }),
      isTrue,
    );
    expect(
      accountOwnsDeletionProfile(account, {
        'locationId': 'cheshire',
        'guardianUserIds': ['member', 'other'],
      }),
      isFalse,
    );
    expect(
      accountOwnsDeletionProfile(account, {
        'locationId': 'cheshire',
        'linkedUserId': 'member',
        'guardianUserIds': <String>[],
      }),
      isTrue,
    );
    expect(
      accountOwnsDeletionProfile(account, {
        'locationId': 'other',
        'linkedUserId': 'member',
        'guardianUserIds': <String>[],
      }),
      isFalse,
    );
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

class _FakeDeletionAuthentication implements AccountDeletionAuthentication {
  _FakeDeletionAuthentication(this.events);

  final List<String> events;
  final User user = _FakeUser();
  int currentUserReads = 0;
  int reauthenticateCalls = 0;
  int deleteCalls = 0;
  int signOutCalls = 0;
  bool googleCancelled = false;
  bool failAuthDeletion = false;
  User? reauthenticatedUser;
  User? deletedUser;

  @override
  User? get currentUser {
    currentUserReads++;
    return user;
  }

  @override
  Set<AccountReauthenticationMethod> methodsFor(User user) => const {
    AccountReauthenticationMethod.password,
    AccountReauthenticationMethod.google,
  };

  @override
  Future<void> reauthenticate(
    User user,
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    reauthenticateCalls++;
    reauthenticatedUser = user;
    if (method == AccountReauthenticationMethod.password) {
      events.add('reauth-password');
      if (password != 'correct-password') {
        throw const AccountDeletionException(
          AccountDeletionError.incorrectPassword,
          'The current password is incorrect.',
        );
      }
      return;
    }
    if (method == AccountReauthenticationMethod.google) {
      events.add('reauth-google');
      if (googleCancelled) {
        throw const AccountDeletionException(
          AccountDeletionError.cancelled,
          'Google verification was cancelled. Nothing was deleted.',
        );
      }
      return;
    }
    throw const AccountDeletionException(
      AccountDeletionError.unsupportedProvider,
      'Apple account verification is not available yet.',
    );
  }

  @override
  Future<void> revokeProviderToken(
    User user,
    AccountReauthenticationMethod method,
  ) async {}

  @override
  Future<void> delete(User user) async {
    deleteCalls++;
    deletedUser = user;
    events.add('delete-auth');
    if (failAuthDeletion) {
      throw const AccountDeletionException(
        AccountDeletionError.recentLoginRequired,
        'internal-token-value',
      );
    }
  }
}

class _FakeDeletionStore implements AccountDeletionStore {
  _FakeDeletionStore(this.events);

  final List<String> events;
  final users = <String, AccountDeletionRecord>{'member': _record()};
  final profiles = <String>{'child', 'self-profile', 'unlinked-profile'};
  final privateDocuments = <String>{
    'pushDevices/install',
    'notificationReads/notice',
  };
  int privateDeleteCalls = 0;
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
    events.add('delete-profiles-and-user');
    profiles.removeAll(account.linkedStudentProfileIds);
    users.remove(account.uid);
  }
}

class _FakeUser implements User {
  @override
  String get uid => 'member';

  @override
  String? get email => 'member@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
