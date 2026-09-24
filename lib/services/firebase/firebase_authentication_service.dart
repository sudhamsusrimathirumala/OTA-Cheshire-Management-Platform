import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'apple_authentication.dart';
import 'web_authentication.dart';

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
  providerDisabled,
  appConfiguration,
  googleCancelled,
  appleCancelled,
  providerConflict,
  registrationRequired,
  unknownFailure,
}

class AuthenticationException implements Exception {
  const AuthenticationException(
    this.error,
    this.message, {
    this.diagnosticCode,
    this.diagnosticMessage,
  });

  final AuthenticationError error;
  final String message;
  final String? diagnosticCode;
  final String? diagnosticMessage;

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
  Future<User?> refreshUser();
  Future<void> signOut();
}

abstract interface class AppleAuthenticationService {
  Future<UserCredential> signInWithApple();
  Future<String> reauthenticateWithApple(User user);
  Future<void> revokeAppleToken(String authorizationCode);
}

abstract interface class AuthenticationClaimsService {
  Future<Map<String, Object?>> currentUserClaims();
}

abstract interface class RegistrationAuthenticationService {
  Future<UserCredential> registerWithGoogle();
  Future<UserCredential> registerWithApple();
}

extension AuthenticationClaimsServiceAccess on AuthenticationService {
  AuthenticationClaimsService? get authenticationClaims =>
      this is AuthenticationClaimsService
      ? this as AuthenticationClaimsService
      : null;
}

extension AppleAuthenticationServiceAccess on AuthenticationService {
  AppleAuthenticationService? get appleAuthentication =>
      this is AppleAuthenticationService
      ? this as AppleAuthenticationService
      : null;
}

extension RegistrationAuthenticationServiceAccess on AuthenticationService {
  RegistrationAuthenticationService? get registrationAuthentication =>
      this is RegistrationAuthenticationService
      ? this as RegistrationAuthenticationService
      : null;
}

class FirebaseAuthenticationService
    implements
        AuthenticationService,
        AppleAuthenticationService,
        AuthenticationClaimsService,
        RegistrationAuthenticationService {
  FirebaseAuthenticationService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    AppleAuthenticationCoordinator? appleAuthentication,
    WebAuthentication? webAuthentication,
    bool? isWeb,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _appleAuthentication =
           appleAuthentication ?? AppleAuthenticationCoordinator(),
       _webAuthentication =
           webAuthentication ?? const FirebaseWebAuthentication(),
       _isWeb = isWeb ?? kIsWeb;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final AppleAuthenticationCoordinator _appleAuthentication;
  final WebAuthentication _webAuthentication;
  final bool _isWeb;
  Future<void>? _googleInitialization;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> authStateChanges() => _auth.userChanges();

  @override
  Future<Map<String, Object?>> currentUserClaims() async {
    final user = _auth.currentUser;
    if (user == null) return const <String, Object?>{};
    final result = await user.getIdTokenResult();
    return Map<String, Object?>.unmodifiable(
      result.claims ?? const <String, Object?>{},
    );
  }

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
  Future<UserCredential> signInWithGoogle() =>
      _signInWithGoogle(allowAccountCreation: false);

  @override
  Future<UserCredential> registerWithGoogle() =>
      _signInWithGoogle(allowAccountCreation: true);

  Future<UserCredential> _signInWithGoogle({
    required bool allowAccountCreation,
  }) async {
    try {
      final UserCredential result;
      if (_isWeb) {
        result = await _webAuthentication.signInWithGoogle(_auth);
      } else {
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
        result = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      if (shouldRejectNewProviderIdentity(
        isNewUser: result.additionalUserInfo?.isNewUser == true,
        allowAccountCreation: allowAccountCreation,
      )) {
        await _rejectUnexpectedProviderRegistration(
          result,
          providerCleanup: _isWeb ? null : _googleSignIn.signOut,
        );
      }
      return result;
    } on GoogleSignInException catch (error) {
      throw mapGoogleSignInException(error);
    } on FirebaseAuthException catch (error) {
      throw _isWeb
          ? mapGoogleWebAuthException(error)
          : mapFirebaseAuthException(error);
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
  Future<UserCredential> signInWithApple() =>
      _signInWithApple(allowAccountCreation: false);

  @override
  Future<UserCredential> registerWithApple() =>
      _signInWithApple(allowAccountCreation: true);

  Future<UserCredential> _signInWithApple({
    required bool allowAccountCreation,
  }) async {
    try {
      final request = await _appleAuthentication.createRequest();
      final result = await _auth.signInWithCredential(request.credential);
      if (shouldRejectNewProviderIdentity(
        isNewUser: result.additionalUserInfo?.isNewUser == true,
        allowAccountCreation: allowAccountCreation,
      )) {
        await _rejectUnexpectedProviderRegistration(
          result,
          revokeAppleAuthorizationCode: request.authorizationCode,
        );
      }
      return result;
    } on AppleAuthorizationCancelled {
      throw const AuthenticationException(
        AuthenticationError.appleCancelled,
        'Sign in with Apple was cancelled.',
      );
    } on FirebaseAuthException catch (error) {
      throw mapFirebaseAuthException(error);
    } catch (_) {
      throw const AuthenticationException(
        AuthenticationError.unknownFailure,
        'Sign in with Apple could not be completed.',
      );
    }
  }

  Future<Never> _rejectUnexpectedProviderRegistration(
    UserCredential credential, {
    Future<void> Function()? providerCleanup,
    String? revokeAppleAuthorizationCode,
  }) async {
    try {
      if (revokeAppleAuthorizationCode != null) {
        await _auth.revokeTokenWithAuthorizationCode(
          revokeAppleAuthorizationCode,
        );
      }
      await credential.user?.delete();
    } catch (_) {
      // Firestore still rejects under-age onboarding. Always end this session,
      // even if provider cleanup cannot remove a just-created Auth record.
    } finally {
      try {
        await _auth.signOut();
      } catch (_) {
        // The new Auth user may already have been deleted.
      }
      try {
        await providerCleanup?.call();
      } catch (_) {
        // Provider-session cleanup is best effort after Firebase sign-out.
      }
    }
    throw const AuthenticationException(
      AuthenticationError.registrationRequired,
      'This provider account is not registered. Use Create Account to '
      'complete the age check before signing in.',
    );
  }

  @override
  Future<String> reauthenticateWithApple(User user) async {
    final request = await _appleAuthentication.createRequest();
    await user.reauthenticateWithCredential(request.credential);
    return request.authorizationCode;
  }

  @override
  Future<void> revokeAppleToken(String authorizationCode) =>
      _auth.revokeTokenWithAuthorizationCode(authorizationCode);

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
      if (_isWeb) return;
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

bool shouldRejectNewProviderIdentity({
  required bool isNewUser,
  required bool allowAccountCreation,
}) => isNewUser && !allowAccountCreation;

AuthenticationException mapGoogleSignInException(GoogleSignInException error) {
  final diagnosticCode =
      'google-${error.code.name.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '-${match.group(0)!.toLowerCase()}')}';
  return switch (error.code) {
    GoogleSignInExceptionCode.canceled ||
    GoogleSignInExceptionCode.interrupted => const AuthenticationException(
      AuthenticationError.googleCancelled,
      'Google Sign-In was cancelled.',
      diagnosticCode: 'google-cancelled',
    ),
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError =>
      AuthenticationException(
        AuthenticationError.appConfiguration,
        'Google Sign-In is not configured correctly. Contact the academy. '
        'Reference: google-configuration.',
        diagnosticCode: diagnosticCode,
      ),
    GoogleSignInExceptionCode.uiUnavailable => AuthenticationException(
      AuthenticationError.unknownFailure,
      'Google Sign-In is temporarily unavailable on this device. '
      'Reference: google-ui-unavailable.',
      diagnosticCode: diagnosticCode,
    ),
    _ => AuthenticationException(
      AuthenticationError.unknownFailure,
      'Google Sign-In could not be completed. '
      'Reference: google-sign-in-failed.',
      diagnosticCode: diagnosticCode,
    ),
  };
}

AuthenticationException mapGoogleWebAuthException(FirebaseAuthException error) {
  if (const {
    'popup-closed-by-user',
    'cancelled-popup-request',
    'web-context-cancelled',
  }.contains(error.code)) {
    return const AuthenticationException(
      AuthenticationError.googleCancelled,
      'Google Sign-In was cancelled.',
      diagnosticCode: 'google-cancelled',
    );
  }
  return mapFirebaseAuthException(error);
}

AuthenticationException mapFirebaseAuthException(FirebaseAuthException error) {
  final diagnosticCode = sanitizedAuthenticationDiagnosticCode(error.code);
  final diagnosticMessage = sanitizedAuthenticationDiagnosticMessage(
    error.message,
    plugin: error.plugin,
  );
  final category = switch (diagnosticCode) {
    'invalid-email' => AuthenticationError.invalidEmail,
    'weak-password' => AuthenticationError.weakPassword,
    'email-already-in-use' => AuthenticationError.emailAlreadyInUse,
    'invalid-credential' => AuthenticationError.invalidCredentials,
    'wrong-password' => AuthenticationError.wrongPassword,
    'user-not-found' => AuthenticationError.userNotFound,
    'user-disabled' => AuthenticationError.accountDisabled,
    'too-many-requests' => AuthenticationError.tooManyAttempts,
    'network-request-failed' => AuthenticationError.networkFailure,
    'operation-not-allowed' => AuthenticationError.providerDisabled,
    'app-not-authorized' ||
    'invalid-api-key' => AuthenticationError.appConfiguration,
    'account-exists-with-different-credential' ||
    'credential-already-in-use' ||
    'provider-already-linked' => AuthenticationError.providerConflict,
    _ => AuthenticationError.unknownFailure,
  };
  return AuthenticationException(
    category,
    switch (category) {
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
      AuthenticationError.providerDisabled =>
        'Email and password sign-in is not enabled for this app.',
      AuthenticationError.appConfiguration =>
        'This app is not configured correctly for sign-in.',
      AuthenticationError.providerConflict =>
        'This account uses a different sign-in method.',
      _ => 'Sign-in could not be completed. Please try again.',
    },
    diagnosticCode: diagnosticCode,
    diagnosticMessage: diagnosticMessage,
  );
}

String? sanitizedAuthenticationDiagnosticCode(String? code) {
  final raw = code?.trim();
  if (raw == null ||
      raw.isEmpty ||
      raw.length > 64 ||
      raw.contains('@') ||
      raw.contains('://') ||
      raw.contains('?') ||
      raw.contains('[') ||
      raw.contains(']') ||
      RegExp(r'[A-Za-z0-9]{24,}').hasMatch(raw)) {
    return null;
  }
  final normalized = raw.toLowerCase();
  final sanitized = normalized.replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
  return sanitized.isEmpty ? null : sanitized;
}

String? sanitizedAuthenticationDiagnosticMessage(
  String? message, {
  String? plugin,
}) {
  final value = message?.trim();
  if (value == null || value.isEmpty) return null;

  final upper = value.toUpperCase();
  final lower = value.toLowerCase();
  final marker = switch (upper) {
    _ when upper.contains('CONFIGURATION_NOT_FOUND') =>
      'CONFIGURATION_NOT_FOUND',
    _ when upper.contains('OPERATION_NOT_ALLOWED') => 'OPERATION_NOT_ALLOWED',
    _
        when upper.contains('API_KEY_INVALID') ||
            lower.contains('api key not valid') =>
      'API_KEY_INVALID',
    _ when upper.contains('APP_NOT_AUTHORIZED') => 'APP_NOT_AUTHORIZED',
    _
        when lower.contains(
          'requests from this android client application are blocked',
        ) =>
      'Requests from this Android client application are blocked',
    _
        when lower.contains('network failure') ||
            lower.contains('network request failed') =>
      'NETWORK_FAILURE',
    _ when lower.contains('internal error') => 'INTERNAL_ERROR',
    _ => null,
  };
  if (marker == null) return null;

  final safePlugin = _sanitizedAuthenticationPlugin(plugin);
  return safePlugin == null ? marker : '$marker; plugin=$safePlugin';
}

String? _sanitizedAuthenticationPlugin(String? plugin) {
  final normalized = plugin?.trim().toLowerCase();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized == 'firebase_auth' ||
      normalized.length > 40 ||
      !RegExp(r'^[a-z0-9_.-]+$').hasMatch(normalized) ||
      RegExp(r'(token|credential|password|api[_-]?key)').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
