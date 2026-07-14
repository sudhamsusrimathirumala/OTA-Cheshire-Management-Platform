import 'package:flutter/foundation.dart';

import '../../routes.dart';
import 'firebase_session_controller.dart';

enum RouteAccess { public, authenticated, student, admin }

const _developmentNavigationToken = Object();

Object developmentNavigationArguments() {
  assert(kDebugMode);
  return _developmentNavigationToken;
}

bool isDevelopmentNavigationRequest(Object? arguments) {
  return kDebugMode && identical(arguments, _developmentNavigationToken);
}

RouteAccess accessForRoute(String? routeName) {
  return switch (routeName) {
    OtaRoutes.welcome ||
    OtaRoutes.login ||
    OtaRoutes.signup => RouteAccess.public,
    OtaRoutes.profile || OtaRoutes.membership => RouteAccess.authenticated,
    OtaRoutes.dashboard ||
    OtaRoutes.schedule ||
    OtaRoutes.events ||
    OtaRoutes.resources ||
    OtaRoutes.generalResources ||
    OtaRoutes.curriculum ||
    OtaRoutes.notifications => RouteAccess.student,
    OtaRoutes.adminDashboard ||
    OtaRoutes.adminStudents ||
    OtaRoutes.adminEvents ||
    OtaRoutes.adminAnnouncements ||
    OtaRoutes.adminSchedule ||
    OtaRoutes.adminResources ||
    OtaRoutes.adminGeneralResources ||
    OtaRoutes.adminCurriculum ||
    OtaRoutes.adminProfile => RouteAccess.admin,
    _ => RouteAccess.public,
  };
}

bool isRouteAuthorized({
  required String? routeName,
  required SessionStage stage,
  Object? arguments,
}) {
  if (isDevelopmentNavigationRequest(arguments)) return true;
  return switch (accessForRoute(routeName)) {
    RouteAccess.public => true,
    RouteAccess.authenticated => switch (stage) {
      SessionStage.incomplete ||
      SessionStage.pending ||
      SessionStage.approved ||
      SessionStage.rejected ||
      SessionStage.disabled ||
      SessionStage.adminDisabled ||
      SessionStage.admin => true,
      _ => false,
    },
    RouteAccess.student => stage == SessionStage.approved,
    RouteAccess.admin => stage == SessionStage.admin,
  };
}

bool protectedAccessWasLost(SessionStage previous, SessionStage current) {
  return (previous == SessionStage.approved &&
          current != SessionStage.approved) ||
      (previous == SessionStage.admin && current != SessionStage.admin) ||
      current == SessionStage.signedOut;
}
