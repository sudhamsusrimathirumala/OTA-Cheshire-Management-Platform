import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ota_cheshire_management_platform/models/curriculum_requirement.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/screens/account_deletion_screen.dart';
import 'package:ota_cheshire_management_platform/screens/curriculum_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/signup_screen.dart';
import 'package:ota_cheshire_management_platform/screens/welcome_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/account_deletion_service.dart';
import 'package:ota_cheshire_management_platform/widgets/privacy_policy_link.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  test('release privacy and deletion URLs are the approved public resources', () {
    expect(
      privacyPolicyUrl,
      'https://docs.google.com/document/d/e/'
      '2PACX-1vQNJ9fGPhLxG9lkE8RXoMwdOXIFh9wc19rJXgCqefbEnE-c3nFnK9VpVhRMK-SLR7sPFuWQl3ZDMQy-/pub',
    );
    expect(
      accountDeletionRequestUrl,
      'https://docs.google.com/forms/d/e/'
      '1FAIpQLScLct1c2cEmJMjEt-vXNJUOjOMuWZiB5uyLMYyV0agFolYWMQ/viewform',
    );
  });

  for (final screen in <Widget>[
    const WelcomeScreen(),
    const LoginScreen(appleSupported: false),
    const SignupScreen(appleSupported: false),
  ]) {
    testWidgets('${screen.runtimeType} exposes Privacy Policy signed out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.scrollUntilVisible(
        find.text('Privacy Policy'),
        250,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  }

  testWidgets('privacy button opens the exact approved URL', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyButton(
            launcher: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();

    expect(opened, Uri.parse(privacyPolicyUrl));
  });

  for (final role in [UserAccountRole.admin, UserAccountRole.superAdmin]) {
    testWidgets('$role gets the supported external deletion request path', (
      tester,
    ) async {
      final account = UserAccount(
        id: 'privileged',
        firstName: 'Admin',
        lastName: 'User',
        email: 'admin@example.com',
        role: role,
        locationId: role == UserAccountRole.admin ? 'cheshire' : '',
        linkedStudentProfileIds: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AccountDeletionScreen(
            service: _NoopDeletionService(),
            accountOverride: account,
          ),
        ),
      );

      expect(find.text('Request account deletion online'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Permanently delete account'), findsNothing);
    });
  }

  testWidgets('YouTube is not loaded before an explicit user action', (
    tester,
  ) async {
    const section = CurriculumSection(
      id: 'forms',
      title: 'Forms',
      sortOrder: 0,
      items: [
        CurriculumItem(
          id: 'video',
          title: 'Form video',
          contentType: CurriculumContentType.video,
          sortOrder: 0,
          videoUrl: 'abcdefghijk',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CurriculumSectionCard(section: section)),
      ),
    );

    expect(find.text('Load YouTube video'), findsOneWidget);
    expect(
      find.textContaining('may collect device and usage data'),
      findsOneWidget,
    );
    expect(find.byType(YoutubePlayer), findsNothing);
  });

  test('YouTube embeds use explicit privacy and content-safety settings', () {
    final params = curriculumYoutubePlayerParams();
    expect(params.privacyEnhancedMode, isTrue);
    expect(params.strictRelatedVideos, isTrue);
    expect(params.showVideoAnnotations, isFalse);
    expect(params.showFullscreenButton, isTrue);
  });
}

class _NoopDeletionService extends AccountDeletionService {
  _NoopDeletionService()
    : super(
        authentication: _NoopDeletionAuthentication(),
        store: _NoopDeletionStore(),
      );
}

class _NoopDeletionAuthentication implements AccountDeletionAuthentication {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopDeletionStore implements AccountDeletionStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
