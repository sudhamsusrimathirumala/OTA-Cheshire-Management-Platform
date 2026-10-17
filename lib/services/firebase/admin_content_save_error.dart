import 'package:firebase_core/firebase_core.dart';

/// Human-readable errors for academy content saves.
///
/// Do not display FirebaseException.message or arbitrary exception.toString():
/// backend messages can include paths, document IDs, or other private data.
String adminContentSaveError(Object error, {required String item}) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Could not save $item: Firebase permissions rejected this write. '
        'Check the admin account, location access, and deployed Firestore rules.',
      'unauthenticated' =>
        'Could not save $item: your session expired. Sign in again and retry.',
      'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
        'Could not save $item: the service or network is unavailable. '
        'Reconnect and retry.',
      'resource-exhausted' =>
        'Could not save $item: the service is temporarily at capacity. '
        'Please retry shortly.',
      'invalid-argument' =>
        'Could not save $item: some copied fields are invalid. '
        'Review the form and retry.',
      'failed-precondition' || 'aborted' =>
        'Could not save $item: the content changed or needs review. '
        'Refresh the content and try again.',
      _ =>
        'Could not save $item (Firebase error: '
        '${_safeFirebaseCode(error.code)}). Please try again.',
    };
  }
  if (error is ArgumentError) {
    return 'Could not save $item: one or more fields are invalid. '
        'Review the copied fields and retry.';
  }
  if (error is StateError) {
    return 'Could not save $item: the original content changed while '
        'editing. Refresh and try again.';
  }
  return 'Could not save $item. Please try again.';
}

String _safeFirebaseCode(String code) {
  final normalized = code.toLowerCase();
  return RegExp(r'^[a-z][a-z0-9-]{0,55}$').hasMatch(normalized)
      ? normalized
      : 'unknown';
}
