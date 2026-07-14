import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('unknown Firebase details are not exposed', () {
    final error = mapFirebaseAuthException(
      FirebaseAuthException(
        code: 'unexpected-backend-detail',
        message: 'Sensitive backend detail',
      ),
    );
    expect(error.error, AuthenticationError.unknownFailure);
    expect(error.message, isNot(contains('Sensitive')));
    expect(error.message, isNot(contains('unexpected-backend-detail')));
  });
}
