import 'app_data_service.dart';
import '../models/user_account.dart';
import 'debug_view_controller.dart';
import 'firebase/admin_location_controller.dart';
import 'firebase/firebase_app_data_service.dart';
import 'firebase/firebase_session_controller.dart';
import 'mock_app_data_service.dart';

const bool useFirebase = true;

late AppDataService appDataService;
late AdminLocationController adminLocationController;

void initializeFirebaseAppDataService() {
  adminLocationController = AdminLocationController(
    session: firebaseSessionController,
  )..start();
  appDataService = FirebaseAppDataService(
    adminLocations: adminLocationController,
  );
}

void initializeMockAppDataServiceForTests() {
  assert(() {
    appDataService = MockAppDataService();
    adminLocationController = AdminLocationController.forTesting(
      role: UserAccountRole.admin,
      locations: const [AdminLocationController.debugLocation],
      assignedLocationId: AdminLocationController.debugLocation.id,
    );
    debugViewController.clear();
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
