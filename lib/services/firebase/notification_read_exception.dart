import 'package:firebase_core/firebase_core.dart';

enum NotificationReadError {
  permissionDenied,
  unauthenticated,
  unavailable,
  networkFailure,
  invalidArgument,
  unknownFailure,
}

class NotificationReadException implements Exception {
  const NotificationReadException(this.error, this.code, this.message);

  final NotificationReadError error;
  final String code;
  final String message;

  @override
  String toString() => message;
}

NotificationReadException classifyNotificationReadException(
  FirebaseException error,
) {
  final category = switch (error.code) {
    'permission-denied' => NotificationReadError.permissionDenied,
    'unauthenticated' => NotificationReadError.unauthenticated,
    'unavailable' || 'deadline-exceeded' => NotificationReadError.unavailable,
    'network-request-failed' => NotificationReadError.networkFailure,
    'invalid-argument' => NotificationReadError.invalidArgument,
    _ => NotificationReadError.unknownFailure,
  };
  final message = switch (category) {
    NotificationReadError.permissionDenied =>
      'Notification read state is not available yet. Please try again later.',
    NotificationReadError.unauthenticated =>
      'Please sign in again to update notification read state.',
    NotificationReadError.unavailable || NotificationReadError.networkFailure =>
      'Notification read state could not reach the academy service. Try again when your connection is available.',
    NotificationReadError.invalidArgument =>
      'This notification could not be updated. Please refresh and try again.',
    NotificationReadError.unknownFailure =>
      'Unable to update notification read state. Try again.',
  };
  return NotificationReadException(category, error.code, message);
}
