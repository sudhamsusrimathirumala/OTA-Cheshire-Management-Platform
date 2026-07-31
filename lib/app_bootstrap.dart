import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  runApp(
    ApplicationStartupGate(
      initialize: (reportStep) => _initializeApplication(
        environment: environment,
        firebaseOptions: firebaseOptions,
        reportStep: reportStep,
      ),
      application: const OTAApp(),
    ),
  );
}

Future<void> _initializeApplication({
  required AppEnvironment environment,
  required FirebaseOptions firebaseOptions,
  required ValueChanged<ApplicationStartupStep> reportStep,
}) async {
  reportStep(ApplicationStartupStep.environment);
  AppEnvironmentConfig.initialize(environment);
  LocationTimeService.initialize();
  reportStep(ApplicationStartupStep.firebase);
  await Firebase.initializeApp(options: firebaseOptions);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final pushService = PushNotificationService();
  pushNotificationService = pushService;
  pushNavigationCoordinator = PushNavigationCoordinator(
    navigatorKey: otaNavigatorKey,
    service: pushService,
  );
  reportStep(ApplicationStartupStep.pushNotifications);
  await pushNavigationCoordinator!.initialize();
  reportStep(ApplicationStartupStep.session);
  firebaseSessionController.signOutCleanup = pushService.unregisterForSignOut;
  firebaseSessionController.start();
  initializeFirebaseAppDataService();
}

enum ApplicationStartupStep {
  preparing,
  environment,
  firebase,
  pushNotifications,
  session,
}

class ApplicationStartupGate extends StatefulWidget {
  const ApplicationStartupGate({
    required this.initialize,
    required this.application,
    this.timeout = const Duration(seconds: 30),
    super.key,
  });

  final Future<void> Function(ValueChanged<ApplicationStartupStep> reportStep)
  initialize;
  final Widget application;
  final Duration timeout;

  @override
  State<ApplicationStartupGate> createState() => _ApplicationStartupGateState();
}

class _ApplicationStartupGateState extends State<ApplicationStartupGate> {
  ApplicationStartupStep _step = ApplicationStartupStep.preparing;
  String? _failureCode;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize(_reportStep).timeout(widget.timeout);
      if (!mounted) return;
      setState(() => _ready = true);
    } on TimeoutException {
      _fail('timeout');
    } on FirebaseException catch (error) {
      _fail(_safeCode(error.code));
    } catch (_) {
      _fail('startup-failed');
    }
  }

  void _reportStep(ApplicationStartupStep step) {
    if (kDebugMode) debugPrint('OTA startup: ${step.name}');
    if (!mounted) return;
    setState(() => _step = step);
  }

  void _fail(String code) {
    if (kDebugMode) {
      debugPrint('OTA startup failed: ${_step.name} ($code)');
    }
    if (!mounted) return;
    setState(() => _failureCode = code);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.application;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _failureCode == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFF7A1F2B),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'The app could not start.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Please close and reopen the app. If this continues, '
                          'contact the academy.',
                          textAlign: TextAlign.center,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 18),
                          Text('Startup step: ${_step.name}'),
                          Text('Code: $_failureCode'),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _safeCode(String value) {
  final safe = value.replaceAll(RegExp('[^a-zA-Z0-9_/-]'), '-');
  return safe.isEmpty
      ? 'startup-failed'
      : safe.substring(0, safe.length.clamp(0, 64));
}
