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

late AppDataService appDataService;
late FirebaseAppDataService _firebaseAppDataService;
late GuestDemoAppDataService guestDemoAppDataService;
late AdminLocationController adminLocationController;
bool _guestDemoActive = false;

bool get isGuestDemoActive => _guestDemoActive;

AdminWriteService get adminWriteService =>
    _guestDemoActive ? guestDemoAppDataService : FirebaseAdminWriteService();

void initializeFirebaseAppDataService() {
  adminLocationController = AdminLocationController(
    session: firebaseSessionController,
  )..start();
  _firebaseAppDataService = FirebaseAppDataService(
    adminLocations: adminLocationController,
  );
  guestDemoAppDataService = GuestDemoAppDataService();
  appDataService = _firebaseAppDataService;
}

void setGuestDemoActive(bool active, {bool reset = false}) {
  if (active && reset) guestDemoAppDataService.reset();
  _guestDemoActive = active;
  appDataService = active ? guestDemoAppDataService : _firebaseAppDataService;
  adminLocationController.setGuestDemoActive(active);
}

void initializeMockAppDataServiceForTests() {
  assert(() {
    appDataService = MockAppDataService();
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
    guestExperienceController.reset();
    guestDemoAppDataService = GuestDemoAppDataService();
    appDataService = guestDemoAppDataService;
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
