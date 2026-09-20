import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'services/startup_diagnostics.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}

Future<void> bootstrapApplication({
  required AppEnvironment environment,
  required FirebaseOptions firebaseOptions,
}) async {
  startupDiagnostics.checkpoint('dart_bootstrap_entered');
  WidgetsFlutterBinding.ensureInitialized();
  startupDiagnostics.installUncaughtErrorHandlers();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    startupDiagnostics.checkpoint('dart_first_frame_rendered');
  });
  Future<void>? initialization;
  Future<void> initialize(ValueChanged<ApplicationStartupStep> reportStep) {
    final running = initialization;
    if (running != null) return running;
    late Future<void> started;
    started =
        _initializeApplication(
          environment: environment,
          firebaseOptions: firebaseOptions,
          reportStep: reportStep,
        ).catchError((Object error, StackTrace stack) {
          if (identical(initialization, started)) initialization = null;
          Error.throwWithStackTrace(error, stack);
        });
    initialization = started;
    return started;
  }

  startupDiagnostics.checkpoint('run_app');
  runApp(
    ApplicationStartupGate(
      initialize: initialize,
      application: const OTAApp(),
      onFailure: ({required step, required code}) =>
          startupDiagnostics.recordStartupFailure(step: step.name, code: code),
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
  startupDiagnostics.checkpoint('firebase_initialize_start');
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: firebaseOptions);
  }
  startupDiagnostics.checkpoint('firebase_initialize_complete');
  unawaited(
    startupDiagnostics.attachCrashReporter(
      reporter: FirebaseStartupCrashReporter(FirebaseCrashlytics.instance),
      environment: environment,
    ),
  );
  unawaited(
    startupDiagnostics.recordDevelopmentNonfatalVerification(
      environment: environment,
      enabled: const bool.fromEnvironment(
        'OTA_CRASHLYTICS_NONFATAL_TEST',
        defaultValue: false,
      ),
    ),
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final pushService = PushNotificationService();
  pushNotificationService = pushService;
  pushNavigationCoordinator = PushNavigationCoordinator(
    navigatorKey: otaNavigatorKey,
    service: pushService,
  );
  reportStep(ApplicationStartupStep.session);
  firebaseSessionController.signOutCleanup = pushService.unregisterForSignOut;
  firebaseSessionController.start();
  initializeFirebaseAppDataService();
  startupDiagnostics.checkpoint('session_initialize_complete');
  unawaited(
    _initializeNotifications(
      coordinator: pushNavigationCoordinator!,
      reportStep: reportStep,
    ),
  );
}

Future<void> _initializeNotifications({
  required PushNavigationCoordinator coordinator,
  required ValueChanged<ApplicationStartupStep> reportStep,
}) async {
  reportStep(ApplicationStartupStep.pushNotifications);
  startupDiagnostics.checkpoint('notifications_initialize_start');
  try {
    await coordinator.initialize().timeout(const Duration(seconds: 15));
    startupDiagnostics.checkpoint('notifications_initialize_complete');
  } on TimeoutException {
    await startupDiagnostics.recordStartupFailure(
      step: ApplicationStartupStep.pushNotifications.name,
      code: 'timeout',
    );
  } on FirebaseException catch (error) {
    await startupDiagnostics.recordStartupFailure(
      step: ApplicationStartupStep.pushNotifications.name,
      code: _safeCode(error.code),
    );
  } catch (_) {
    await startupDiagnostics.recordStartupFailure(
      step: ApplicationStartupStep.pushNotifications.name,
      code: 'initialization-failed',
    );
  }
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
    this.onFailure,
    this.timeout = const Duration(seconds: 30),
    super.key,
  });

  final Future<void> Function(ValueChanged<ApplicationStartupStep> reportStep)
  initialize;
  final Widget application;
  final Future<void> Function({
    required ApplicationStartupStep step,
    required String code,
  })?
  onFailure;
  final Duration timeout;

  @override
  State<ApplicationStartupGate> createState() => _ApplicationStartupGateState();
}

class _ApplicationStartupGateState extends State<ApplicationStartupGate> {
  ApplicationStartupStep _step = ApplicationStartupStep.preparing;
  String? _failureCode;
  bool _ready = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _failureCode = null;
    });
    try {
      await widget.initialize(_reportStep).timeout(widget.timeout);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _initializing = false;
      });
    } on TimeoutException {
      _fail('timeout');
    } on FirebaseException catch (error) {
      _fail(_safeCode(error.code));
    } catch (_) {
      _fail('startup-failed');
    }
  }

  void _reportStep(ApplicationStartupStep step) {
    startupDiagnostics.checkpoint(step.name);
    if (!mounted) return;
    setState(() => _step = step);
  }

  void _fail(String code) {
    unawaited(widget.onFailure?.call(step: _step, code: code));
    if (!mounted) return;
    setState(() {
      _failureCode = code;
      _initializing = false;
    });
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
                          'Check your connection and try again. If this '
                          'continues, contact the academy.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _initializing ? null : _initialize,
                          child: const Text('Try again'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Reference: ${_step.name} / $_failureCode',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
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
