import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/auth/auth_gate.dart';
import 'package:ota_cheshire_management_platform/screens/auth/profile_creation_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/signup_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';

void main() {
  test('session adoption waits until the account snapshot resolves', () async {
    final user = _FakeUser();
    final authentication = _SignupAuthenticationService(user);
    final controller = FirebaseSessionController(authentication: authentication)
      ..authUser = user
      ..stage = SessionStage.loading;

    final adoption = controller.adoptAuthenticatedUserAfterSignup();
    controller.stage = SessionStage.needsProfiles;
    controller.dismissCreatedConfirmation();

    expect(await adoption, SessionStage.needsProfiles);
    controller.dispose();
  });

  testWidgets('successful account creation waits for session profile setup', (
    tester,
  ) async {
    final transition = Completer<SessionStage>();
    var creationCalls = 0;
    var authenticatedUserCreated = false;
    Type? gateDestinationType;
    await tester.pumpWidget(
      _app(
        SignupScreen(
          emailSignUp: (email, password) async {
            creationCalls++;
            authenticatedUserCreated = true;
            return Object();
          },
          emailSignupSessionTransition: () => transition.future,
        ),
        gateBuilder: (_) {
          final destination = authGateDestination(
            stage: SessionStage.needsProfiles,
          );
          gateDestinationType = destination.runtimeType;
          return const Scaffold(body: Text('PROFILE SETUP GATE'));
        },
      ),
    );
    await _enterValidSignup(tester);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pump();

    expect(authenticatedUserCreated, isTrue);
    expect(creationCalls, 1);
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('CREATING ACCOUNT...'), findsOneWidget);

    transition.complete(SessionStage.needsProfiles);
    await tester.pumpAndSettle();

    expect(gateDestinationType, ProfileCreationScreen);
    expect(find.text('PROFILE SETUP GATE'), findsOneWidget);
    expect(creationCalls, 1);
  });

  testWidgets('session transition failure never repeats account creation', (
    tester,
  ) async {
    var creationCalls = 0;
    var transitionCalls = 0;
    await tester.pumpWidget(
      _app(
        SignupScreen(
          emailSignUp: (email, password) async {
            creationCalls++;
            return Object();
          },
          emailSignupSessionTransition: () async {
            transitionCalls++;
            return transitionCalls == 1
                ? SessionStage.error
                : SessionStage.needsProfiles;
          },
        ),
      ),
    );
    await _enterValidSignup(tester);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pump();
    expect(find.textContaining('Your account was created'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(creationCalls, 1);
    expect(transitionCalls, 2);
    expect(find.text('AUTH GATE'), findsOneWidget);
  });

  testWidgets('known signup failures show safe debug diagnostics', (
    tester,
  ) async {
    for (final failure in [
      const AuthenticationException(
        AuthenticationError.emailAlreadyInUse,
        'An account already uses this email address.',
        diagnosticCode: 'email-already-in-use',
      ),
      const AuthenticationException(
        AuthenticationError.weakPassword,
        'Choose a stronger password.',
        diagnosticCode: 'weak-password',
      ),
      const AuthenticationException(
        AuthenticationError.networkFailure,
        'The network is unavailable. Check your connection and try again.',
        diagnosticCode: 'network-request-failed',
      ),
    ]) {
      await tester.pumpWidget(
        _app(
          SignupScreen(emailSignUp: (email, password) async => throw failure),
        ),
      );
      await _enterValidSignup(tester);

      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pump();

      expect(find.textContaining(failure.message), findsOneWidget);
      expect(find.textContaining(failure.diagnosticCode!), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    }
  });

  testWidgets('unexpected signup failure is safe and ends loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SignupScreen(
          emailSignUp: (email, password) async =>
              throw StateError('Private failure detail'),
        ),
      ),
    );
    await _enterValidSignup(tester);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pump();

    expect(
      find.text('Account creation could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Private failure detail'), findsNothing);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('CREATING ACCOUNT...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('release display excludes signup diagnostics', () {
    const failure = AuthenticationException(
      AuthenticationError.networkFailure,
      'The network is unavailable. Check your connection and try again.',
      diagnosticCode: 'network-request-failed',
    );

    expect(
      authenticationDisplayMessage(failure, includeDiagnostic: false),
      failure.message,
    );
    expect(
      authenticationDisplayMessage(failure, includeDiagnostic: true),
      contains('network-request-failed'),
    );
  });

  test('signup Firebase failures retain safe categories and diagnostics', () {
    final expected = <String, AuthenticationError>{
      'invalid-email': AuthenticationError.invalidEmail,
      'weak-password': AuthenticationError.weakPassword,
      'email-already-in-use': AuthenticationError.emailAlreadyInUse,
      'operation-not-allowed': AuthenticationError.providerDisabled,
      'app-not-authorized': AuthenticationError.appConfiguration,
      'invalid-api-key': AuthenticationError.appConfiguration,
      'network-request-failed': AuthenticationError.networkFailure,
      'too-many-requests': AuthenticationError.tooManyAttempts,
    };

    for (final entry in expected.entries) {
      final failure = mapFirebaseAuthException(
        FirebaseAuthException(code: entry.key),
      );
      expect(failure.error, entry.value);
      expect(failure.diagnosticCode, entry.key);
    }

    final unknown = mapFirebaseAuthException(
      FirebaseAuthException(code: 'Unexpected Private/Detail'),
    );
    expect(unknown.error, AuthenticationError.unknownFailure);
    expect(unknown.diagnosticCode, 'unexpected-private-detail');
    expect(unknown.message, isNot(contains('Private')));
  });
}

Widget _app(SignupScreen screen, {WidgetBuilder? gateBuilder}) => MaterialApp(
  key: UniqueKey(),
  initialRoute: OtaRoutes.signup,
  routes: {
    OtaRoutes.signup: (_) => screen,
    OtaRoutes.gate:
        gateBuilder ?? (_) => const Scaffold(body: Text('AUTH GATE')),
  },
);

Future<void> _enterValidSignup(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'student@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'password1');
  await tester.enterText(find.byType(TextFormField).at(2), 'password1');
}

class _FakeUser implements User {
  @override
  String get uid => 'new-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignupAuthenticationService implements AuthenticationService {
  const _SignupAuthenticationService(this.currentUser);

  @override
  final User? currentUser;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
