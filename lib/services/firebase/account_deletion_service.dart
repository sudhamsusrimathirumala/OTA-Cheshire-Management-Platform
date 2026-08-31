import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_account.dart';
import '../firestore/firestore_collections.dart';
import 'firebase_authentication_service.dart';

enum AccountReauthenticationMethod { password, google, apple }

enum AccountDeletionError {
  unauthenticated,
  accountMissing,
  privilegedAccount,
  unsupportedProvider,
  incorrectPassword,
  cancelled,
  recentLoginRequired,
  networkFailure,
  invalidAccountData,
  deletionFailed,
  authenticationDeletionFailed,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(
    this.error,
    this.message, {
    this.firestoreDeletionCompleted = false,
  });

  final AccountDeletionError error;
  final String message;
  final bool firestoreDeletionCompleted;

  @override
  String toString() => message;
}

class AccountDeletionRecord {
  const AccountDeletionRecord({
    required this.uid,
    required this.role,
    required this.locationId,
    required this.linkedStudentProfileIds,
  });

  final String uid;
  final UserAccountRole role;
  final String locationId;
  final List<String> linkedStudentProfileIds;
}

abstract interface class AccountDeletionAuthentication {
  User? get currentUser;
  Set<AccountReauthenticationMethod> methodsFor(User user);
  Future<void> reauthenticate(
    User user,
    AccountReauthenticationMethod method, {
    String? password,
  });
  Future<void> revokeProviderToken(
    User user,
    AccountReauthenticationMethod method,
  );
  Future<void> delete(User user);
}

abstract interface class AccountDeletionStore {
  Future<AccountDeletionRecord?> loadAccount(String uid);
  Future<void> deletePrivateDocuments(String uid);
  Future<void> deleteLinkedProfilesAndUser(AccountDeletionRecord account);
}

class AccountDeletionService {
  AccountDeletionService({required this.authentication, required this.store});

  final AccountDeletionAuthentication authentication;
  final AccountDeletionStore store;
  Future<void>? _activeDeletion;

  Set<AccountReauthenticationMethod> get availableMethods {
    final user = authentication.currentUser;
    return user == null ? const {} : authentication.methodsFor(user);
  }

  Future<void> deleteAccount(
    AccountReauthenticationMethod method, {
    String? password,
  }) {
    final active = _activeDeletion;
    if (active != null) return active;
    final operation = _deleteAccount(method, password: password);
    _activeDeletion = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_activeDeletion, operation)) _activeDeletion = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_activeDeletion, operation)) _activeDeletion = null;
        },
      ),
    );
    return operation;
  }

  Future<void> _deleteAccount(
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    final user = authentication.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before deleting your account.',
      );
    }
    final uid = user.uid;
    final methods = authentication.methodsFor(user);
    if (!methods.contains(method) ||
        method == AccountReauthenticationMethod.apple) {
      throw const AccountDeletionException(
        AccountDeletionError.unsupportedProvider,
        'Choose a sign-in method currently connected to this account.',
      );
    }
    if (method == AccountReauthenticationMethod.password &&
        (password == null || password.isEmpty)) {
      throw const AccountDeletionException(
        AccountDeletionError.incorrectPassword,
        'Enter your current password.',
      );
    }

    final account = await store.loadAccount(uid);
    _validateMemberAccount(account);
    await authentication.reauthenticate(user, method, password: password);
    await authentication.revokeProviderToken(user, method);
    await store.deletePrivateDocuments(uid);
    await store.deleteLinkedProfilesAndUser(account!);
    try {
      await authentication.delete(user);
    } on AccountDeletionException catch (error) {
      throw AccountDeletionException(
        error.error,
        'Your OTA data was deleted, but the sign-in account could not be '
        'removed. Try removing the sign-in account again.',
        firestoreDeletionCompleted: true,
      );
    } catch (_) {
      throw const AccountDeletionException(
        AccountDeletionError.authenticationDeletionFailed,
        'Your OTA data was deleted, but the sign-in account could not be '
        'removed. Try removing the sign-in account again.',
        firestoreDeletionCompleted: true,
      );
    }
  }

  void _validateMemberAccount(AccountDeletionRecord? account) {
    if (account == null) {
      throw const AccountDeletionException(
        AccountDeletionError.accountMissing,
        'Your OTA account record could not be found.',
      );
    }
    if (account.role == UserAccountRole.admin ||
        account.role == UserAccountRole.superAdmin) {
      throw const AccountDeletionException(
        AccountDeletionError.privilegedAccount,
        'Privileged accounts must be removed by another authorized '
        'administrator.',
      );
    }
    final ids = account.linkedStudentProfileIds;
    if (account.locationId.isEmpty ||
        ids.isEmpty ||
        ids.length > 11 ||
        ids.toSet().length != ids.length ||
        ids.any((id) => id.trim().isEmpty)) {
      throw const AccountDeletionException(
        AccountDeletionError.invalidAccountData,
        'Your linked profiles could not be verified. Contact the academy.',
      );
    }
  }
}

class FirebaseAccountDeletionAuthentication
    implements AccountDeletionAuthentication {
  FirebaseAccountDeletionAuthentication(
    this._authentication, {
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final AuthenticationService _authentication;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  User? get currentUser => _authentication.currentUser;

  @override
  Set<AccountReauthenticationMethod> methodsFor(User user) {
    final providers = user.providerData
        .map((value) => value.providerId)
        .toSet();
    return {
      if (providers.contains(EmailAuthProvider.PROVIDER_ID))
        AccountReauthenticationMethod.password,
      if (providers.contains(GoogleAuthProvider.PROVIDER_ID))
        AccountReauthenticationMethod.google,
    };
  }

  @override
  Future<void> reauthenticate(
    User user,
    AccountReauthenticationMethod method, {
    String? password,
  }) => switch (method) {
    AccountReauthenticationMethod.password => _reauthenticateWithPassword(
      user,
      password ?? '',
    ),
    AccountReauthenticationMethod.google => _reauthenticateWithGoogle(user),
    AccountReauthenticationMethod.apple => throw const AccountDeletionException(
      AccountDeletionError.unsupportedProvider,
      'Apple account verification is not available yet.',
    ),
  };

  Future<void> _reauthenticateWithPassword(User user, String password) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AccountDeletionException(
        AccountDeletionError.unsupportedProvider,
        'Password verification is unavailable for this account.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw _mapDeletionAuthException(error, passwordAttempt: true);
    }
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    try {
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AccountDeletionException(
          AccountDeletionError.deletionFailed,
          'Google could not verify this account. Please try again.',
        );
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AccountDeletionException(
          AccountDeletionError.cancelled,
          'Google verification was cancelled. Nothing was deleted.',
        );
      }
      throw const AccountDeletionException(
        AccountDeletionError.deletionFailed,
        'Google verification could not be completed. Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw _mapDeletionAuthException(error);
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException(
        AccountDeletionError.deletionFailed,
        'Google verification could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<void> revokeProviderToken(
    User user,
    AccountReauthenticationMethod method,
  ) async {
    if (method == AccountReauthenticationMethod.apple) {
      throw const AccountDeletionException(
        AccountDeletionError.unsupportedProvider,
        'Apple account deletion is not available yet.',
      );
    }
  }

  @override
  Future<void> delete(User user) async {
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      throw _mapDeletionAuthException(error);
    }
  }
}

class FirestoreAccountDeletionStore implements AccountDeletionStore {
  FirestoreAccountDeletionStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _privateSubcollections = [
    'pushDevices',
    'notificationReads',
    'announcementDeliveries',
  ];

  @override
  Future<AccountDeletionRecord?> loadAccount(String uid) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) return null;
    final role = switch (data['role']) {
      'student' => UserAccountRole.student,
      'parent' => UserAccountRole.parent,
      'admin' => UserAccountRole.admin,
      'superAdmin' => UserAccountRole.superAdmin,
      _ => null,
    };
    final locationId = data['locationId'];
    final linked = data['linkedStudentProfileIds'];
    if (role == null || locationId is! String || linked is! List) {
      throw const AccountDeletionException(
        AccountDeletionError.invalidAccountData,
        'Your OTA account record could not be verified.',
      );
    }
    final ids = linked.whereType<String>().toList(growable: false);
    if (ids.length != linked.length) {
      throw const AccountDeletionException(
        AccountDeletionError.invalidAccountData,
        'Your linked profiles could not be verified. Contact the academy.',
      );
    }
    return AccountDeletionRecord(
      uid: uid,
      role: role,
      locationId: locationId,
      linkedStudentProfileIds: ids,
    );
  }

  @override
  Future<void> deletePrivateDocuments(String uid) async {
    for (final collectionName in _privateSubcollections) {
      while (true) {
        final snapshot = await _firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection(collectionName)
            .limit(400)
            .get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final document in snapshot.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }
  }

  @override
  Future<void> deleteLinkedProfilesAndUser(
    AccountDeletionRecord account,
  ) async {
    final profileReferences = account.linkedStudentProfileIds
        .map(
          (id) => _firestore
              .collection(FirestoreCollections.studentProfiles)
              .doc(id),
        )
        .toList(growable: false);
    final snapshots = await Future.wait(
      profileReferences.map(
        (reference) => reference.get(const GetOptions(source: Source.server)),
      ),
    );
    for (final snapshot in snapshots) {
      final data = snapshot.data();
      if (!accountOwnsDeletionProfile(account, data)) {
        throw const AccountDeletionException(
          AccountDeletionError.invalidAccountData,
          'A linked student profile could not be verified. Contact the '
          'academy before trying again.',
        );
      }
    }

    final batch = _firestore.batch();
    for (final reference in profileReferences) {
      batch.delete(reference);
    }
    batch.delete(
      _firestore.collection(FirestoreCollections.users).doc(account.uid),
    );
    await batch.commit();
  }
}

bool accountOwnsDeletionProfile(
  AccountDeletionRecord account,
  Map<String, dynamic>? data,
) {
  if (data == null || data['locationId'] != account.locationId) return false;
  final guardianIds = data['guardianUserIds'];
  final exclusiveParentOwner =
      data['linkedUserId'] == null &&
      guardianIds is List &&
      guardianIds.length == 1 &&
      guardianIds.single == account.uid;
  final selfOwner =
      data['linkedUserId'] == account.uid &&
      guardianIds is List &&
      guardianIds.isEmpty;
  return exclusiveParentOwner || selfOwner;
}

AccountDeletionException _mapDeletionAuthException(
  FirebaseAuthException error, {
  bool passwordAttempt = false,
}) {
  return switch (error.code) {
    'wrong-password' ||
    'invalid-credential' when passwordAttempt => const AccountDeletionException(
      AccountDeletionError.incorrectPassword,
      'The current password is incorrect.',
    ),
    'requires-recent-login' => const AccountDeletionException(
      AccountDeletionError.recentLoginRequired,
      'Please verify your sign-in again before deleting your account.',
    ),
    'network-request-failed' => const AccountDeletionException(
      AccountDeletionError.networkFailure,
      'The network is unavailable. Check your connection and try again.',
    ),
    _ => const AccountDeletionException(
      AccountDeletionError.deletionFailed,
      'Account verification could not be completed. Please try again.',
    ),
  };
}

AccountDeletionService createFirebaseAccountDeletionService({
  required AuthenticationService authentication,
}) => AccountDeletionService(
  authentication: FirebaseAccountDeletionAuthentication(authentication),
  store: FirestoreAccountDeletionStore(),
);
