// File generated from the Firebase Android and iOS app SDK configurations.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class ProductionFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'ProductionFirebaseOptions have not been configured for web.',
      );
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
