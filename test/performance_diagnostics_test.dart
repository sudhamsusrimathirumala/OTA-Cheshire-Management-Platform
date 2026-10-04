import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/performance_diagnostics.dart';

void main() {
  final messages = <String>[];
  setUp(() {
    messages.clear();
    PerformanceDiagnostics.debugSink = messages.add;
    PerformanceDiagnostics.resetJourney();
  });
  tearDown(() => PerformanceDiagnostics.debugSink = null);

  test('journey records all total metrics without identity payloads', () {
    PerformanceDiagnostics.mark('auth_user');
    PerformanceDiagnostics.mark('create_profiles_pressed');
    PerformanceDiagnostics.mark('member', once: true);
    PerformanceDiagnostics.mark(
      'schedule_first_snapshot',
      fromCache: true,
      count: 4,
      once: true,
    );
    PerformanceDiagnostics.mark('schedule_snapshot', once: true);
    PerformanceDiagnostics.mark('schedule_model_ready', once: true);
    PerformanceDiagnostics.mark('dashboard_usable_frame', once: true);
    for (final metric in [
      'auth_user_to_member',
      'create_profiles_pressed_to_member',
      'member_to_schedule_first_snapshot',
      'member_to_dashboard_usable_frame',
      'create_profiles_pressed_to_dashboard_usable_frame',
      'schedule_snapshot_to_schedule_model_ready',
    ]) {
      expect(
        messages.any((message) => message.startsWith('stage=$metric ')),
        isTrue,
      );
    }
    expect(messages.join(' '), contains('source=cache count=4'));
    expect(messages.join(' '), isNot(contains('uid=')));
    expect(messages.join(' '), isNot(contains('email=')));
  });

  testWidgets('render milestone deduplicates and waits for a Flutter frame', (
    tester,
  ) async {
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    expect(messages, isEmpty);
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(
      messages.where(
        (message) => message.startsWith('stage=dashboard_usable_frame '),
      ),
      hasLength(1),
    );
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(
      messages.where(
        (message) => message.startsWith('stage=dashboard_usable_frame '),
      ),
      hasLength(1),
    );
  });

  testWidgets('provisional empty cache does not count as a usable live frame', (
    tester,
  ) async {
    PerformanceDiagnostics.mark('member', once: true);
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(
      messages.any(
        (message) => message.startsWith('stage=dashboard_usable_frame '),
      ),
      isFalse,
    );
    PerformanceDiagnostics.mark('schedule_model_ready', once: true);
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(
      messages.any(
        (message) => message.startsWith('stage=dashboard_usable_frame '),
      ),
      isTrue,
    );
  });

  testWidgets('new session discards queued frames from previous session', (
    tester,
  ) async {
    PerformanceDiagnostics.usableFrame('dashboard_usable_frame');
    PerformanceDiagnostics.resetJourney();
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(messages, isEmpty);
    PerformanceDiagnostics.mark('member', once: true);
    expect(messages.any((message) => message.contains('_to_member')), isFalse);
  });
}
