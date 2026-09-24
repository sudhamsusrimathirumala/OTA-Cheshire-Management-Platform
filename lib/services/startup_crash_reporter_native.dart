import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'startup_diagnostics.dart';

StartupCrashReporter? createStartupCrashReporter() {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return null;
  }
  return FirebaseStartupCrashReporter(FirebaseCrashlytics.instance);
}

class FirebaseStartupCrashReporter implements StartupCrashReporter {
  FirebaseStartupCrashReporter(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> log(String message) => _crashlytics.log(message);

  @override
  Future<void> setCustomKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
    String? reason,
  }) => _crashlytics.recordError(error, stack, fatal: fatal, reason: reason);
}
