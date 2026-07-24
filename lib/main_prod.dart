import 'app_bootstrap.dart';
import 'app_environment.dart';
import 'firebase_options_prod.dart';

Future<void> main() => bootstrapApplication(
  environment: AppEnvironment.prod,
  firebaseOptions: ProductionFirebaseOptions.currentPlatform,
);
