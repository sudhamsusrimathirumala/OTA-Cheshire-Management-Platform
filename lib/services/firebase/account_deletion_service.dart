import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../models/user_account.dart';
import '../firestore/firestore_collections.dart';

enum AccountReauthenticationMethod { password, google }

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

class AccountDeletionAuthorization {
  const AccountDeletionAuthorization({
    required this.uid,
    required this.method,
    required this.expiresAt,
  });

  final String uid;
  final AccountReauthenticationMethod method;
  final DateTime expiresAt;
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

class AccountDeletionIdentity {
  const AccountDeletionIdentity({
    required this.uid,
    required this.email,
    required this.methods,
  });

  final String uid;
  final String? email;
  final Set<AccountReauthenticationMethod> methods;
}

abstract interface class AccountDeletionAuthGateway {
  AccountDeletionIdentity? get currentIdentity;
  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithGoogle();
  Future<void> deleteCurrentUser();
}

abstract interface class AccountDeletionStore {
  Future<AccountDeletionRecord?> loadAccount(String uid);
  Future<void> deletePrivateDocuments(String uid);
  Future<void> deleteLinkedProfilesAndUser(AccountDeletionRecord account);
}

class AccountDeletionService {
  AccountDeletionService({
    required this.authGateway,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountDeletionAuthGateway authGateway;
  final AccountDeletionStore store;
  final DateTime Function() _clock;
  Future<void>? _activeDeletion;

  Set<AccountReauthenticationMethod> get availableMethods =>
      authGateway.currentIdentity?.methods ?? const {};

  Future<AccountDeletionAuthorization> reauthenticate(
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    final identity = authGateway.currentIdentity;
    if (identity == null) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before deleting your account.',
      );
    }
    final account = await store.loadAccount(identity.uid);
    _validateMemberAccount(account);
    return _reauthenticateIdentity(identity, method, password: password);
  }

  Future<AccountDeletionAuthorization> reauthenticateRemainingSignIn(
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    final identity = authGateway.currentIdentity;
    if (identity == null) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before removing the remaining sign-in account.',
        firestoreDeletionCompleted: true,
      );
    }
    return _reauthenticateIdentity(identity, method, password: password);
  }

  Future<AccountDeletionAuthorization> _reauthenticateIdentity(
    AccountDeletionIdentity identity,
    AccountReauthenticationMethod method, {
    String? password,
  }) async {
    if (!identity.methods.contains(method)) {
      throw const AccountDeletionException(
        AccountDeletionError.unsupportedProvider,
        'Choose a sign-in method currently connected to this account.',
      );
    }
    if (method == AccountReauthenticationMethod.password) {
      final value = password ?? '';
      if (value.isEmpty) {
        throw const AccountDeletionException(
          AccountDeletionError.incorrectPassword,
          'Enter your current password.',
        );
      }
      await authGateway.reauthenticateWithPassword(value);
    } else {
      await authGateway.reauthenticateWithGoogle();
    }
    return AccountDeletionAuthorization(
      uid: identity.uid,
      method: method,
      expiresAt: _clock().add(const Duration(minutes: 5)),
    );
  }

  Future<void> deleteAccount(AccountDeletionAuthorization authorization) {
    final active = _activeDeletion;
    if (active != null) return active;
    final operation = _deleteAccount(authorization);
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
    AccountDeletionAuthorization authorization,
  ) async {
    final identity = authGateway.currentIdentity;
    if (identity == null || identity.uid != authorization.uid) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before deleting your account.',
      );
    }
    if (_clock().isAfter(authorization.expiresAt)) {
      throw const AccountDeletionException(
        AccountDeletionError.recentLoginRequired,
        'Please verify your sign-in again before deleting your account.',
      );
    }

    final account = await store.loadAccount(identity.uid);
    _validateMemberAccount(account);
    await store.deletePrivateDocuments(identity.uid);
    await store.deleteLinkedProfilesAndUser(account!);
    try {
      await authGateway.deleteCurrentUser();
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

  Future<void> retryAuthenticationDeletion(
    AccountDeletionAuthorization authorization,
  ) async {
    final identity = authGateway.currentIdentity;
    if (identity == null || identity.uid != authorization.uid) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before removing the remaining sign-in account.',
        firestoreDeletionCompleted: true,
      );
    }
    if (_clock().isAfter(authorization.expiresAt)) {
      throw const AccountDeletionException(
        AccountDeletionError.recentLoginRequired,
        'Please verify your sign-in again before removing the remaining '
        'sign-in account.',
        firestoreDeletionCompleted: true,
      );
    }
    try {
      await authGateway.deleteCurrentUser();
    } on AccountDeletionException catch (error) {
      throw AccountDeletionException(
        error.error,
        'The remaining sign-in account could not be removed. Try again.',
        firestoreDeletionCompleted: true,
      );
    } catch (_) {
      throw const AccountDeletionException(
        AccountDeletionError.authenticationDeletionFailed,
        'The remaining sign-in account could not be removed. Try again.',
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

class FirebaseAccountDeletionAuthGateway implements AccountDeletionAuthGateway {
  FirebaseAccountDeletionAuthGateway({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  AccountDeletionIdentity? get currentIdentity {
    final user = _auth.currentUser;
    if (user == null) return null;
    final providers = user.providerData
        .map((value) => value.providerId)
        .toSet();
    return AccountDeletionIdentity(
      uid: user.uid,
      email: user.email,
      methods: {
        if (providers.contains(EmailAuthProvider.PROVIDER_ID))
          AccountReauthenticationMethod.password,
        if (providers.contains(GoogleAuthProvider.PROVIDER_ID))
          AccountReauthenticationMethod.google,
      },
    );
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
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

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'Sign in again before deleting your account.',
      );
    }
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
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        AccountDeletionError.unauthenticated,
        'The sign-in account is already unavailable.',
      );
    }
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
  static const _privateSubcollections = ['pushDevices', 'notificationReads'];

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
      final guardianIds = data?['guardianUserIds'];
      final ownsProfile =
          data != null &&
          data['locationId'] == account.locationId &&
          (data['linkedUserId'] == account.uid ||
              (guardianIds is List && guardianIds.contains(account.uid)));
      if (!ownsProfile) {
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

AccountDeletionService createFirebaseAccountDeletionService() =>
    AccountDeletionService(
      authGateway: FirebaseAccountDeletionAuthGateway(),
      store: FirestoreAccountDeletionStore(),
    );
