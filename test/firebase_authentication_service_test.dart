import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/web_authentication.dart';

void main() {
  test('Web Google provider always asks the user to select an account', () {
    final provider = createGoogleWebAuthProvider();

    expect(provider.providerId, GoogleAuthProvider.PROVIDER_ID);
    expect(provider.parameters, {'prompt': 'select_account'});
  });

  test('Web Google sign-in uses the Firebase popup adapter', () async {
    final auth = _FakeFirebaseAuth();
    final webAuthentication = _RecordingWebAuthentication();
    final service = FirebaseAuthenticationService(
      auth: auth,
      webAuthentication: webAuthentication,
      isWeb: true,
    );

    final credential = await service.signInWithGoogle();

    expect(credential, same(webAuthentication.credential));
    expect(webAuthentication.signInAuth, same(auth));
  });

  test('Web Google login rejects a newly provisioned identity', () async {
    final auth = _FakeFirebaseAuth();
    final user = _FakeUser();
    final webAuthentication = _RecordingWebAuthentication(
      credential: _FakeUserCredential(isNewUser: true, user: user),
    );
    final service = FirebaseAuthenticationService(
      auth: auth,
      webAuthentication: webAuthentication,
      isWeb: true,
    );

    await expectLater(
      service.signInWithGoogle(),
      throwsA(
        isA<AuthenticationException>().having(
          (error) => error.error,
          'error',
          AuthenticationError.registrationRequired,
        ),
      ),
    );

    expect(user.deleteCalls, 1);
    expect(auth.signOutCalls, 1);
  });

  test(
    'Web Google registration permits a newly provisioned identity',
    () async {
      final credential = _FakeUserCredential(isNewUser: true);
      final webAuthentication = _RecordingWebAuthentication(
        credential: credential,
      );
      final service = FirebaseAuthenticationService(
        auth: _FakeFirebaseAuth(),
        webAuthentication: webAuthentication,
        isWeb: true,
      );

      final result = await service.registerWithGoogle();

      expect(result, same(credential));
    },
  );

  test('Web Google popup cancellation remains distinct', () {
    for (final code in [
      'popup-closed-by-user',
      'cancelled-popup-request',
      'web-context-cancelled',
    ]) {
      final error = mapGoogleWebAuthException(
        FirebaseAuthException(code: code),
      );

      expect(error.error, AuthenticationError.googleCancelled);
      expect(error.message, 'Google Sign-In was cancelled.');
    }
  });

  test('Web sign-out only clears the canonical Firebase session', () async {
    final auth = _FakeFirebaseAuth();
    final service = FirebaseAuthenticationService(auth: auth, isWeb: true);

    await service.signOut();

    expect(auth.signOutCalls, 1);
  });

  test('Google configuration failures use a safe actionable reference', () {
    for (final code in [
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError,
    ]) {
      final error = mapGoogleSignInException(
        GoogleSignInException(
          code: code,
          description: 'developer error containing backend details',
        ),
      );

      expect(error.error, AuthenticationError.appConfiguration);
      expect(error.message, contains('Reference: google-configuration'));
      expect(error.message, isNot(contains('backend details')));
      expect(error.diagnosticCode, startsWith('google-'));
      expect(error.diagnosticMessage, isNull);
    }
  });

  test('Google cancellation stays distinct from configuration failures', () {
    final error = mapGoogleSignInException(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    expect(error.error, AuthenticationError.googleCancelled);
    expect(error.message, 'Google Sign-In was cancelled.');
  });

  test('credential failures use a neutral message', () {
    for (final code in [
      'invalid-credential',
      'wrong-password',
      'user-not-found',
    ]) {
      final error = mapFirebaseAuthException(FirebaseAuthException(code: code));
      expect(error.message, 'The email or password is incorrect.');
    }
  });

  test('known authentication failures map to actionable safe categories', () {
    expect(
      mapFirebaseAuthException(
        FirebaseAuthException(code: 'email-already-in-use'),
      ).error,
      AuthenticationError.emailAlreadyInUse,
    );
    expect(
      mapFirebaseAuthException(
        FirebaseAuthException(code: 'network-request-failed'),
      ).error,
      AuthenticationError.networkFailure,
    );
  });

  test('unknown code preserves a safe configuration marker', () {
    final error = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'unknown',
        message: 'An internal error occurred. [ CONFIGURATION_NOT_FOUND ]',
      ),
    );

    expect(error.error, AuthenticationError.unknownFailure);
    expect(error.diagnosticCode, 'unknown');
    expect(error.diagnosticMessage, 'CONFIGURATION_NOT_FOUND');
  });

  test('diagnostic details discard sensitive exception content', () {
    final error = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'unknown',
        message:
            'CONFIGURATION_NOT_FOUND user@example.com '
            'access_token=abcdefghijklmnopqrstuvwxyz0123456789 '
            'https://example.com/login?apiKey=private-value '
            '[credential=private-credential]',
      ),
    );

    expect(error.diagnosticMessage, 'CONFIGURATION_NOT_FOUND');
    final display = authenticationDisplayMessage(
      error,
      includeDiagnostic: true,
    );
    expect(display, contains('Details: CONFIGURATION_NOT_FOUND'));
    expect(display, isNot(contains('user@example.com')));
    expect(display, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
    expect(display, isNot(contains('https://')));
    expect(display, isNot(contains('private-value')));
    expect(display, isNot(contains('private-credential')));
  });

  test('diagnostic sanitizer recognizes only safe failure markers', () {
    final expected = <String, String>{
      'CONFIGURATION_NOT_FOUND': 'CONFIGURATION_NOT_FOUND',
      'OPERATION_NOT_ALLOWED': 'OPERATION_NOT_ALLOWED',
      'API_KEY_INVALID': 'API_KEY_INVALID',
      'APP_NOT_AUTHORIZED': 'APP_NOT_AUTHORIZED',
      'Requests from this Android client application are blocked.':
          'Requests from this Android client application are blocked',
      'A network failure occurred.': 'NETWORK_FAILURE',
      'An internal error occurred.': 'INTERNAL_ERROR',
    };

    for (final entry in expected.entries) {
      expect(sanitizedAuthenticationDiagnosticMessage(entry.key), entry.value);
    }
    expect(
      sanitizedAuthenticationDiagnosticMessage(
        'CONFIGURATION_NOT_FOUND',
        plugin: 'firebase_core',
      ),
      'CONFIGURATION_NOT_FOUND; plugin=firebase_core',
    );
    expect(
      sanitizedAuthenticationDiagnosticMessage(
        'CONFIGURATION_NOT_FOUND',
        plugin: 'api_key_private',
      ),
      'CONFIGURATION_NOT_FOUND',
    );
    expect(
      sanitizedAuthenticationDiagnosticMessage(
        'Unrecognized backend detail user@example.com',
      ),
      isNull,
    );
  });

  test('diagnostic code sanitizer rejects credential-like values', () {
    expect(sanitizedAuthenticationDiagnosticCode('unknown'), 'unknown');
    expect(
      sanitizedAuthenticationDiagnosticCode('Unexpected Backend/Detail'),
      'unexpected-backend-detail',
    );
    expect(sanitizedAuthenticationDiagnosticCode('user@example.com'), isNull);
    expect(
      sanitizedAuthenticationDiagnosticCode(
        'abcdefghijklmnopqrstuvwxyz0123456789',
      ),
      isNull,
    );
    expect(
      sanitizedAuthenticationDiagnosticCode(
        'https://example.com/error?apiKey=private',
      ),
      isNull,
    );
  });

  test('disabled account and provider use actionable safe messages', () {
    final disabledAccount = mapFirebaseAuthException(
      FirebaseAuthException(code: 'user-disabled'),
    );
    expect(disabledAccount.error, AuthenticationError.accountDisabled);
    expect(disabledAccount.message, contains('account is disabled'));

    final disabledProvider = mapFirebaseAuthException(
      FirebaseAuthException(code: 'operation-not-allowed'),
    );
    expect(disabledProvider.error, AuthenticationError.providerDisabled);
    expect(
      disabledProvider.message,
      'Email and password sign-in is not enabled for this app.',
    );
  });

  test('invalid app configuration uses one safe message', () {
    for (final code in ['app-not-authorized', 'invalid-api-key']) {
      final error = mapFirebaseAuthException(FirebaseAuthException(code: code));
      expect(error.error, AuthenticationError.appConfiguration);
      expect(
        error.message,
        'This app is not configured correctly for sign-in.',
      );
      expect(error.diagnosticCode, code);
    }
  });

  test('network failure remains actionable without backend details', () {
    final error = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Connection detail',
      ),
    );
    expect(error.error, AuthenticationError.networkFailure);
    expect(error.message, contains('Check your connection'));
    expect(error.message, isNot(contains('Connection detail')));
  });

  test('unknown Firebase details are hidden but retain a sanitized code', () {
    final error = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'Unexpected Backend/Detail',
        message: 'Sensitive backend detail',
      ),
    );
    expect(error.error, AuthenticationError.unknownFailure);
    expect(error.message, isNot(contains('Sensitive')));
    expect(error.message, isNot(contains('unexpected-backend-detail')));
    expect(error.diagnosticCode, 'unexpected-backend-detail');
  });

  test(
    'debug display includes safe details and release excludes diagnostics',
    () {
      const error = AuthenticationException(
        AuthenticationError.providerDisabled,
        'Email and password sign-in is not enabled for this app.',
        diagnosticCode: 'operation-not-allowed',
        diagnosticMessage: 'OPERATION_NOT_ALLOWED',
      );

      expect(
        authenticationDisplayMessage(error, includeDiagnostic: false),
        error.message,
      );
      final debugDisplay = authenticationDisplayMessage(
        error,
        includeDiagnostic: true,
      );
      expect(debugDisplay, contains('Code: operation-not-allowed'));
      expect(debugDisplay, contains('Details: OPERATION_NOT_ALLOWED'));
    },
  );

  test('known Firebase codes retain their existing user-facing messages', () {
    final expected = <String, String>{
      'invalid-email': 'Enter a valid email address.',
      'weak-password': 'Choose a stronger password.',
      'email-already-in-use': 'An account already uses this email address.',
      'network-request-failed':
          'The network is unavailable. Check your connection and try again.',
      'operation-not-allowed':
          'Email and password sign-in is not enabled for this app.',
      'app-not-authorized': 'This app is not configured correctly for sign-in.',
      'invalid-api-key': 'This app is not configured correctly for sign-in.',
    };

    for (final entry in expected.entries) {
      expect(
        mapFirebaseAuthException(
          FirebaseAuthException(code: entry.key),
        ).message,
        entry.value,
      );
    }
  });
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeAdditionalUserInfo extends Fake implements AdditionalUserInfo {
  _FakeAdditionalUserInfo(this.isNewUser);

  @override
  final bool isNewUser;
}

class _FakeUser extends Fake implements User {
  int deleteCalls = 0;

  @override
  Future<void> delete() async {
    deleteCalls++;
  }
}

class _FakeUserCredential extends Fake implements UserCredential {
  _FakeUserCredential({this.isNewUser = false, this.user});

  final bool isNewUser;

  @override
  final User? user;

  @override
  AdditionalUserInfo get additionalUserInfo =>
      _FakeAdditionalUserInfo(isNewUser);
}

class _RecordingWebAuthentication implements WebAuthentication {
  _RecordingWebAuthentication({UserCredential? credential})
    : credential = credential ?? _FakeUserCredential();

  final UserCredential credential;
  FirebaseAuth? signInAuth;

  @override
  Future<UserCredential> signInWithGoogle(FirebaseAuth auth) async {
    signInAuth = auth;
    return credential;
  }

  @override
  Future<void> reauthenticateWithGoogle(User user) async {}
}
