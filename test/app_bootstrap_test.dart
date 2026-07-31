import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/app_bootstrap.dart';

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
    expect(find.text('Startup step: firebase'), findsOneWidget);
    expect(find.text('Code: startup-failed'), findsOneWidget);
    expect(find.textContaining('unsafe backend details'), findsNothing);
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
    expect(find.text('Startup step: pushNotifications'), findsOneWidget);
    expect(find.text('Code: timeout'), findsOneWidget);
  });
}
