import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

bool debugViewsAllowed({
  required AppEnvironment environment,
  required bool debugBuild,
}) => environment == AppEnvironment.dev && debugBuild;

class AppEnvironmentConfig {
  const AppEnvironmentConfig._();

  static AppEnvironment _current = AppEnvironment.dev;

  static AppEnvironment get current => _current;
  static bool get isDevelopment => _current == AppEnvironment.dev;
  static bool get allowsDebugViews =>
      debugViewsAllowed(environment: _current, debugBuild: kDebugMode);

  static void initialize(AppEnvironment environment) {
    _current = environment;
  }
}
