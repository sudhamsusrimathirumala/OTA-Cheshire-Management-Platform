import 'package:flutter/foundation.dart';

import '../routes.dart';

enum DebugMockRole { student, admin }

class DebugMockRoleState extends ValueNotifier<DebugMockRole> {
  DebugMockRoleState() : super(DebugMockRole.student);

  String get initialRoute {
    if (!kDebugMode) {
      return OtaRoutes.dashboard;
    }

    return routeFor(value);
  }

  String routeFor(DebugMockRole role) {
    return switch (role) {
      DebugMockRole.student => OtaRoutes.dashboard,
      DebugMockRole.admin => OtaRoutes.adminDashboard,
    };
  }

  void switchTo(DebugMockRole role) {
    if (!kDebugMode || value == role) {
      return;
    }

    value = role;
  }

  @visibleForTesting
  void resetForTesting() {
    value = DebugMockRole.student;
  }
}

final DebugMockRoleState debugMockRoleState = DebugMockRoleState();
