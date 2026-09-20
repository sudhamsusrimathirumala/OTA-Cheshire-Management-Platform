import 'package:flutter/foundation.dart';

import 'app_data_service.dart';
import '../models/user_account.dart';
import 'debug_view_controller.dart';
import 'firebase/admin_location_controller.dart';
import 'firebase/firebase_app_data_service.dart';
import 'firebase/firebase_session_controller.dart';
import 'firebase/firebase_admin_write_service.dart';
import 'guest/guest_demo_app_data_service.dart';
import 'guest/guest_experience_controller.dart';
import 'mock_app_data_service.dart';

const bool useFirebase = true;

late AppDataService _standardAppDataService;
late FirebaseAppDataService _firebaseAppDataService;
late GuestDemoAppDataService guestDemoAppDataService;
late AdminLocationController adminLocationController;
bool _guestDemoActive = false;
SessionStage Function()? _sessionStageReader;

bool get isGuestDemoActive =>
    _guestDemoActive || _sessionStageReader?.call() == SessionStage.guest;

AppDataService get appDataService =>
    isGuestDemoActive ? guestDemoAppDataService : _standardAppDataService;

@visibleForTesting
set appDataService(AppDataService value) => _standardAppDataService = value;

AdminWriteService get adminWriteService =>
    isGuestDemoActive ? guestDemoAppDataService : FirebaseAdminWriteService();

void initializeFirebaseAppDataService() {
  _sessionStageReader = () => firebaseSessionController.stage;
  adminLocationController = AdminLocationController(
    session: firebaseSessionController,
  )..start();
  _firebaseAppDataService = FirebaseAppDataService(
    adminLocations: adminLocationController,
  );
  guestDemoAppDataService = GuestDemoAppDataService();
  _standardAppDataService = _firebaseAppDataService;
}

void setGuestDemoActive(bool active, {bool reset = false}) {
  if (active && reset) guestDemoAppDataService.reset();
  _guestDemoActive = active;
  adminLocationController.setGuestDemoActive(active);
}

void initializeMockAppDataServiceForTests() {
  assert(() {
    _sessionStageReader = null;
    _standardAppDataService = MockAppDataService();
    _guestDemoActive = false;
    adminLocationController = AdminLocationController.forTesting(
      role: UserAccountRole.admin,
      locations: const [AdminLocationController.debugLocation],
      assignedLocationId: AdminLocationController.debugLocation.id,
    );
    debugViewController.clear();
    return true;
  }());
}

void initializeGuestDemoAppDataServiceForTests() {
  assert(() {
    _sessionStageReader = () => SessionStage.guest;
    guestExperienceController.reset();
    guestDemoAppDataService = GuestDemoAppDataService();
    _standardAppDataService = guestDemoAppDataService;
    adminLocationController = AdminLocationController.forTesting(
      role: UserAccountRole.guest,
      locations: const [AdminLocationController.guestDemoLocation],
      assignedLocationId: AdminLocationController.guestDemoLocation.id,
    )..setGuestDemoActive(true);
    _guestDemoActive = true;
    return true;
  }());
}

void setDevelopmentDataView(DebugViewMode mode) {
  adminLocationController.setDebugMode(mode);
  final service = appDataService;
  if (service is FirebaseAppDataService) {
    service.setDevelopmentViewMode(mode);
  }
}
