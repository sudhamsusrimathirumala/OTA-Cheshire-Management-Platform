import 'app_bootstrap.dart';
import 'app_environment.dart';
import 'firebase_options_dev.dart';
import 'services/startup_diagnostics.dart';

Future<void> main() {
  startupDiagnostics.checkpoint('dart_main_dev');
  return bootstrapApplication(
    environment: AppEnvironment.dev,
    firebaseOptions: DevelopmentFirebaseOptions.currentPlatform,
  );
}
