// File generated from the Firebase Android and iOS app SDK configurations.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'services/startup_failure.dart';

class ProductionFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'ProductionFirebaseOptions have not been configured for this '
          'platform.',
        );
    }
  }

  static const _webApiKey = String.fromEnvironment('OTA_FIREBASE_WEB_API_KEY');
  static const _webAppId = String.fromEnvironment('OTA_FIREBASE_WEB_APP_ID');
  static const _webMessagingSenderId = String.fromEnvironment(
    'OTA_FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const _webProjectId = String.fromEnvironment(
    'OTA_FIREBASE_WEB_PROJECT_ID',
  );
  static const _webAuthDomain = String.fromEnvironment(
    'OTA_FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const _webStorageBucket = String.fromEnvironment(
    'OTA_FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const _webMeasurementId = String.fromEnvironment(
    'OTA_FIREBASE_WEB_MEASUREMENT_ID',
  );

  static FirebaseOptions get web => webFromValues(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _webMessagingSenderId,
    projectId: _webProjectId,
    authDomain: _webAuthDomain,
    storageBucket: _webStorageBucket,
    measurementId: _webMeasurementId,
  );

  static FirebaseOptions webFromValues({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    required String authDomain,
    required String storageBucket,
    String measurementId = '',
  }) {
    final requiredValues = {
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'authDomain': authDomain,
      'storageBucket': storageBucket,
    };
    if (requiredValues.values.any((value) => value.trim().isEmpty)) {
      throw const ApplicationStartupFailure(
        code: 'firebase-web-config-missing',
        userMessage:
            'The OTA Web app is not configured yet. Please contact the academy.',
      );
    }
    return FirebaseOptions(
      apiKey: apiKey.trim(),
      appId: appId.trim(),
      messagingSenderId: messagingSenderId.trim(),
      projectId: projectId.trim(),
      authDomain: authDomain.trim(),
      storageBucket: storageBucket.trim(),
      measurementId: measurementId.trim().isEmpty ? null : measurementId.trim(),
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBJEHdAfzLK6W9LBgzYdtIdT8w8qAsykXA',
    appId: '1:675595858362:android:815d377e29d8938e806d83',
    messagingSenderId: '675595858362',
    projectId: 'ota-management-platform-e4847',
    storageBucket: 'ota-management-platform-e4847.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAX0i7D1I9hZwsowKmr_lRlHI8ENQNFQ7E',
    appId: '1:675595858362:ios:acb8af23e611d52f806d83',
    messagingSenderId: '675595858362',
    projectId: 'ota-management-platform-e4847',
    storageBucket: 'ota-management-platform-e4847.firebasestorage.app',
    iosClientId:
        '675595858362-9ib7peesj2rgbs58oinnqev0mcqhekdo.apps.googleusercontent.com',
    iosBundleId: 'com.otacheshire.app',
  );
}
