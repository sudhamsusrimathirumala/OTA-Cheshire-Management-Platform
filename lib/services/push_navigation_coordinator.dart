import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
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
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
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
      _showForegroundMessage,
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

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final destination = PushDestination.tryParse(message.data);
    if (destination == null) return;
    final notification = message.notification;
    await _localNotifications.show(
      id: destination.contentId.hashCode,
      title: notification?.title ?? 'Olympic Taekwondo Academy',
      body: notification?.body ?? 'A new academy update is available.',
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
      payload: destination.encode(),
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

class PushAccessState {
  const PushAccessState({required this.stage, required this.memberLocationId});

  final SessionStage stage;
  final String? memberLocationId;
}
