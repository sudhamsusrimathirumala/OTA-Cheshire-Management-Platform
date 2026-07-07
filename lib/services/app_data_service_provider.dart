import 'app_data_service.dart';
import 'firebase/firebase_app_data_service.dart';
import 'mock_app_data_service.dart';

const bool useFirebase = false;

final AppDataService appDataService = useFirebase
    ? FirebaseAppDataService()
    : const MockAppDataService();
