import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsigned production bundle opt-in cannot silently relax APK signing', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final workflow = File('.github/workflows/build-unsigned-android-aab.yml')
        .readAsStringSync();

    expect(gradle, contains('System.getenv("OTA_ALLOW_UNSIGNED_PROD_AAB") == "true"'));
    expect(gradle, contains('requestedGradleTasks.isNotEmpty()'));
    expect(gradle, contains('requestedGradleTasks.all {'));
    expect(gradle, contains('equals("bundleProdRelease", ignoreCase = true)'));
    expect(gradle, contains('!releaseSigningConfigured &&'));
    expect(gradle, contains('!allowUnsignedProdBundle'));
    expect(gradle, contains('Production release signing is not configured.'));

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('OTA_ALLOW_UNSIGNED_PROD_AAB: "true"'));
    expect(workflow, contains('flutter build appbundle --release --flavor prod'));
    expect(workflow, contains('lib/main_prod.dart'));
    expect(workflow, contains('OTA-Cheshire-prod-UNSIGNED'));
    expect(workflow, isNot(contains('ANDROID_UPLOAD_KEYSTORE_BASE64')));
    expect(workflow, isNot(contains('jarsigner -keystore')));
  });
}
