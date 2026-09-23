import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/app_bootstrap.dart';
import 'package:ota_cheshire_management_platform/services/startup_failure.dart';

void main() {
  testWidgets('startup gate renders before initialization completes', (
    tester,
  ) async {
    final pending = Completer<void>();

    await tester.pumpWidget(
      ApplicationStartupGate(
        initialize: (_) => pending.future,
        application: const MaterialApp(home: Text('Application ready')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Application ready'), findsNothing);

    pending.complete();
    await tester.pumpAndSettle();

    expect(find.text('Application ready'), findsOneWidget);
  });

  testWidgets('startup exception displays a safe error screen', (tester) async {
    await tester.pumpWidget(
      ApplicationStartupGate(
        initialize: (reportStep) async {
          reportStep(ApplicationStartupStep.firebase);
          throw StateError('unsafe backend details');
        },
        application: const MaterialApp(home: Text('Application ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The app could not start.'), findsOneWidget);
    expect(find.text('Reference: firebase / startup-failed'), findsOneWidget);
    expect(find.textContaining('unsafe backend details'), findsNothing);
  });

  testWidgets('configuration failure displays an actionable safe message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ApplicationStartupGate(
        initialize: (reportStep) async {
          reportStep(ApplicationStartupStep.firebase);
          throw const ApplicationStartupFailure(
            code: 'firebase-web-config-missing',
            userMessage:
                'The OTA Web app is not configured yet. Please contact the academy.',
          );
        },
        application: const MaterialApp(home: Text('Application ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The OTA Web app is not configured yet. Please contact the academy.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Reference: firebase / firebase-web-config-missing'),
      findsOneWidget,
    );
  });

  test('Web startup defers OS push initialization', () {
    expect(shouldInitializePushNotifications(isWeb: true), isFalse);
    expect(shouldInitializePushNotifications(isWeb: false), isTrue);
  });

  testWidgets('blocked startup displays timeout instead of staying blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      ApplicationStartupGate(
        initialize: (reportStep) {
          reportStep(ApplicationStartupStep.pushNotifications);
          return Completer<void>().future;
        },
        application: const MaterialApp(home: Text('Application ready')),
        timeout: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('The app could not start.'), findsOneWidget);
    expect(find.text('Reference: pushNotifications / timeout'), findsOneWidget);
  });

  testWidgets('failed startup can be retried without restarting the process', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ApplicationStartupGate(
        initialize: (_) async {
          attempts += 1;
          if (attempts == 1) throw StateError('first attempt failed');
        },
        application: const MaterialApp(home: Text('Application ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The app could not start.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Application ready'), findsOneWidget);
  });
}
