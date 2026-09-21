import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android startup and Crashlytics configuration cover both flavors', () {
    final rootGradle = File('android/build.gradle.kts').readAsStringSync();
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/otamanagement/app/MainActivity.kt',
    ).readAsStringSync();
    final devServices = File(
      'android/app/src/dev/google-services.json',
    ).readAsStringSync();
    final prodServices = File(
      'android/app/src/prod/google-services.json',
    ).readAsStringSync();

    expect(rootGradle, contains('com.google.firebase.crashlytics'));
    expect(appGradle, contains('id("com.google.firebase.crashlytics")'));
    expect(appGradle, contains('applicationId = "com.otamanagement.app"'));
    expect(appGradle, contains('applicationId = "com.otacheshire.app"'));
    expect(appGradle, contains('"lib/main_dev.dart"'));
    expect(appGradle, contains('"lib/main_prod.dart"'));
    expect(appGradle, contains('afterEvaluate'));
    expect(appGradle, contains('targetPath != expectedTargetPath'));
    expect(appGradle, contains('mergeProdReleaseJniLibFolders'));
    expect(appGradle, contains('outputs.upToDateWhen { false }'));
    expect(activity, contains('activity_on_create'));
    expect(activity, contains('flutter_engine_configure_complete'));
    expect(activity, contains('flutter_first_frame_displayed'));
    expect(activity, isNot(contains('FirebaseCrashlytics')));
    expect(activity, isNot(contains('firebase.')));
    expect(devServices, contains('"project_id": "ota-management-platform"'));
    expect(
      prodServices,
      contains('"project_id": "ota-management-platform-e4847"'),
    );
  });
}
