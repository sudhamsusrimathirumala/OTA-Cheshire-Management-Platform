import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/services/firebase/account_deletion_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/web_authentication.dart';

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

  test(
    'Web Google deletion verification uses popup reauthentication',
    () async {
      final webAuthentication = _RecordingWebAuthentication();
      final authentication = FirebaseAccountDeletionAuthentication(
        _AppleAuthenticationService(),
        webAuthentication: webAuthentication,
        isWeb: true,
      );
      final user = _ProviderUser(GoogleAuthProvider.PROVIDER_ID);

      await authentication.reauthenticate(
        user,
        AccountReauthenticationMethod.google,
      );

      expect(webAuthentication.reauthenticatedUser, same(user));
    },
  );

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

  test('Apple verification, revocation, and deletion use one user', () async {
    await service.deleteAccount(AccountReauthenticationMethod.apple);

    expect(authentication.reauthenticatedUser, same(authentication.user));
    expect(authentication.revokedUser, same(authentication.user));
    expect(authentication.deletedUser, same(authentication.user));
    expect(
      events,
      orderedEquals([
        'load-account',
        'reauth-apple',
        'revoke-apple',
        'delete-private',
        'delete-profiles-and-user',
        'delete-auth',
      ]),
    );
  });

  test('Apple cancellation changes nothing', () async {
    authentication.appleCancelled = true;

    await expectLater(
      service.deleteAccount(AccountReauthenticationMethod.apple),
      throwsA(
        isA<AccountDeletionException>().having(
          (value) => value.error,
          'error',
          AccountDeletionError.cancelled,
        ),
      ),
    );

    expect(store.users, isNotEmpty);
    expect(store.privateDocuments, isNotEmpty);
    expect(authentication.deletedUser, isNull);
  });

  test('Apple revocation failure performs no destructive deletion', () async {
    authentication.failAppleRevocation = true;

    await expectLater(
      service.deleteAccount(AccountReauthenticationMethod.apple),
      throwsA(
        isA<AccountDeletionException>()
            .having(
              (value) => value.firestoreDeletionCompleted,
              'Firestore completed',
              isFalse,
            )
            .having(
              (value) => value.message,
              'safe message',
              isNot(contains('apple-authorization-code')),
            ),
      ),
    );

    expect(
      events,
      orderedEquals(['load-account', 'reauth-apple', 'revoke-apple']),
    );
    expect(store.users, isNotEmpty);
    expect(store.profiles, containsAll(['child', 'self-profile']));
    expect(store.privateDocuments, isNotEmpty);
    expect(store.privateDeleteCalls, 0);
    expect(authentication.deletedUser, isNull);
  });

  test('Apple revocation fallback requires explicit confirmation', () async {
    authentication.failAppleRevocation = true;
    var confirmationCalls = 0;

    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.apple,
        confirmAppleRevocationFallback: (failure) async {
          confirmationCalls++;
          expect(failure.error, AccountDeletionError.deletionFailed);
          expect(failure.message, isNot(contains('apple-authorization-code')));
          return false;
        },
      ),
      throwsA(
        isA<AccountDeletionException>()
            .having(
              (error) => error.error,
              'error',
              AccountDeletionError.cancelled,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Nothing was deleted'),
            ),
      ),
    );

    expect(confirmationCalls, 1);
    expect(authentication.reauthenticateCalls, 1);
    expect(events, ['load-account', 'reauth-apple', 'revoke-apple']);
    expect(store.privateDeleteCalls, 0);
    expect(store.users, isNotEmpty);
    expect(store.profiles, containsAll(['child', 'self-profile']));
    expect(authentication.deletedUser, isNull);
  });

  test('Apple manual revocation fallback continues after confirmation', () async {
    authentication.failAppleRevocation = true;
    var confirmationCalls = 0;

    await service.deleteAccount(
      AccountReauthenticationMethod.apple,
      confirmAppleRevocationFallback: (failure) async {
        confirmationCalls++;
        expect(failure.error, AccountDeletionError.deletionFailed);
        expect(authentication.reauthenticatedUser, same(authentication.user));
        expect(store.users, isNotEmpty);
        expect(store.privateDeleteCalls, 0);
        return true;
      },
    );

    expect(confirmationCalls, 1);
    expect(authentication.reauthenticateCalls, 1);
    expect(
      events,
      orderedEquals([
        'load-account',
        'reauth-apple',
        'revoke-apple',
        'delete-private',
        'delete-profiles-and-user',
        'delete-auth',
      ]),
    );
    expect(store.users, isEmpty);
    expect(store.privateDocuments, isEmpty);
    expect(authentication.deletedUser, same(authentication.user));
  });

  test('Apple revocation success never asks for fallback', () async {
    await service.deleteAccount(
      AccountReauthenticationMethod.apple,
      confirmAppleRevocationFallback: (_) async {
        fail('A successful revocation must not trigger fallback.');
      },
    );

    expect(authentication.reauthenticateCalls, 1);
    expect(authentication.deleteCalls, 1);
  });

  test('Apple reauthentication failure never offers fallback', () async {
    authentication.appleCancelled = true;
    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.apple,
        confirmAppleRevocationFallback: (_) async {
          fail('Fallback must not bypass Apple identity verification.');
        },
      ),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.error,
          'error',
          AccountDeletionError.cancelled,
        ),
      ),
    );
    expect(store.privateDeleteCalls, 0);
    expect(authentication.deleteCalls, 0);
  });

  test('Failure in the confirmation callback fails closed', () async {
    authentication.failAppleRevocation = true;

    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.apple,
        confirmAppleRevocationFallback: (_) async {
          throw StateError('confirmation unavailable');
        },
      ),
      throwsA(isA<StateError>()),
    );

    expect(store.privateDeleteCalls, 0);
    expect(store.users, isNotEmpty);
    expect(authentication.deleteCalls, 0);
  });

  test('Privileged Apple user cannot reach fallback', () async {
    authentication.failAppleRevocation = true;
    store.users['member'] = _record(role: UserAccountRole.admin);

    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.apple,
        confirmAppleRevocationFallback: (_) async {
          fail('Admin protection must run before fallback.');
        },
      ),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.error,
          'error',
          AccountDeletionError.privilegedAccount,
        ),
      ),
    );

    expect(authentication.reauthenticateCalls, 0);
    expect(store.privateDeleteCalls, 0);
  });

  test('Apple fallback keeps Auth deletion failure retryable', () async {
    authentication.failAppleRevocation = true;
    authentication.failAuthDeletion = true;

    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.apple,
        confirmAppleRevocationFallback: (_) async => true,
      ),
      throwsA(
        isA<AccountDeletionException>().having(
          (error) => error.firestoreDeletionCompleted,
          'Firestore completed',
          isTrue,
        ),
      ),
    );

    expect(store.users, isEmpty);
    authentication.failAuthDeletion = false;
    events.clear();
    await service.deleteAccount(
      AccountReauthenticationMethod.apple,
      confirmAppleRevocationFallback: (_) async => true,
    );
    expect(
      events,
      ['load-account', 'reauth-apple', 'revoke-apple', 'delete-auth'],
    );
    expect(authentication.deleteCalls, 2);
  });

  test('Apple reauthentication errors include a safe stage reference', () {
    final error = mapAppleDeletionAuthException(
      FirebaseAuthException(code: 'invalid-credential'),
      stage: 'apple-reauth',
    );

    expect(error.error, AccountDeletionError.deletionFailed);
    expect(error.message, contains('Reference: apple-reauth-invalid-credential.'));
    expect(error.message, isNot(contains('@')));
  });

  test('Apple revocation errors identify the revocation stage', () {
    final error = mapAppleDeletionAuthException(
      FirebaseAuthException(code: 'invalid-credential'),
      stage: 'apple-revoke',
    );

    expect(error.error, AccountDeletionError.deletionFailed);
    expect(error.message, contains('Apple authorization could not be revoked.'));
    expect(error.message, contains('Reference: apple-revoke-invalid-credential.'));
  });

  test('Apple revocation surfaces only a fixed, safe detail marker', () {
    final error = mapAppleDeletionAuthException(
      FirebaseAuthException(
        code: 'invalid-credential',
        message:
            'Error getting access token from Apple. OAuth2 redirect uri is '
            'https://example.com/?token=private-authorization-code '
            'for parent@example.com.',
      ),
      stage: 'apple-revoke',
    );

    expect(error.error, AccountDeletionError.deletionFailed);
    expect(error.firestoreDeletionCompleted, isFalse);
    expect(error.message, contains('Reference: apple-revoke-invalid-credential.'));
    expect(error.message, contains('Detail: apple-redirect-uri.'));
    expect(error.message, isNot(contains('private-authorization-code')));
    expect(error.message, isNot(contains('parent@example.com')));
    expect(error.message, isNot(contains('https://')));
  });

  test('Apple revocation classification is allowlisted', () {
    final expected = <String, String>{
      'Code flow is not enabled for Apple.': 'apple-code-flow-disabled',
      'Error getting access token from Apple.': 'apple-token-exchange',
      'invalid_client_secret': 'apple-client-secret',
      'invalid_client': 'apple-client',
      'invalid_grant': 'apple-grant',
      'Invalid OAuth response from apple.com': 'apple-oauth-response',
      'Authorization code has expired': 'apple-code-expired',
      'Invalid authorization code': 'apple-code-invalid',
      'CONFIGURATION_NOT_FOUND': 'firebase-configuration',
      'An internal error has occurred': 'firebase-internal-error',
      'The supplied auth credential is malformed or expired':
          'provider-detail-unavailable',
    };

    for (final entry in expected.entries) {
      expect(
        appleRevocationDiagnosticMarker(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
    expect(
      appleRevocationDiagnosticMarker(
        'Unrecognized error from parent@example.com: '
        'authorization_code=very-private-value',
      ),
      'provider-detail-unavailable',
    );
    expect(appleRevocationDiagnosticMarker(null), 'provider-detail-unavailable');
  });

  test('Unspecified Apple revocation failures do not expose raw details', () {
    final error = mapAppleDeletionAuthException(
      FirebaseAuthException(
        code: 'invalid-credential',
        message:
            'The supplied auth credential is malformed or expired. '
            'secret=very-private-value',
      ),
      stage: 'apple-revoke',
    );

    expect(error.message, contains('Detail: provider-detail-unavailable.'));
    expect(error.message, isNot(contains('very-private-value')));
    expect(error.message, contains('Reference: apple-revoke-invalid-credential.'));
  });

  test('Apple cancellation remains non-destructive and identifiable', () {
    final error = mapAppleDeletionAuthException(
      FirebaseAuthException(code: 'web-context-cancelled'),
      stage: 'apple-reauth',
    );

    expect(error.error, AccountDeletionError.cancelled);
    expect(error.message, contains('Nothing was deleted.'));
    expect(error.message, contains('apple-reauth-web-context-cancelled'));
  });

  test('Apple deletion verification is available when supported', () {
    final authentication = FirebaseAccountDeletionAuthentication(
      _AppleAuthenticationService(),
      appleSupported: true,
    );

    expect(
      authentication.methodsFor(_ProviderUser(AppleAuthProvider.PROVIDER_ID)),
      contains(AccountReauthenticationMethod.apple),
    );
  });

  test('Apple deletion verification is hidden when unsupported', () {
    final authentication = FirebaseAccountDeletionAuthentication(
      _AppleAuthenticationService(),
      appleSupported: false,
    );

    expect(
      authentication.methodsFor(_ProviderUser(AppleAuthProvider.PROVIDER_ID)),
      isNot(contains(AccountReauthenticationMethod.apple)),
    );
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
    'deletion resumes when the final linked profile is already gone',
    () async {
      store.users['member'] = _record(
        linkedStudentProfileIds: const [],
        deletionInProgress: true,
      );

      await service.deleteAccount(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );

      expect(store.users, isEmpty);
      expect(authentication.deletedUser, same(authentication.user));
    },
  );

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

  test(
    'retry deletes Auth when the Firestore account is already absent',
    () async {
      authentication.failAuthDeletion = true;
      await expectLater(
        service.deleteAccount(
          AccountReauthenticationMethod.password,
          password: 'correct-password',
        ),
        throwsA(isA<AccountDeletionException>()),
      );

      authentication.failAuthDeletion = false;
      events.clear();
      await service.deleteAccount(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      );

      expect(
        events,
        orderedEquals(['load-account', 'reauth-password', 'delete-auth']),
      );
      expect(authentication.deleteCalls, 2);
    },
  );

  test('Apple retry reauthenticates and revokes without Firestore', () async {
    authentication.failAuthDeletion = true;
    await expectLater(
      service.deleteAccount(AccountReauthenticationMethod.apple),
      throwsA(isA<AccountDeletionException>()),
    );

    authentication.failAuthDeletion = false;
    events.clear();
    await service.deleteAccount(AccountReauthenticationMethod.apple);

    expect(
      events,
      orderedEquals([
        'load-account',
        'reauth-apple',
        'revoke-apple',
        'delete-auth',
      ]),
    );
    expect(store.privateDeleteCalls, 1);
    expect(authentication.deleteCalls, 2);
  });

  test('repeated Auth deletion failure remains retryable', () async {
    authentication.failAuthDeletion = true;

    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        service.deleteAccount(
          AccountReauthenticationMethod.password,
          password: 'correct-password',
        ),
        throwsA(
          isA<AccountDeletionException>().having(
            (value) => value.firestoreDeletionCompleted,
            'Firestore completed',
            isTrue,
          ),
        ),
      );
    }

    expect(authentication.reauthenticateCalls, 2);
    expect(authentication.deleteCalls, 2);
    expect(store.privateDeleteCalls, 1);
  });

  test('malformed existing member account remains rejected', () async {
    store.users['member'] = _record(linkedStudentProfileIds: const []);

    await expectLater(
      service.deleteAccount(
        AccountReauthenticationMethod.password,
        password: 'correct-password',
      ),
      throwsA(
        isA<AccountDeletionException>().having(
          (value) => value.error,
          'error',
          AccountDeletionError.invalidAccountData,
        ),
      ),
    );

    expect(authentication.reauthenticateCalls, 0);
    expect(authentication.deleteCalls, 0);
  });

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
  List<String> linkedStudentProfileIds = const ['child', 'self-profile'],
  bool deletionInProgress = false,
}) => AccountDeletionRecord(
  uid: 'member',
  role: role,
  locationId: 'cheshire',
  linkedStudentProfileIds: linkedStudentProfileIds,
  deletionInProgress: deletionInProgress,
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
  bool appleCancelled = false;
  bool failAppleRevocation = false;
  bool failAuthDeletion = false;
  User? reauthenticatedUser;
  User? deletedUser;
  User? revokedUser;

  @override
  User? get currentUser {
    currentUserReads++;
    return user;
  }

  @override
  Set<AccountReauthenticationMethod> methodsFor(User user) => const {
    AccountReauthenticationMethod.password,
    AccountReauthenticationMethod.google,
    AccountReauthenticationMethod.apple,
  };

  @override
  Future<AccountDeletionProviderProof?> reauthenticate(
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
      return null;
    }
    if (method == AccountReauthenticationMethod.google) {
      events.add('reauth-google');
      if (googleCancelled) {
        throw const AccountDeletionException(
          AccountDeletionError.cancelled,
          'Google verification was cancelled. Nothing was deleted.',
        );
      }
      return null;
    }
    events.add('reauth-apple');
    if (appleCancelled) {
      throw const AccountDeletionException(
        AccountDeletionError.cancelled,
        'Apple verification was cancelled. Nothing was deleted.',
      );
    }
    return const AccountDeletionProviderProof.apple('apple-authorization-code');
  }

  @override
  Future<void> revokeProviderToken(
    User user,
    AccountReauthenticationMethod method,
    AccountDeletionProviderProof? proof,
  ) async {
    if (method != AccountReauthenticationMethod.apple) return;
    revokedUser = user;
    events.add('revoke-apple');
    expect(proof?.appleAuthorizationCode, 'apple-authorization-code');
    if (failAppleRevocation) throw StateError('apple-authorization-code');
  }

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

class _ProviderUser implements User {
  _ProviderUser(String providerId)
    : _providerData = [_ProviderInfo(providerId)];

  final List<UserInfo> _providerData;

  @override
  List<UserInfo> get providerData => _providerData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProviderInfo implements UserInfo {
  _ProviderInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AppleAuthenticationService
    implements AuthenticationService, AppleAuthenticationService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> revokeAppleToken(String authorizationCode) async {}

  @override
  Future<String> reauthenticateWithApple(User user) async => 'authorization';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingWebAuthentication implements WebAuthentication {
  User? reauthenticatedUser;

  @override
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) =>
      throw UnimplementedError();

  @override
  Future<void> reauthenticateWithGoogle(User user) async {
    reauthenticatedUser = user;
  }
}
