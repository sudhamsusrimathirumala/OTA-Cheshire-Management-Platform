import 'package:flutter/foundation.dart';

import '../app_environment.dart';

enum DebugViewMode { none, student, admin }

DebugViewMode debugViewModeForBuild({
  required bool debugBuild,
  required DebugViewMode requestedMode,
}) => debugBuild ? requestedMode : DebugViewMode.none;

class DebugViewController extends ChangeNotifier {
  DebugViewMode _mode = DebugViewMode.none;

  DebugViewMode get mode => debugViewModeForBuild(
    debugBuild: AppEnvironmentConfig.allowsDebugViews,
    requestedMode: _mode,
  );
  bool get isActive => mode != DebugViewMode.none;
  bool get isStudent => mode == DebugViewMode.student;
  bool get isAdmin => mode == DebugViewMode.admin;

  void enterStudent() => _setMode(DebugViewMode.student);
  void enterAdmin() => _setMode(DebugViewMode.admin);

  void clear() {
    if (_mode == DebugViewMode.none) return;
    _mode = DebugViewMode.none;
    notifyListeners();
  }

  void _setMode(DebugViewMode value) {
    final effective = debugViewModeForBuild(
      debugBuild: AppEnvironmentConfig.allowsDebugViews,
      requestedMode: value,
    );
    if (_mode == effective) return;
    _mode = effective;
    notifyListeners();
  }
}

final DebugViewController debugViewController = DebugViewController();
