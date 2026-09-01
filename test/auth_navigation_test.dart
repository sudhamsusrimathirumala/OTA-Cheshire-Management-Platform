import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/auth/auth_gate.dart';
import 'package:ota_cheshire_management_platform/screens/auth/profile_creation_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/signup_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/welcome_screen.dart';
import 'package:ota_cheshire_management_platform/services/debug_view_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';

void main() {
  Widget app({required String route, required Widget screen}) => MaterialApp(
    key: UniqueKey(),
    initialRoute: route,
    routes: {
      OtaRoutes.gate: (_) => const Scaffold(body: Text('AUTH GATE')),
      route: (_) => screen,
    },
  );

  testWidgets('email signup clears debug state and resets the full stack', (
    tester,
  ) async {
    var calls = 0;
    debugViewController.enterStudent();
    await tester.pumpWidget(
      app(
        route: OtaRoutes.signup,
        screen: SignupScreen(
          emailSignUp: (email, password) async {
            calls++;
            expect(email, 'student@example.com');
            expect(password, 'password1');
            return null;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.enterText(find.byType(TextFormField).at(2), 'password1');

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(debugViewController.mode, DebugViewMode.none);
    expect(find.text('AUTH GATE'), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets('email login success resets to the gate', (tester) async {
    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: LoginScreen(emailSignIn: (email, password) async => null),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(find.text('AUTH GATE'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Google success from login and signup resets to the gate', (
    tester,
  ) async {
    for (final screen in <Widget>[
      LoginScreen(googleSignIn: () async => null),
      SignupScreen(googleSignIn: () async => null),
    ]) {
      final route = screen is LoginScreen ? OtaRoutes.login : OtaRoutes.signup;
      await tester.pumpWidget(app(route: route, screen: screen));
      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();
      expect(find.text('AUTH GATE'), findsOneWidget);
    }
  });

  testWidgets('Apple success from login and signup resets to the gate', (
    tester,
  ) async {
    for (final screen in <Widget>[
      LoginScreen(appleSupported: true, appleSignIn: () async => null),
      SignupScreen(appleSupported: true, appleSignIn: () async => null),
    ]) {
      final route = screen is LoginScreen ? OtaRoutes.login : OtaRoutes.signup;
      await tester.pumpWidget(app(route: route, screen: screen));
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      await tester.ensureVisible(find.text('Sign in with Apple'));
      await tester.tap(find.text('Sign in with Apple'));
      await tester.pumpAndSettle();
      expect(find.text('AUTH GATE'), findsOneWidget);
    }
  });

  testWidgets('Apple button is hidden when the platform is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: const LoginScreen(appleSupported: false),
      ),
    );
    expect(find.byType(SignInWithAppleButton), findsNothing);

    await tester.pumpWidget(
      app(
        route: OtaRoutes.signup,
        screen: const SignupScreen(appleSupported: false),
      ),
    );
    expect(find.byType(SignInWithAppleButton), findsNothing);
  });

  testWidgets('Apple cancellation stays on login with a distinct message', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: LoginScreen(
          appleSupported: true,
          appleSignIn: () async => throw const AuthenticationException(
            AuthenticationError.appleCancelled,
            'Sign in with Apple was cancelled.',
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Sign in with Apple'));
    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign in with Apple was cancelled.'), findsOneWidget);
    expect(find.text('AUTH GATE'), findsNothing);
  });

  testWidgets('Apple buttons disable while authentication is busy', (
    tester,
  ) async {
    for (final isLogin in [true, false]) {
      final completer = Completer<void>();
      var calls = 0;
      Future<void> appleSignIn() {
        calls++;
        return completer.future;
      }

      final screen = isLogin
          ? LoginScreen(appleSupported: true, appleSignIn: appleSignIn)
          : SignupScreen(appleSupported: true, appleSignIn: appleSignIn);
      await tester.pumpWidget(
        app(
          route: isLogin ? OtaRoutes.login : OtaRoutes.signup,
          screen: screen,
        ),
      );

      await tester.ensureVisible(find.text('Sign in with Apple'));
      await tester.tap(find.text('Sign in with Apple'));
      await tester.pump();

      expect(calls, 1);
      expect(
        tester
            .widget<SignInWithAppleButton>(find.byType(SignInWithAppleButton))
            .onPressed,
        isNull,
      );

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('AUTH GATE'), findsOneWidget);
    }
  });

  testWidgets('authentication failure stays on the current screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: LoginScreen(
          emailSignIn: (email, password) async =>
              throw const AuthenticationException(
                AuthenticationError.invalidCredentials,
                'The email or password is incorrect.',
              ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');

    await tester.tap(find.text('LOGIN'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    expect(find.text('AUTH GATE'), findsNothing);
  });

  testWidgets('login and signup use the same safe diagnostic formatter', (
    tester,
  ) async {
    const failure = AuthenticationException(
      AuthenticationError.unknownFailure,
      'Sign-in could not be completed. Please try again.',
      diagnosticCode: 'unknown',
      diagnosticMessage: 'CONFIGURATION_NOT_FOUND',
    );
    final expected = authenticationDisplayMessage(
      failure,
      includeDiagnostic: true,
    );

    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: LoginScreen(
          emailSignIn: (email, password) async => throw failure,
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.tap(find.text('LOGIN'));
    await tester.pump();
    expect(find.text(expected), findsOneWidget);

    await tester.pumpWidget(
      app(
        route: OtaRoutes.signup,
        screen: SignupScreen(
          emailSignUp: (email, password) async => throw failure,
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.enterText(find.byType(TextFormField).at(2), 'password1');
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pump();
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('unexpected sign-in failure shows a safe message', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        route: OtaRoutes.login,
        screen: LoginScreen(
          emailSignIn: (email, password) async =>
              throw StateError('Sensitive implementation detail'),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');

    await tester.tap(find.text('LOGIN'));
    await tester.pump();

    expect(
      find.text('Sign-in could not be completed. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sensitive implementation detail'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated signup submit performs one action and one reset', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      app(
        route: OtaRoutes.signup,
        screen: SignupScreen(
          emailSignUp: (email, password) {
            calls++;
            return completer.future;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.enterText(find.byType(TextFormField).at(2), 'password1');

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    expect(calls, 1);
    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('AUTH GATE'), findsOneWidget);
  });

  test('AuthGate maps the simplified session stages', () {
    final expected = <SessionStage, Type>{
      SessionStage.signedOut: WelcomeScreen,
      SessionStage.needsProfiles: ProfileCreationScreen,
      SessionStage.member: StudentDashboardScreen,
      SessionStage.admin: AdminDashboardScreen,
    };

    for (final entry in expected.entries) {
      expect(authGateDestination(stage: entry.key).runtimeType, entry.value);
    }
    for (final stage in [
      SessionStage.loading,
      SessionStage.disabled,
      SessionStage.adminDisabled,
      SessionStage.error,
    ]) {
      expect(authGateDestination(stage: stage), isA<Widget>());
    }
  });

  test('administrator sign out clears the protected session stage', () async {
    final authentication = _SignOutAuthenticationService();
    final controller = FirebaseSessionController(
      authentication: authentication,
    );
    controller.stage = SessionStage.admin;

    await controller.signOut();

    expect(authentication.signOutCalls, 1);
    expect(controller.stage, SessionStage.signedOut);
    expect(controller.account, isNull);
    controller.dispose();
  });
}

class _SignOutAuthenticationService implements AuthenticationService {
  int signOutCalls = 0;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<User?> refreshUser() async => null;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) =>
      throw UnimplementedError();
}
