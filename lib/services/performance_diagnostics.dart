import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Privacy-safe development timing diagnostics for asynchronous app flows.
///
/// Callers must use fixed stage names. Identity, document IDs, tokens, and
/// other user-provided values are intentionally unsupported.
class PerformanceDiagnostics {
  PerformanceDiagnostics._();

  static final Stopwatch _journey = Stopwatch()..start();
  static final Map<String, int> _marks = {};
  static final Set<String> _framesPending = {};
  static int _generation = 0;

  /// Fixed internal stage names only; never pass identity or document values.
  static void resetJourney() {
    if (!_enabled) return;
    _generation++;
    _marks.clear();
    _framesPending.clear();
    _journey
      ..reset()
      ..start();
  }

  static void mark(
    String stage, {
    bool? fromCache,
    int? count,
    bool once = false,
  }) {
    if (!_enabled || (once && _marks.containsKey(stage))) return;
    final elapsed = _journey.elapsedMilliseconds;
    _marks[stage] = elapsed;
    _write(
      'stage=${_safeStage(stage)} elapsed_ms=$elapsed '
      'platform=${kIsWeb ? 'web' : 'native'}'
      '${fromCache == null ? '' : ' source=${fromCache ? 'cache' : 'server'}'}'
      '${count == null ? '' : ' count=$count'}',
    );
    final origins = switch (stage) {
      'member' => ['auth_user', 'create_profiles_pressed'],
      'schedule_first_snapshot' => ['member'],
      'schedule_model_parsed' => ['schedule_callback'],
      'schedule_model_ready' => ['member', 'schedule_snapshot'],
      'dashboard_usable_frame' => [
        'member',
        'create_profiles_pressed',
        'schedule_snapshot',
      ],
      'schedule_usable_frame' => ['schedule_snapshot'],
      _ => <String>[],
    };
    for (final origin in origins) {
      final start = _marks[origin];
      if (start != null) {
        _write('stage=${origin}_to_$stage elapsed_ms=${elapsed - start}');
      }
    }
  }

  static bool get enabled => _enabled;

  static bool get creatingProfiles =>
      _marks.containsKey('create_profiles_pressed') &&
      !_marks.containsKey('member');

  /// A completed Flutter frame is a rendering proxy, not proof of screen paint.
  static void usableFrame(String stage) {
    // A provisional empty cache result is not a usable live schedule yet.
    if (_marks.containsKey('member') &&
        !_marks.containsKey('schedule_model_ready')) {
      return;
    }
    if (!_enabled || _marks.containsKey(stage) || !_framesPending.add(stage)) {
      return;
    }
    final generation = _generation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation) return;
      _framesPending.remove(stage);
      mark(stage, once: true);
    });
  }

  static const _logName = 'ota.performance';
  static const _enabled =
      kDebugMode ||
      bool.fromEnvironment('OTA_PERFORMANCE_DIAGNOSTICS', defaultValue: false);
  static final Stopwatch _webStartup = Stopwatch();

  @visibleForTesting
  static void Function(String message)? debugSink;

  static void startWebStartup() {
    if (!_enabled) return;
    resetJourney();
    mark('flutter_start');
    _webStartup
      ..reset()
      ..start();
    _write('flow=web_startup stage=started elapsed_ms=0');
  }

  static void webStartupStage(String stage) {
    if (!_enabled || !_webStartup.isRunning) return;
    mark(stage, once: true);
    _write(
      'flow=web_startup stage=${_safeStage(stage)} '
      'elapsed_ms=${_webStartup.elapsedMilliseconds}',
    );
  }

  static PerformanceTrace start(String flow) => PerformanceTrace._(flow);

  static void _write(String message) {
    debugSink?.call(message);
    // dart:developer.log is a no-op in dart2js release builds.
    if (kIsWeb) {
      debugPrintSynchronously('$_logName $message');
    } else {
      developer.log(message, name: _logName);
    }
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
