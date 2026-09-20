import '../../routes.dart';
import '../debug_view_controller.dart';
import '../guest/guest_experience_controller.dart';
import 'firebase_session_controller.dart';

enum RouteAccess { public, authenticated, student, realMember, admin, guest }

RouteAccess accessForRoute(String? routeName) {
  return switch (routeName) {
    OtaRoutes.welcome ||
    OtaRoutes.login ||
    OtaRoutes.signup => RouteAccess.public,
    OtaRoutes.guestDashboard => RouteAccess.guest,
    OtaRoutes.profile => RouteAccess.authenticated,
    OtaRoutes.accountDeletion => RouteAccess.realMember,
    OtaRoutes.manageProfiles => RouteAccess.student,
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
  GuestViewMode guestMode = GuestViewMode.parent,
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
      SessionStage.member ||
      SessionStage.disabled ||
      SessionStage.adminDisabled ||
      SessionStage.admin => true,
      SessionStage.guest => guestMode != GuestViewMode.admin,
      _ => false,
    },
    RouteAccess.student =>
      stage == SessionStage.member ||
          (stage == SessionStage.guest && guestMode != GuestViewMode.admin),
    RouteAccess.realMember => stage == SessionStage.member,
    RouteAccess.admin =>
      stage == SessionStage.admin ||
          (stage == SessionStage.guest && guestMode == GuestViewMode.admin),
    RouteAccess.guest => stage == SessionStage.guest,
  };
}

bool protectedAccessWasLost(SessionStage previous, SessionStage current) {
  if (current == SessionStage.loading) return false;
  return (previous == SessionStage.member && current != SessionStage.member) ||
      (previous == SessionStage.admin && current != SessionStage.admin) ||
      (previous == SessionStage.guest && current != SessionStage.guest);
}

SessionStage rememberedStageForRouteProtection(
  SessionStage previous,
  SessionStage current,
) {
  if (current == SessionStage.loading &&
      (previous == SessionStage.member ||
          previous == SessionStage.admin ||
          previous == SessionStage.guest)) {
    return previous;
  }
  return current;
}
