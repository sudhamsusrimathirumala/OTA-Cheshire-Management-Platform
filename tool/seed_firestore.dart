import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:ota_cheshire_management_platform/firebase_options_dev.dart';
import 'package:ota_cheshire_management_platform/services/firestore/firestore_seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DevelopmentFirebaseOptions.currentPlatform,
    );

    stdout.writeln('Seeding Firestore mock data...');
    await FirestoreSeedService().seedAll();
    stdout.writeln('Firestore seed complete.');
  } catch (error, stackTrace) {
    stderr.writeln('Firestore seed failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
