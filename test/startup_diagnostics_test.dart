import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/app_environment.dart';
import 'package:ota_cheshire_management_platform/services/startup_diagnostics.dart';

void main() {
  test(
    'buffered privacy-safe checkpoints flush after Crashlytics attaches',
    () async {
      final reporter = _RecordingReporter();
      final diagnostics = StartupDiagnostics();

      diagnostics.checkpoint('dart main: prod');
      await diagnostics.attachCrashReporter(
        reporter: reporter,
        environment: AppEnvironment.prod,
      );

      expect(reporter.keys, {'app_environment': 'prod'});
      expect(reporter.logs, [
        'startup:dart-main--prod',
        'startup:crashlytics_ready',
      ]);
    },
  );

  test('startup failures report only sanitized step and code', () async {
    final reporter = _RecordingReporter();
    final diagnostics = StartupDiagnostics(reporter);

    await diagnostics.recordStartupFailure(
      step: 'firebase student@example.com',
      code: 'bad code: token=value',
    );

    expect(reporter.errors, hasLength(1));
    expect(
      reporter.errors.single.error.toString(),
      isNot(contains('student@example.com')),
    );
    expect(reporter.errors.single.reason, 'startup_failure');
    expect(reporter.errors.single.fatal, isFalse);
  });

  test(
    'nonfatal verification is enabled only for development builds',
    () async {
      final reporter = _RecordingReporter();
      final diagnostics = StartupDiagnostics(reporter);

      await diagnostics.recordDevelopmentNonfatalVerification(
        environment: AppEnvironment.prod,
        enabled: true,
      );
      await diagnostics.recordDevelopmentNonfatalVerification(
        environment: AppEnvironment.dev,
        enabled: false,
      );
      expect(reporter.errors, isEmpty);

      await diagnostics.recordDevelopmentNonfatalVerification(
        environment: AppEnvironment.dev,
        enabled: true,
      );
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.reason, 'development_verification');
      expect(reporter.errors.single.fatal, isFalse);
    },
  );

  test(
    'failed reporter attachment is not treated as active reporting',
    () async {
      final diagnostics = StartupDiagnostics();

      await diagnostics.attachCrashReporter(
        reporter: _FailingReporter(),
        environment: AppEnvironment.prod,
      );

      expect(diagnostics.hasReporter, isFalse);
    },
  );
}

class _FailingReporter implements StartupCrashReporter {
  @override
  Future<void> log(String message) => throw StateError('unavailable');

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
    String? reason,
  }) => throw StateError('unavailable');

  @override
  Future<void> setCustomKey(String key, Object value) =>
      throw StateError('unavailable');
}

class _RecordingReporter implements StartupCrashReporter {
  final logs = <String>[];
  final keys = <String, Object>{};
  final errors = <_RecordedError>[];

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
    String? reason,
  }) async {
    errors.add(_RecordedError(error: error, fatal: fatal, reason: reason));
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    keys[key] = value;
  }
}

class _RecordedError {
  const _RecordedError({
    required this.error,
    required this.fatal,
    required this.reason,
  });

  final Object error;
  final bool fatal;
  final String? reason;
}
