import 'app_bootstrap.dart';
import 'app_environment.dart';
import 'firebase_options_dev.dart';

Future<void> main() => bootstrapApplication(
  environment: AppEnvironment.dev,
  firebaseOptions: DevelopmentFirebaseOptions.currentPlatform,
);
