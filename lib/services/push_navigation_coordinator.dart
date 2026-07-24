import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../routes.dart';
import '../screens/content_unavailable_screen.dart';
import '../screens/events_screen.dart';
import '../screens/notification_detail_screen.dart';
import '../screens/resource_detail_screen.dart';
import 'app_data_service_provider.dart';
import 'firebase/firebase_session_controller.dart';
import 'push_notification_service.dart';

class PushNavigationCoordinator {
  PushNavigationCoordinator({
    required this.navigatorKey,
    required this.service,
    FlutterLocalNotificationsPlugin? localNotifications,
    PushAccessState Function()? accessState,
    this.foregroundNotificationDisplay,
    bool? useAndroidForegroundNotifications,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _useAndroidForegroundNotifications =
           useAndroidForegroundNotifications ??
           defaultTargetPlatform == TargetPlatform.android,
       _accessState =
           accessState ??
           (() {
             final session = firebaseSessionController;
             return PushAccessState(
               stage: session.stage,
               memberLocationId: session.selectedProfile?.locationId,
             );
           });

  final GlobalKey<NavigatorState> navigatorKey;
  final PushNotificationService service;
  final FlutterLocalNotificationsPlugin _localNotifications;
  @visibleForTesting
  final ForegroundNotificationDisplay? foregroundNotificationDisplay;
  final bool _useAndroidForegroundNotifications;
  final PushAccessState Function() _accessState;
  final PendingPushDestination _pending = PendingPushDestination();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> initialize() async {
    const androidChannel = AndroidNotificationChannel(
      otaUpdatesChannelId,
      otaUpdatesChannelName,
      description: 'Announcements, events, and resources from the academy.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_ota'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final destination = PushDestination.tryDecode(response.payload);
        if (destination != null) {
          _pending.queue(destination);
          flush();
        }
      },
    );
    await service.messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      showForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _queueRemoteMessage,
    );
    final initial = await service.messaging.getInitialMessage();
    if (initial != null) _queueRemoteMessage(initial);
  }

  void _queueRemoteMessage(RemoteMessage message) {
    handlePayload(message.data);
  }

  void handlePayload(Map<String, dynamic> data) {
    final destination = PushDestination.tryParse(data);
    if (destination == null) return;
    _pending.queue(destination);
    flush();
  }

  @visibleForTesting
  Future<void> showForegroundMessage(RemoteMessage message) async {
    if (!_useAndroidForegroundNotifications) return;
    final destination = PushDestination.tryParse(message.data);
    final notification = message.notification;
    final receivedTitle = _visibleText(notification?.title);
    final receivedBody = _visibleText(notification?.body);
    if (destination == null && receivedTitle == null && receivedBody == null) {
      return;
    }
    final display = ForegroundNotificationRequest(
      id: foregroundNotificationId(
        messageId: message.messageId,
        destination: destination,
      ),
      title: receivedTitle ?? 'Olympic Taekwondo Academy',
      body: receivedBody ?? 'A new academy update is available.',
      payload: destination?.encode(),
    );
    final displayOverride = foregroundNotificationDisplay;
    if (displayOverride != null) {
      await displayOverride(display);
      return;
    }
    await _localNotifications.show(
      id: display.id,
      title: display.title,
      body: display.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          otaUpdatesChannelId,
          otaUpdatesChannelName,
          channelDescription:
              'Announcements, events, and resources from the academy.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_ota',
        ),
      ),
      payload: display.payload,
    );
  }

  void flush() {
    final access = _accessState();
    final destination = _pending.takeIfAuthorized(
      stage: access.stage,
      memberLocationId: access.memberLocationId,
      navigatorReady: navigatorKey.currentState != null,
    );
    if (destination == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(destination));
  }

  void _open(PushDestination destination) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pending.queue(destination);
      return;
    }
    switch (destination.type) {
      case PushContentType.announcement:
        final notification = appDataService.notifications
            .where((item) => item.id == destination.contentId)
            .firstOrNull;
        navigator.pushNamed(OtaRoutes.notifications);
        if (notification == null) {
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const ContentUnavailableScreen(
                returnRoute: OtaRoutes.notifications,
              ),
            ),
          );
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                NotificationDetailScreen(notification: notification),
          ),
        );
        unawaited(appDataService.markNotificationRead(notification.id));
      case PushContentType.event:
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => EventsScreen(initialEventId: destination.contentId),
          ),
        );
      case PushContentType.resource:
        navigator.pushNamed(OtaRoutes.resources);
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ResourceDetailScreen.fromId(resourceId: destination.contentId),
          ),
        );
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}

typedef ForegroundNotificationDisplay =
    Future<void> Function(ForegroundNotificationRequest notification);

class ForegroundNotificationRequest {
  const ForegroundNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String? payload;
}

@visibleForTesting
int foregroundNotificationId({
  required String? messageId,
  required PushDestination? destination,
  DateTime? now,
}) {
  final normalizedMessageId = _visibleText(messageId);
  if (normalizedMessageId != null) {
    return _stableNotificationId(normalizedMessageId);
  }
  if (destination != null) {
    return _stableNotificationId(
      '${destination.type.name}:${destination.contentId}:${destination.locationId}',
    );
  }
  return (now ?? DateTime.now()).millisecondsSinceEpoch & 0x7fffffff;
}

String? _visibleText(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

class PushAccessState {
  const PushAccessState({required this.stage, required this.memberLocationId});

  final SessionStage stage;
  final String? memberLocationId;
}
