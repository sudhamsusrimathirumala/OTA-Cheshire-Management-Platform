import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../app_environment.dart';

abstract interface class StartupCrashReporter {
  Future<void> log(String message);

  Future<void> setCustomKey(String key, Object value);

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
    String? reason,
  });
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

class StartupDiagnostics {
  StartupDiagnostics([this._reporter]);

  static const _logName = 'ota.startup';
  static const _maxBufferedCheckpoints = 24;

  StartupCrashReporter? _reporter;
  final List<String> _bufferedCheckpoints = <String>[];

  void checkpoint(String name) {
    final safeName = _safeDiagnosticValue(name);
    developer.log('checkpoint=$safeName', name: _logName);
    final reporter = _reporter;
    if (reporter == null) {
      if (_bufferedCheckpoints.length == _maxBufferedCheckpoints) {
        _bufferedCheckpoints.removeAt(0);
      }
      _bufferedCheckpoints.add(safeName);
      return;
    }
    unawaited(_bestEffort(reporter.log('startup:$safeName')));
  }

  Future<void> attachCrashReporter({
    required StartupCrashReporter reporter,
    required AppEnvironment environment,
  }) async {
    _reporter = reporter;
    try {
      await reporter.setCustomKey('app_environment', environment.name);
      for (final checkpoint in _bufferedCheckpoints) {
        await reporter.log('startup:$checkpoint');
      }
      _bufferedCheckpoints.clear();
      await reporter.log('startup:crashlytics_ready');
    } catch (_) {
      developer.log('crashlytics_attach_failed', name: _logName);
    }
  }

  void installUncaughtErrorHandlers() {
    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      final reporter = _reporter;
      if (reporter != null) {
        unawaited(
          _bestEffort(
            reporter.recordError(
              _privacySafeUnhandledError(
                scope: 'flutter',
                error: details.exception,
              ),
              details.stack ?? StackTrace.current,
              fatal: true,
              reason: 'flutter_framework_error',
            ),
          ),
        );
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      final reporter = _reporter;
      if (reporter != null) {
        unawaited(
          _bestEffort(
            reporter.recordError(
              _privacySafeUnhandledError(scope: 'platform', error: error),
              stack,
              fatal: true,
              reason: 'uncaught_platform_error',
            ),
          ),
        );
        return true;
      } else {
        developer.log(
          'uncaught_error_before_crashlytics',
          name: _logName,
          error: error.runtimeType,
        );
      }
      return false;
    };
  }

  Future<void> recordStartupFailure({
    required String step,
    required String code,
  }) async {
    final safeStep = _safeDiagnosticValue(step);
    final safeCode = _safeDiagnosticValue(code);
    checkpoint('failure_${safeStep}_$safeCode');
    final reporter = _reporter;
    if (reporter == null) return;
    await _bestEffort(
      reporter.recordError(
        StateError('OTA startup failed at $safeStep ($safeCode)'),
        StackTrace.current,
        fatal: false,
        reason: 'startup_failure',
      ),
    );
  }

  Future<void> recordDevelopmentNonfatalVerification({
    required AppEnvironment environment,
    required bool enabled,
  }) async {
    if (!enabled || environment != AppEnvironment.dev) return;
    final reporter = _reporter;
    if (reporter == null) return;
    await _bestEffort(
      reporter.recordError(
        StateError('OTA development Crashlytics nonfatal verification'),
        StackTrace.current,
        fatal: false,
        reason: 'development_verification',
      ),
    );
    checkpoint('development_nonfatal_sent');
  }
}

StateError _privacySafeUnhandledError({
  required String scope,
  required Object error,
}) => StateError('Unhandled $scope error (${error.runtimeType})');

Future<void> _bestEffort(Future<void> operation) async {
  try {
    await operation;
  } catch (_) {
    developer.log(
      'crashlytics_write_failed',
      name: StartupDiagnostics._logName,
    );
  }
}

String _safeDiagnosticValue(String value) {
  final safe = value.replaceAll(RegExp('[^a-zA-Z0-9_/-]'), '-');
  if (safe.isEmpty) return 'unknown';
  return safe.substring(0, safe.length.clamp(0, 64));
}

final startupDiagnostics = StartupDiagnostics();
