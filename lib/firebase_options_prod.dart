import 'package:firebase_core/firebase_core.dart';

/// Production Firebase values must be generated from the academy-owned project.
/// This placeholder intentionally contains no development or fake credentials.
class ProductionFirebaseOptions {
  const ProductionFirebaseOptions._();

  static FirebaseOptions get currentPlatform => throw StateError(
    'Production Firebase is not configured. Replace '
    'lib/firebase_options_prod.dart using the academy-owned Firebase project.',
  );
}
