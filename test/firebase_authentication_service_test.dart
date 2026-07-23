import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';

void main() {
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

  test('diagnostic code is omitted from release display behavior', () {
    const error = AuthenticationException(
      AuthenticationError.providerDisabled,
      'Email and password sign-in is not enabled for this app.',
      diagnosticCode: 'operation-not-allowed',
    );

    expect(
      authenticationDisplayMessage(error, includeDiagnostic: false),
      error.message,
    );
    expect(
      authenticationDisplayMessage(error, includeDiagnostic: true),
      contains('operation-not-allowed'),
    );
  });
}
