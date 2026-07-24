import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/notification_detail_screen.dart';
import 'package:ota_cheshire_management_platform/services/app_data_service_provider.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/push_navigation_coordinator.dart';
import 'package:ota_cheshire_management_platform/services/push_notification_service.dart';

void main() {
  setUp(initializeMockAppDataServiceForTests);

  test('Firebase Console-style foreground notification is displayed', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(displays);

    await coordinator.showForegroundMessage(
      RemoteMessage(
        messageId: 'console-message',
        notification: const RemoteNotification(
          title: 'Academy update',
          body: 'Class starts soon.',
        ),
      ),
    );

    expect(displays, hasLength(1));
    expect(displays.single.title, 'Academy update');
    expect(displays.single.body, 'Class starts soon.');
    expect(displays.single.payload, isNull);
  });

  test('valid destination is displayed with a navigation payload', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(displays);

    await coordinator.showForegroundMessage(
      RemoteMessage(
        messageId: 'destination-message',
        data: _validData,
        notification: const RemoteNotification(
          title: 'New announcement',
          body: 'Open for details.',
        ),
      ),
    );

    expect(displays, hasLength(1));
    expect(PushDestination.tryDecode(displays.single.payload), isNotNull);
    expect(
      PushDestination.tryDecode(displays.single.payload)?.contentId,
      _validData['contentId'],
    );
  });

  test('malformed destination still displays visible content', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(displays);

    await coordinator.showForegroundMessage(
      RemoteMessage(
        data: const {'contentType': 'event', 'contentId': ''},
        notification: const RemoteNotification(
          title: 'Visible title',
          body: 'Visible body',
        ),
      ),
    );

    expect(displays, hasLength(1));
    expect(displays.single.title, 'Visible title');
    expect(displays.single.body, 'Visible body');
    expect(displays.single.payload, isNull);
  });

  test('valid data-only message uses fallback visible content', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(displays);

    await coordinator.showForegroundMessage(RemoteMessage(data: _validData));

    expect(displays, hasLength(1));
    expect(displays.single.title, 'Olympic Taekwondo Academy');
    expect(displays.single.body, 'A new academy update is available.');
    expect(displays.single.payload, isNotNull);
  });

  test('completely empty foreground message is ignored', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(displays);

    await coordinator.showForegroundMessage(const RemoteMessage());

    expect(displays, isEmpty);
  });

  testWidgets('foreground notification without payload cannot navigate', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Dashboard')),
      ),
    );
    final coordinator = _coordinator(
      <ForegroundNotificationRequest>[],
      navigatorKey: navigatorKey,
    );

    coordinator.handlePayload(const {'contentType': 'announcement'});
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(NotificationDetailScreen), findsNothing);
  });

  testWidgets('valid foreground destination keeps existing deep linking', (
    tester,
  ) async {
    final notification = appDataService.notifications.first;
    final data = {
      'contentType': 'announcement',
      'contentId': notification.id,
      'locationId': 'ota-cheshire',
    };
    final displays = <ForegroundNotificationRequest>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Dashboard')),
        routes: {
          OtaRoutes.notifications: (_) =>
              const Scaffold(body: Text('Notifications')),
        },
      ),
    );
    final coordinator = _coordinator(displays, navigatorKey: navigatorKey);
    await coordinator.showForegroundMessage(
      RemoteMessage(
        messageId: 'deep-link-message',
        data: data,
        notification: const RemoteNotification(
          title: 'Announcement',
          body: 'Tap to open.',
        ),
      ),
    );

    final destination = PushDestination.tryDecode(displays.single.payload);
    expect(destination, isNotNull);
    coordinator.handlePayload(data);
    await tester.pumpAndSettle();

    expect(find.byType(NotificationDetailScreen), findsOneWidget);
    expect(find.text(notification.title), findsWidgets);
  });

  test('foreground notification IDs are stable when messageId exists', () {
    final first = foregroundNotificationId(
      messageId: 'stable-message-id',
      destination: null,
    );
    final second = foregroundNotificationId(
      messageId: 'stable-message-id',
      destination: const PushDestination(
        type: PushContentType.event,
        contentId: 'event-1',
        locationId: 'ota-cheshire',
      ),
    );

    expect(first, second);
    expect(first, greaterThanOrEqualTo(0));
  });

  test('Android local display can be disabled for iOS presentation', () async {
    final displays = <ForegroundNotificationRequest>[];
    final coordinator = _coordinator(
      displays,
      useAndroidForegroundNotifications: false,
    );

    await coordinator.showForegroundMessage(
      RemoteMessage(
        data: _validData,
        notification: const RemoteNotification(title: 'Shown by iOS'),
      ),
    );

    expect(displays, isEmpty);
  });
}

const _validData = {
  'contentType': 'announcement',
  'contentId': 'notification-1',
  'locationId': 'ota-cheshire',
};

PushNavigationCoordinator _coordinator(
  List<ForegroundNotificationRequest> displays, {
  GlobalKey<NavigatorState>? navigatorKey,
  bool useAndroidForegroundNotifications = true,
}) => PushNavigationCoordinator(
  navigatorKey: navigatorKey ?? GlobalKey<NavigatorState>(),
  service: PushNotificationService(
    tokenProvider: _UnusedTokenProvider(),
    registrationStore: _UnusedRegistrationStore(),
    installationIds: _UnusedInstallationIdStore(),
  ),
  accessState: () => const PushAccessState(
    stage: SessionStage.member,
    memberLocationId: 'ota-cheshire',
  ),
  foregroundNotificationDisplay: (notification) async {
    displays.add(notification);
  },
  useAndroidForegroundNotifications: useAndroidForegroundNotifications,
);

class _UnusedTokenProvider implements PushTokenProvider {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<bool> requestPermission() async => false;
}

class _UnusedRegistrationStore implements DeviceRegistrationStore {
  @override
  Future<void> delete({
    required String uid,
    required String installationId,
  }) async {}

  @override
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
    required String environment,
  }) async {}
}

class _UnusedInstallationIdStore implements InstallationIdStore {
  @override
  Future<String> getOrCreate() async => 'unused';
}
