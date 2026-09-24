import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_profile_screen.dart';
import 'package:ota_cheshire_management_platform/screens/auth/auth_gate.dart';
import 'package:ota_cheshire_management_platform/screens/auth/profile_creation_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/signup_screen.dart';
import 'package:ota_cheshire_management_platform/screens/student_dashboard_screen.dart';
import 'package:ota_cheshire_management_platform/screens/guest/guest_dashboard_screen.dart';
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
    await _enterEligibleSignupDate(tester);

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
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

  testWidgets(
    'autofill-style credential updates stay on login until submission',
    (tester) async {
      var signInCalls = 0;
      await tester.pumpWidget(
        app(
          route: OtaRoutes.login,
          screen: LoginScreen(
            emailSignIn: (email, password) async {
              signInCalls++;
              return null;
            },
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'saved.user@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'saved-password',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('saved.user@example.com'), findsOneWidget);
      expect(signInCalls, 0);
      expect(find.text('AUTH GATE'), findsNothing);
    },
  );

  testWidgets('Google success from login and signup resets to the gate', (
    tester,
  ) async {
    for (final screen in <Widget>[
      LoginScreen(googleSignIn: () async => null),
      SignupScreen(googleSignIn: () async => null),
    ]) {
      final route = screen is LoginScreen ? OtaRoutes.login : OtaRoutes.signup;
      await tester.pumpWidget(app(route: route, screen: screen));
      if (screen is SignupScreen) await _enterEligibleSignupDate(tester);
      await tester.ensureVisible(find.text('CONTINUE WITH GOOGLE'));
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
      if (screen is SignupScreen) await _enterEligibleSignupDate(tester);
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

      if (!isLogin) await _enterEligibleSignupDate(tester);
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
    await _enterEligibleSignupDate(tester);
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
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
    await _enterEligibleSignupDate(tester);

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
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
      SessionStage.guest: GuestModeShell,
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

  test(
    'account replacement enters loading before the prior admin identity clears',
    () async {
      final authentication = _DelayedClaimsAuthenticationService();
      final controller =
          FirebaseSessionController(authentication: authentication)
            ..authUser = _TestUser('admin-user')
            ..account = const UserAccount(
              id: 'admin-user',
              firstName: 'Academy',
              lastName: 'Admin',
              email: 'admin@example.invalid',
              role: UserAccountRole.admin,
              locationId: 'academy',
              linkedStudentProfileIds: [],
            )
            ..stage = SessionStage.admin
            ..start();

      authentication.emit(_TestUser('replacement-user'));
      await pumpEventQueue(times: 3);

      expect(controller.account, isNull);
      expect(controller.stage, SessionStage.loading);

      controller.dispose();
      authentication.completeClaims();
      await authentication.close();
    },
  );

  test('Admin Profile does not read Firebase identity during transition', () {
    var localIdentityWasRead = false;

    final account = adminProfileAccountForSession(
      stage: SessionStage.loading,
      firebaseAccount: null,
      requiresFirebaseIdentity: true,
      localAccount: () {
        localIdentityWasRead = true;
        throw StateError('The strict identity getter must not be read.');
      },
    );

    expect(account, isNull);
    expect(localIdentityWasRead, isFalse);
  });
}

Future<void> _enterEligibleSignupDate(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).last, '01/01/2000');
  await tester.pump();
}

class _TestUser implements User {
  _TestUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedClaimsAuthenticationService
    implements AuthenticationService, AuthenticationClaimsService {
  final _authStates = StreamController<User?>();
  final _claims = Completer<Map<String, Object?>>();

  void emit(User? user) => _authStates.add(user);

  void completeClaims() {
    if (!_claims.isCompleted) _claims.complete(const {});
  }

  Future<void> close() => _authStates.close();

  @override
  Stream<User?> authStateChanges() => _authStates.stream;

  @override
  Future<Map<String, Object?>> currentUserClaims() => _claims.future;

  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
