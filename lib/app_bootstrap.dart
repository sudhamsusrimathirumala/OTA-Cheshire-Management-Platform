import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_environment.dart';
import 'services/app_data_service_provider.dart';
import 'services/firebase/firebase_session_controller.dart';
import 'services/location_time_service.dart';

Future<void> bootstrapApplication({
  required AppEnvironment environment,
  required FirebaseOptions firebaseOptions,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironmentConfig.initialize(environment);
  LocationTimeService.initialize();
  await Firebase.initializeApp(options: firebaseOptions);
  firebaseSessionController.start();
  initializeFirebaseAppDataService();
  runApp(const OTAApp());
}
