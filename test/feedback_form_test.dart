import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/profile_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/widgets/privacy_policy_link.dart';
import 'package:ota_cheshire_management_platform/widgets/app_issue_report_notice.dart';

void main() {
  test('feedback destination is the exact public responder link', () {
    final uri = Uri.parse(feedbackFormUrl);
    expect(uri.scheme, 'https');
    expect(uri.host, 'docs.google.com');
    expect(uri.path,
        '/forms/d/e/1FAIpQLSfrhfhlIYH5TuTtw1GXmGfx-G8zKdRas-bZa87sdg67MFJFng/viewform');
    expect(uri.query, isEmpty);
  });

  testWidgets('feedback action opens the academy form externally', (tester) async {
    Uri? destination;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => openFeedbackForm(
            context,
            launcher: (uri) async {
              destination = uri;
              return true;
            },
          ),
          child: const Text('Send feedback'),
        )),
      ),
    ));

    await tester.tap(find.text('Send feedback'));
    await tester.pump();
    expect(destination, Uri.parse(feedbackFormUrl));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('unavailable feedback form reports a useful error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => openFeedbackForm(
            context,
            launcher: (_) async => false,
          ),
          child: const Text('Send feedback'),
        )),
      ),
    ));

    await tester.tap(find.text('Send feedback'));
    await tester.pump();
    expect(find.text('The feedback form could not be opened. Please try again.'),
        findsOneWidget);
  });

  testWidgets('dashboard report reminder wraps large text and opens the form', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Uri? destination;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.5)),
        child: child!,
      ),
      home: Scaffold(body: AppIssueReportNotice(launcher: (uri) async {
        destination = uri;
        return true;
      })),
    ));
    await tester.tap(find.text(AppIssueReportNotice.message));
    await tester.pump();
    expect(destination, Uri.parse(feedbackFormUrl));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed link launcher shows an error instead of escaping', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: AppIssueReportNotice(launcher: (_) async => throw StateError('Unavailable')),
    )));
    await tester.tap(find.text(AppIssueReportNotice.message));
    await tester.pump();
    expect(find.text('The feedback form could not be opened. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both member and admin profiles expose feedback action', (tester) async {
    initializeMockAppDataServiceForTests();
    addTearDown(initializeMockAppDataServiceForTests);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: ProfileScreen(
        managementAvailableOverride: false,
        accountDeletionAvailableOverride: false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Feedback & Report a Bug'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: AdminProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Feedback & Report a Bug'), findsOneWidget);
  });
}
