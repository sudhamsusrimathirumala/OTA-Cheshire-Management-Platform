import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/performance_diagnostics.dart';
import 'package:ota_cheshire_management_platform/services/performance_event_buffer.dart';
import 'package:ota_cheshire_management_platform/widgets/performance_diagnostics_panel.dart';

void main() {
  test('40-second gap has cumulative, operation and journey clocks', () {
    final buffer = PerformanceEventBuffer();
    buffer.record('create_profiles_pressed', 100000);
    buffer.record('batch_commit_start', 100708);
    buffer.record('batch_commit_end', 140200, durationMilliseconds: 39492);
    buffer.record('member', 140231);
    buffer.record(
      'create_profiles_pressed_to_member',
      140231,
      durationMilliseconds: 40231,
    );
    expect(buffer.events.first.createMilliseconds, 0);
    expect(buffer.events[2].createMilliseconds, 40200);
    expect(buffer.events[2].durationMilliseconds, 39492);
    expect(buffer.events[2].journeyMilliseconds, 140200);
    expect(buffer.exportText, contains('+40231 ms  session_member_reached'));
    expect(buffer.exportText, contains('TOTAL_create_profiles_to_member'));
  });

  test('only approved stage labels and scalar metadata can enter exports', () {
    final buffer = PerformanceEventBuffer();
    buffer.record('uid=private-user email=private@example.invalid', 0);
    buffer.record(
      'post_create_profile_snapshot',
      12,
      fromCache: true,
      count: 2,
    );
    expect(buffer.events, hasLength(1));
    expect(buffer.exportText, contains('profile_snapshot_received'));
    expect(buffer.exportText, contains('source=cache  count=2'));
    expect(buffer.exportText, isNot(contains('private')));
    expect(buffer.exportText, isNot(contains('uid=')));
    expect(buffer.exportText, isNot(contains('email=')));
  });

  test('bounded buffer and new press reset prevent cross-run mixing', () {
    final buffer = PerformanceEventBuffer();
    buffer.record('create_profiles_pressed', 0);
    for (var i = 0; i < 400; i++) {
      buffer.record('schedule_callback', i);
    }
    expect(buffer.events, hasLength(PerformanceEventBuffer.maximumEvents));
    buffer.record('create_profiles_pressed', 1000);
    expect(buffer.events, hasLength(1));
    expect(buffer.events.single.createMilliseconds, 0);
    buffer.clear();
    expect(buffer.events, isEmpty);
    expect(buffer.createElapsed(2000), isNull);
  });

  test('debug mode alone cannot enable viewer collection', () {
    PerformanceDiagnostics.resetJourney();
    PerformanceDiagnostics.viewerBuffer.clear();
    PerformanceDiagnostics.mark('create_profiles_pressed');
    expect(
      PerformanceDiagnostics.viewerEnabled,
      kIsWeb && PerformanceDiagnostics.diagnosticsRequested,
    );
    expect(
      PerformanceDiagnostics.viewerBuffer.events.isNotEmpty,
      PerformanceDiagnostics.diagnosticsRequested,
    );
  });

  testWidgets('launcher is absent unless Web and explicit flag both allow it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: Text('Member app')),
        builder: (context, child) =>
            PerformanceDiagnosticsOverlay(child: child!),
      ),
    );
    expect(
      find.text('Timings'),
      PerformanceDiagnostics.viewerEnabled ? findsOneWidget : findsNothing,
    );
    expect(find.text('Member app'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('panel scrolls at iPhone width; copy and clear work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final buffer = PerformanceEventBuffer();
    buffer.record('create_profiles_pressed', 0);
    for (var i = 0; i < 50; i++) {
      buffer.record(
        'post_create_profile_snapshot',
        i,
        fromCache: true,
        count: 1,
      );
    }
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: PerformanceDiagnosticsPanel(buffer: buffer, onClose: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();
    expect(copied, buffer.exportText);
    expect(find.text('Copied'), findsOneWidget);
    await tester.tap(find.text('Clear / reset'));
    await tester.pump();
    expect(buffer.events, isEmpty);
    expect(find.textContaining('No timings yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('clipboard failure leaves selectable text intact', (
    tester,
  ) async {
    final buffer = PerformanceEventBuffer()..record('batch_commit_start', 708);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PerformanceDiagnosticsPanel(buffer: buffer, onClose: () {}),
      ),
    );
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();
    expect(
      find.text('Clipboard unavailable. Select text below.'),
      findsOneWidget,
    );
    expect(find.byType(SelectableText), findsOneWidget);
    expect(buffer.events, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Web viewer survives navigation and supports text selection',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      PerformanceDiagnostics.resetJourney();
      PerformanceDiagnostics.mark('create_profiles_pressed');
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Profile setup')),
          builder: (context, child) =>
              PerformanceDiagnosticsOverlay(child: child!),
        ),
      );
      await tester.tap(find.text('Timings'));
      await tester.pumpAndSettle();
      expect(find.text('Local performance timings'), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Dashboard')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local performance timings'), findsOneWidget);
      await tester.longPress(find.byType(SelectableText));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close timings'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !PerformanceDiagnostics.viewerEnabled,
  );
}
