import 'app_data_service.dart';
import 'firebase/firebase_app_data_service.dart';
import 'mock_app_data_service.dart';

const bool useFirebase = true;

late AppDataService appDataService;

void initializeFirebaseAppDataService() {
  appDataService = FirebaseAppDataService();
}

void initializeMockAppDataServiceForTests() {
  assert(() {
    appDataService = const MockAppDataService();
    return true;
  }());
}

void setDevelopmentDataView(bool active) {
  final service = appDataService;
  if (service is FirebaseAppDataService) {
    service.setDevelopmentViewActive(active);
  }
}
