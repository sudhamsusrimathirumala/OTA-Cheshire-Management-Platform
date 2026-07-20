import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/academy_resource.dart';
import 'package:ota_cheshire_management_platform/models/class_session.dart';
import 'package:ota_cheshire_management_platform/models/notification_item.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/admin/admin_announcements_screen.dart';
import 'package:ota_cheshire_management_platform/screens/login_screen.dart';
import 'package:ota_cheshire_management_platform/screens/notification_detail_screen.dart';
import 'package:ota_cheshire_management_platform/screens/resource_detail_screen.dart';
import 'package:ota_cheshire_management_platform/screens/schedule_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/debug_view_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_authentication_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/mock_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/push_navigation_coordinator.dart';
import 'package:ota_cheshire_management_platform/services/push_notification_service.dart';
import 'package:ota_cheshire_management_platform/widgets/unsaved_changes_guard.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  testWidgets(
    'login validation updates after submit and clears server errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            emailSignIn: (email, password) async =>
                throw const AuthenticationException(
                  AuthenticationError.invalidCredentials,
                  'Invalid sign-in.',
                ),
          ),
        ),
      );

      expect(find.text('Enter a valid email address.'), findsNothing);
      await tester.ensureVisible(find.text('LOGIN'));
      await tester.tap(find.text('LOGIN'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'parent@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsNothing);
      expect(find.text('Enter your password.'), findsNothing);

      await tester.tap(find.text('LOGIN'));
      await tester.pump();
      expect(find.text('Invalid sign-in.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), 'password2');
      await tester.pump();
      expect(find.text('Invalid sign-in.'), findsNothing);
    },
  );

  testWidgets('password reset stays open until normalized email is valid', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(passwordReset: (email) async => submitted = email),
      ),
    );
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'bad-address');
    await tester.tap(find.text('Send reset email'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).last,
      '  Parent@Example.COM  ',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();
    expect(submitted, 'parent@example.com');
    expect(
      find.text(
        'If an account is eligible, password reset instructions have been sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shared unsaved guard confirms before closing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UnsavedChangesGuard(
          isDirty: () => true,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => UnsavedChangesGuard.requestClose(context),
                child: const Text('Cancel'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Keep Editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('dirty admin announcement form confirms Cancel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminAnnouncementsScreen()),
    );
    await tester.tap(find.text('Create Announcement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Changed');
    await tester.ensureVisible(find.text('Cancel').last);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('announcement detail hides content removed while open', (
    tester,
  ) async {
    final service = _MutableAppDataService();
    appDataService = service;
    final notification = service.notifications.first;
    await tester.pumpWidget(
      MaterialApp(home: NotificationDetailScreen(notification: notification)),
    );
    expect(find.text(notification.title), findsWidgets);
    service.removeNotification(notification.id);
    await tester.pump();
    expect(find.text('This item is no longer available.'), findsOneWidget);
    expect(find.text(notification.body), findsNothing);
  });

  testWidgets('resource detail hides content removed while open', (
    tester,
  ) async {
    final service = _MutableAppDataService();
    appDataService = service;
    final resource = service.resources.first;
    await tester.pumpWidget(
      MaterialApp(home: ResourceDetailScreen(resource: resource)),
    );
    expect(find.text(resource.title), findsWidgets);
    service.removeResource(resource.id);
    await tester.pump();
    expect(find.text('This item is no longer available.'), findsOneWidget);
    expect(find.text(resource.description), findsNothing);
  });

  testWidgets('deleted class detail becomes unavailable', (tester) async {
    final service = _MutableAppDataService();
    appDataService = service;
    final session = service.schedule.values.expand((items) => items).first;
    final date = _dateForWeekday(session.startTime.weekday);
    await tester.pumpWidget(
      MaterialApp(home: ScheduleScreen(initialDate: date)),
    );
    final className = find.text(session.className).first;
    await tester.ensureVisible(className);
    await tester.tap(className);
    await tester.pumpAndSettle();
    service.removeClass(session.id);
    await tester.pump();
    expect(find.text('This item is no longer available.'), findsOneWidget);
  });

  testWidgets('missing content opened from push shows unavailable state', (
    tester,
  ) async {
    final service = _MutableAppDataService()..clearResources();
    appDataService = service;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const SizedBox(),
        routes: {
          OtaRoutes.resources: (_) => const Scaffold(body: Text('Resources')),
        },
      ),
    );
    final coordinator = PushNavigationCoordinator(
      navigatorKey: navigatorKey,
      service: _pushService(),
      accessState: () => const PushAccessState(
        stage: SessionStage.member,
        memberLocationId: 'ota-cheshire',
      ),
    );
    coordinator.handlePayload({
      'contentType': 'resource',
      'contentId': 'missing',
      'locationId': 'ota-cheshire',
    });
    await tester.pumpAndSettle();
    expect(find.byType(ResourceDetailScreen), findsOneWidget);
    expect(find.text('This item is no longer available.'), findsOneWidget);
  });

  test('push payload parsing and authorization reject malformed data', () {
    expect(PushDestination.tryParse({'contentType': 'event'}), isNull);
    expect(PushDestination.tryDecode('not-json'), isNull);
    final pending = PendingPushDestination();
    pending.queue(
      const PushDestination(
        type: PushContentType.event,
        contentId: 'event-1',
        locationId: 'other',
      ),
    );
    expect(
      pending.takeIfAuthorized(
        stage: SessionStage.member,
        memberLocationId: 'ota-cheshire',
        navigatorReady: true,
      ),
      isNull,
    );
  });

  test(
    'pending navigation waits for member authentication and deduplicates',
    () {
      final pending = PendingPushDestination();
      const destination = PushDestination(
        type: PushContentType.announcement,
        contentId: 'notice-1',
        locationId: 'ota-cheshire',
      );
      pending.queue(destination);
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.loading,
          memberLocationId: 'ota-cheshire',
          navigatorReady: true,
        ),
        isNull,
      );
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'ota-cheshire',
          navigatorReady: true,
        ),
        same(destination),
      );
      pending.queue(destination);
      expect(
        pending.takeIfAuthorized(
          stage: SessionStage.member,
          memberLocationId: 'ota-cheshire',
          navigatorReady: true,
        ),
        isNull,
      );
    },
  );

  test(
    'device registration lifecycle uses one installation document',
    () async {
      debugViewController.clear();
      final tokens = _FakeTokenProvider('token-1');
      final registrations = _FakeRegistrationStore();
      final service = PushNotificationService(
        tokenProvider: tokens,
        registrationStore: registrations,
        installationIds: _FakeInstallationIdStore(),
      );
      final authentication = _FakeAuthenticationService(_FakeUser());
      final session = FirebaseSessionController(authentication: authentication)
        ..stage = SessionStage.member
        ..authUser = authentication.currentUser
        ..account = _account;

      await service.handleSession(session);
      await service.handleSession(session);
      expect(registrations.writes, ['member-1:install-1:token-1']);
      tokens.emit('token-2');
      await Future<void>.delayed(Duration.zero);
      expect(registrations.writes.last, 'member-1:install-1:token-2');
      await service.unregisterForSignOut();
      expect(registrations.deletes, ['member-1:install-1']);
      expect(tokens.deleteCalls, 1);
    },
  );

  test('family query limits and event window remain bounded', () {
    expect(FirebaseAppDataService.memberAnnouncementLimit, 30);
    expect(FirebaseAppDataService.memberEventLimit, 50);
    expect(FirebaseAppDataService.memberResourceLimit, 50);
    expect(memberEventWindowStart(DateTime(2026, 7, 20)), DateTime(2026, 6));
  });
}

DateTime _dateForWeekday(int weekday) {
  final monday = DateTime(2026, 7, 20);
  return monday.add(Duration(days: weekday - DateTime.monday));
}

const _account = UserAccount(
  id: 'member-1',
  firstName: 'Parent',
  lastName: 'Member',
  email: 'parent@example.com',
  role: UserAccountRole.parent,
  linkedStudentProfileIds: ['student-1'],
  selectedStudentProfileId: 'student-1',
  locationId: 'ota-cheshire',
);

class _MutableAppDataService extends MockAppDataService {
  _MutableAppDataService() {
    notificationItems = List.of(super.notifications);
    resourceItems = List.of(super.resources);
    scheduleItems = {
      for (final entry in super.schedule.entries)
        entry.key: List.of(entry.value),
    };
  }

  late List<NotificationItem> notificationItems;
  late List<AcademyResource> resourceItems;
  late Map<int, List<ClassSession>> scheduleItems;

  @override
  List<NotificationItem> get notifications => notificationItems;

  @override
  List<AcademyResource> get resources => resourceItems;

  @override
  Map<int, List<ClassSession>> get schedule => scheduleItems;

  void removeNotification(String id) {
    notificationItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void removeResource(String id) {
    resourceItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearResources() => resourceItems.clear();

  void removeClass(String id) {
    for (final items in scheduleItems.values) {
      items.removeWhere((item) => item.id == id);
    }
    notifyListeners();
  }
}

class _FakeTokenProvider implements PushTokenProvider {
  _FakeTokenProvider(this.token);

  String token;
  int deleteCalls = 0;
  final _refreshes = StreamController<String>.broadcast();

  void emit(String value) => _refreshes.add(value);

  @override
  Future<void> deleteToken() async => deleteCalls++;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refreshes.stream;

  @override
  Future<bool> requestPermission() async => true;
}

class _FakeInstallationIdStore implements InstallationIdStore {
  @override
  Future<String> getOrCreate() async => 'install-1';
}

class _FakeRegistrationStore implements DeviceRegistrationStore {
  final writes = <String>[];
  final deletes = <String>[];

  @override
  Future<void> delete({
    required String uid,
    required String installationId,
  }) async {
    deletes.add('$uid:$installationId');
  }

  @override
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
    required String environment,
  }) async {
    writes.add('$uid:$installationId:$token');
  }
}

class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthenticationService implements AuthenticationService {
  _FakeAuthenticationService(this.currentUser);

  @override
  final User? currentUser;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PushNotificationService _pushService() => PushNotificationService(
  tokenProvider: _FakeTokenProvider('token'),
  registrationStore: _FakeRegistrationStore(),
  installationIds: _FakeInstallationIdStore(),
);
