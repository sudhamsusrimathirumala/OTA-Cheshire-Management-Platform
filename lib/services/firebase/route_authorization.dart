import '../../routes.dart';
import '../debug_view_controller.dart';
import 'firebase_session_controller.dart';

enum RouteAccess { public, authenticated, student, admin }

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
  DebugViewMode debugMode = DebugViewMode.none,
}) {
  final access = accessForRoute(routeName);
  if (debugMode == DebugViewMode.student &&
      (access == RouteAccess.student || access == RouteAccess.authenticated)) {
    return true;
  }
  if (debugMode == DebugViewMode.admin && access == RouteAccess.admin) {
    return true;
  }
  return switch (access) {
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
