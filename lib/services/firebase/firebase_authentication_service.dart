import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthenticationError {
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  invalidCredentials,
  wrongPassword,
  userNotFound,
  accountDisabled,
  tooManyAttempts,
  networkFailure,
  googleCancelled,
  providerConflict,
  unknownFailure,
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.error, this.message);

  final AuthenticationError error;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthenticationService {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signUpWithEmail(String email, String password);
  Future<UserCredential> signInWithEmail(String email, String password);
  Future<UserCredential> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerificationEmail();
  Future<User?> refreshUser();
  Future<void> signOut();
}

class FirebaseAuthenticationService implements AuthenticationService {
  FirebaseAuthenticationService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> authStateChanges() => _auth.userChanges();

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthenticationException(
          AuthenticationError.unknownFailure,
          'Google Sign-In could not verify this account.',
        );
      }
      return await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthenticationException(
          AuthenticationError.googleCancelled,
          'Google Sign-In was cancelled.',
        );
      }
      throw const AuthenticationException(
        AuthenticationError.unknownFailure,
        'Google Sign-In could not be completed.',
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      throw const AuthenticationException(
        AuthenticationError.unknownFailure,
        'Google Sign-In could not be completed.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      // Keep reset responses neutral for account enumeration-sensitive cases.
      if (error.code == 'user-not-found') return;
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthenticationException(
        AuthenticationError.unknownFailure,
        'Sign in again to verify your email.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<User?> refreshUser() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser;
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } on GoogleSignInException {
      // Firebase Auth is canonical; a provider-session cleanup failure must not
      // restore OTA access after Firebase sign-out succeeds.
    }
  }
}

AuthenticationException mapFirebaseAuthException(FirebaseAuthException error) {
  final category = switch (error.code) {
    'invalid-email' => AuthenticationError.invalidEmail,
    'weak-password' => AuthenticationError.weakPassword,
    'email-already-in-use' => AuthenticationError.emailAlreadyInUse,
    'invalid-credential' => AuthenticationError.invalidCredentials,
    'wrong-password' => AuthenticationError.wrongPassword,
    'user-not-found' => AuthenticationError.userNotFound,
    'user-disabled' => AuthenticationError.accountDisabled,
    'too-many-requests' => AuthenticationError.tooManyAttempts,
    'network-request-failed' => AuthenticationError.networkFailure,
    'account-exists-with-different-credential' ||
    'credential-already-in-use' ||
    'provider-already-linked' => AuthenticationError.providerConflict,
    _ => AuthenticationError.unknownFailure,
  };
  return AuthenticationException(category, switch (category) {
    AuthenticationError.invalidEmail => 'Enter a valid email address.',
    AuthenticationError.weakPassword => 'Choose a stronger password.',
    AuthenticationError.emailAlreadyInUse =>
      'An account already uses this email address.',
    AuthenticationError.invalidCredentials ||
    AuthenticationError.wrongPassword ||
    AuthenticationError.userNotFound => 'The email or password is incorrect.',
    AuthenticationError.accountDisabled =>
      'This account is disabled. Contact the academy.',
    AuthenticationError.tooManyAttempts =>
      'Too many attempts. Wait a moment and try again.',
    AuthenticationError.networkFailure =>
      'The network is unavailable. Check your connection and try again.',
    AuthenticationError.providerConflict =>
      'This account uses a different sign-in method.',
    _ => 'Sign-in could not be completed. Please try again.',
  });
}
