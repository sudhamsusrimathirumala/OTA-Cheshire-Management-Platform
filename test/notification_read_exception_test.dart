import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/notification_read_exception.dart';

void main() {
  test('notification Firebase error codes receive safe classifications', () {
    final cases = <String, NotificationReadError>{
      'permission-denied': NotificationReadError.permissionDenied,
      'unauthenticated': NotificationReadError.unauthenticated,
      'unavailable': NotificationReadError.unavailable,
      'deadline-exceeded': NotificationReadError.unavailable,
      'network-request-failed': NotificationReadError.networkFailure,
      'invalid-argument': NotificationReadError.invalidArgument,
      'internal': NotificationReadError.unknownFailure,
    };

    for (final entry in cases.entries) {
      final result = classifyNotificationReadException(
        FirebaseException(plugin: 'cloud_firestore', code: entry.key),
      );
      expect(result.error, entry.value);
      expect(result.code, entry.key);
      expect(result.message, isNot(contains(entry.key)));
    }
  });
}
