import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_environment.dart';
import 'services/app_data_service_provider.dart';
import 'services/firebase/firebase_session_controller.dart';
import 'services/location_time_service.dart';
import 'services/push_navigation_coordinator.dart';
import 'services/push_notification_service.dart';
import 'services/push_runtime.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

Future<void> bootstrapApplication({
  required AppEnvironment environment,
  required FirebaseOptions firebaseOptions,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironmentConfig.initialize(environment);
  LocationTimeService.initialize();
  await Firebase.initializeApp(options: firebaseOptions);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final pushService = PushNotificationService();
  pushNotificationService = pushService;
  pushNavigationCoordinator = PushNavigationCoordinator(
    navigatorKey: otaNavigatorKey,
    service: pushService,
  );
  await pushNavigationCoordinator!.initialize();
  firebaseSessionController.signOutCleanup = pushService.unregisterForSignOut;
  firebaseSessionController.start();
  initializeFirebaseAppDataService();
  runApp(const OTAApp());
}
