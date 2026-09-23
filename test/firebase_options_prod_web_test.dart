import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/firebase_options_prod.dart';
import 'package:ota_cheshire_management_platform/services/startup_failure.dart';

void main() {
  test(
    'production Web options fail safely when registration values are absent',
    () {
      expect(
        () => ProductionFirebaseOptions.webFromValues(
          apiKey: '',
          appId: '',
          messagingSenderId: '',
          projectId: '',
          authDomain: '',
          storageBucket: '',
        ),
        throwsA(
          isA<ApplicationStartupFailure>().having(
            (error) => error.code,
            'code',
            'firebase-web-config-missing',
          ),
        ),
      );
    },
  );

  test(
    'production Web options preserve supplied Firebase registration values',
    () {
      final options = ProductionFirebaseOptions.webFromValues(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: '123456',
        projectId: 'test-project',
        authDomain: 'test-project.firebaseapp.com',
        storageBucket: 'test-project.firebasestorage.app',
      );

      expect(options.projectId, 'test-project');
      expect(options.authDomain, 'test-project.firebaseapp.com');
      expect(options.measurementId, isNull);
    },
  );
}
