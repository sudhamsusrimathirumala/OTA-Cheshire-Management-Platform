import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

class AppEnvironmentConfig {
  const AppEnvironmentConfig._();

  static AppEnvironment _current = AppEnvironment.dev;

  static AppEnvironment get current => _current;
  static bool get isDevelopment => _current == AppEnvironment.dev;
  static bool get allowsDebugViews => isDevelopment && kDebugMode;

  static void initialize(AppEnvironment environment) {
    _current = environment;
  }
}
