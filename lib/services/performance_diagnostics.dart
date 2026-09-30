import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Privacy-safe development timing diagnostics for asynchronous app flows.
///
/// Callers must use fixed stage names. Identity, document IDs, tokens, and
/// other user-provided values are intentionally unsupported.
class PerformanceDiagnostics {
  PerformanceDiagnostics._();

  static const _logName = 'ota.performance';
  static const _enabled =
      kDebugMode ||
      bool.fromEnvironment('OTA_PERFORMANCE_DIAGNOSTICS', defaultValue: false);
  static final Stopwatch _webStartup = Stopwatch();

  @visibleForTesting
  static void Function(String message)? debugSink;

  static void startWebStartup() {
    if (!_enabled) return;
    _webStartup
      ..reset()
      ..start();
    _write('flow=web_startup stage=started elapsed_ms=0');
  }

  static void webStartupStage(String stage) {
    if (!_enabled || !_webStartup.isRunning) return;
    _write(
      'flow=web_startup stage=${_safeStage(stage)} '
      'elapsed_ms=${_webStartup.elapsedMilliseconds}',
    );
  }

  static PerformanceTrace start(String flow) => PerformanceTrace._(flow);

  static void _write(String message) {
    debugSink?.call(message);
    developer.log(message, name: _logName);
  }

  static String _safeStage(String value) {
    final safe = value.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-');
    if (safe.isEmpty) return 'unknown';
    return safe.substring(0, safe.length.clamp(0, 64));
  }
}

class PerformanceTrace {
  PerformanceTrace._(String flow)
    : _flow = PerformanceDiagnostics._safeStage(flow) {
    if (PerformanceDiagnostics._enabled) _watch.start();
  }

  final String _flow;
  final Stopwatch _watch = Stopwatch();
  int _lastElapsedMilliseconds = 0;

  void stage(String stage) {
    if (!PerformanceDiagnostics._enabled) return;
    final elapsed = _watch.elapsedMilliseconds;
    final delta = elapsed - _lastElapsedMilliseconds;
    _lastElapsedMilliseconds = elapsed;
    PerformanceDiagnostics._write(
      'flow=$_flow stage=${PerformanceDiagnostics._safeStage(stage)} '
      'elapsed_ms=$elapsed delta_ms=$delta',
    );
  }
}
