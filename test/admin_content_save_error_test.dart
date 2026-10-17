import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_content_save_error.dart';

void main() {
  test('permissions explain potential deployed-rules mismatch without leaking details', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Document /users/secret-user, email secret@example.com',
    );
    final explanation = adminContentSaveError(error, item: 'announcement');
    expect(explanation, contains('Firebase permissions'));
    expect(explanation, contains('deployed Firestore rules'));
    expect(explanation, isNot(contains('secret-user')));
    expect(explanation, isNot(contains('secret@example.com')));
  });

  test('network and session errors are explained', () {
    expect(
      adminContentSaveError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        item: 'event',
      ),
      contains('network'),
    );
    expect(
      adminContentSaveError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unauthenticated'),
        item: 'resource',
      ),
      contains('Sign in again'),
    );
  });

  test('unknown error does not expose unsafe provider messages or codes', () {
    final detail = adminContentSaveError(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'bad/id@example.com',
        message: 'secret-token-xyz',
      ),
      item: 'event',
    );
    expect(detail, contains('Firebase error: unknown'));
    expect(detail, isNot(contains('secret-token-xyz')));
    expect(detail, isNot(contains('bad/id')));
    expect(adminContentSaveError(StateError('secret'), item: 'resource'),
        isNot(contains('secret')));
  });
}
