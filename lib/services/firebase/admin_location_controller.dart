import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/academy_location.dart';
import '../../models/user_account.dart';
import '../debug_view_controller.dart';
import '../firestore/firestore_collections.dart';
import '../location_time_service.dart';
import 'firebase_identity_contract.dart';
import 'firebase_session_controller.dart';

enum AdminLocationAccess { none, locationAdmin, superAdmin, debugAdmin }

class AdminLocationController extends ChangeNotifier {
  AdminLocationController({
    required FirebaseSessionController this._session,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _testRole = null;

  AdminLocationController.forTesting({
    required UserAccountRole role,
    required List<AcademyLocation> locations,
    this._assignedLocationId,
  }) : _session = null,
       _firestore = null,
       _testRole = role,
       _locations = List.unmodifiable(locations);

  final FirebaseSessionController? _session;
  final FirebaseFirestore? _firestore;
  final UserAccountRole? _testRole;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _locationsSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _assignedLocationSubscription;
  List<AcademyLocation> _locations = const [];
  String? _assignedLocationId;
  String? _selectedLocationId;
  DebugViewMode _debugMode = DebugViewMode.none;
  int _generation = 0;
  bool _started = false;
  bool _pendingApplicationsPromptShown = false;
  AdminLocationAccess _listeningAccess = AdminLocationAccess.none;
  String? _listeningLocationId;

  static const debugLocation = AcademyLocation(
    id: LocationTimeService.otaCheshireLocationId,
    name: 'OTA Cheshire',
    timeZoneId: LocationTimeService.otaCheshireTimeZoneId,
    isActive: true,
    addressLine1: 'Development data',
  );

  AdminLocationAccess get access {
    if (kDebugMode && _debugMode == DebugViewMode.admin) {
      return AdminLocationAccess.debugAdmin;
    }
    final role = _testRole ?? _session?.account?.role;
    return switch (role) {
      UserAccountRole.superAdmin => AdminLocationAccess.superAdmin,
      UserAccountRole.admin => AdminLocationAccess.locationAdmin,
      _ => AdminLocationAccess.none,
    };
  }

  bool get isSuperAdmin => access == AdminLocationAccess.superAdmin;
  bool get isLocationAdmin => access == AdminLocationAccess.locationAdmin;
  bool get isDebugAdmin => access == AdminLocationAccess.debugAdmin;
  bool get pendingApplicationsPromptShown => _pendingApplicationsPromptShown;
  List<AcademyLocation> get locations => List.unmodifiable(_locations);
  List<AcademyLocation> get activeLocations =>
      List.unmodifiable(_locations.where((location) => location.isActive));
  Set<String> get activeLocationIds => {
    for (final location in activeLocations) location.id,
  };
  String? get selectedLocationId => isSuperAdmin ? _selectedLocationId : null;
  AcademyLocation? get selectedLocation => _locationById(selectedLocationId);
  AcademyLocation? get assignedLocation =>
      isDebugAdmin ? debugLocation : _locationById(_assignedLocationId);
  String get writeLocationId {
    if (isSuperAdmin) return selectedLocationId ?? '';
    return assignedLocation?.id ?? _assignedLocationId ?? '';
  }

  void start() {
    if (_started || _session == null) return;
    _started = true;
    _session.addListener(_handleSessionChanged);
    _handleSessionChanged();
  }

  void setDebugMode(DebugViewMode mode) {
    final effective = kDebugMode ? mode : DebugViewMode.none;
    if (_debugMode == effective) return;
    _debugMode = effective;
    if (effective == DebugViewMode.admin) {
      _cancelSubscriptions();
      _assignedLocationId = debugLocation.id;
      _locations = const [debugLocation];
      _selectedLocationId = null;
      notifyListeners();
      return;
    }
    _handleSessionChanged();
  }

  void selectLocation(String? locationId) {
    if (!isSuperAdmin) return;
    final next = locationId != null && activeLocationIds.contains(locationId)
        ? locationId
        : null;
    if (_selectedLocationId == next) return;
    _selectedLocationId = next;
    notifyListeners();
  }

  void clearSelection() => selectLocation(null);

  void markPendingApplicationsPromptShown() {
    _pendingApplicationsPromptShown = true;
  }

  @visibleForTesting
  void resetPendingApplicationsPrompt() {
    _pendingApplicationsPromptShown = false;
  }

  void clearForSignOut() => _reset();

  void replaceLocationsForTesting(List<AcademyLocation> locations) {
    assert(() {
      _applyLocations(locations);
      return true;
    }());
  }

  void _handleSessionChanged() {
    if (kDebugMode && _debugMode != DebugViewMode.none) return;
    final session = _session;
    if (session == null) return;
    if (session.authUser == null) {
      _pendingApplicationsPromptShown = false;
    }
    if (session.stage != SessionStage.admin) {
      _reset();
      return;
    }
    final account = session.account;
    if (account?.role == UserAccountRole.superAdmin) {
      _listenToAllLocations();
    } else if (account?.role == UserAccountRole.admin) {
      _listenToAssignedLocation(account!.locationId);
    } else {
      _reset();
    }
  }

  void _listenToAllLocations() {
    final firestore = _firestore;
    if (firestore == null) return;
    if (_listeningAccess == AdminLocationAccess.superAdmin &&
        _locationsSubscription != null) {
      return;
    }
    final generation = ++_generation;
    _cancelSubscriptions();
    _listeningAccess = AdminLocationAccess.superAdmin;
    _listeningLocationId = null;
    _assignedLocationId = null;
    _selectedLocationId = null;
    _locationsSubscription = firestore
        .collection(FirestoreCollections.locations)
        .snapshots()
        .listen((snapshot) {
          if (generation != _generation) return;
          final loaded = snapshot.docs.map((document) {
            return academyLocationFromFirestoreData(
              document.id,
              document.data(),
            );
          }).toList()..sort((a, b) => a.name.compareTo(b.name));
          _applyLocations(loaded);
        });
  }

  void _listenToAssignedLocation(String locationId) {
    final firestore = _firestore;
    if (firestore == null || locationId.trim().isEmpty) {
      _reset();
      return;
    }
    if (_listeningAccess == AdminLocationAccess.locationAdmin &&
        _listeningLocationId == locationId &&
        _assignedLocationSubscription != null) {
      return;
    }
    final generation = ++_generation;
    _cancelSubscriptions();
    _listeningAccess = AdminLocationAccess.locationAdmin;
    _listeningLocationId = locationId;
    _assignedLocationId = locationId;
    _selectedLocationId = null;
    _assignedLocationSubscription = firestore
        .collection(FirestoreCollections.locations)
        .doc(locationId)
        .snapshots()
        .listen((snapshot) {
          if (generation != _generation) return;
          final data = snapshot.data();
          _applyLocations(
            data == null
                ? const []
                : [academyLocationFromFirestoreData(snapshot.id, data)],
          );
        });
  }

  void _applyLocations(List<AcademyLocation> value) {
    _locations = List.unmodifiable(value);
    if (_selectedLocationId != null &&
        !activeLocationIds.contains(_selectedLocationId)) {
      _selectedLocationId = null;
    }
    notifyListeners();
  }

  AcademyLocation? _locationById(String? locationId) {
    if (locationId == null) return null;
    return _locations
        .where((location) => location.id == locationId)
        .firstOrNull;
  }

  void _reset() {
    ++_generation;
    _cancelSubscriptions();
    final changed =
        _locations.isNotEmpty ||
        _assignedLocationId != null ||
        _selectedLocationId != null;
    _locations = const [];
    _assignedLocationId = null;
    _selectedLocationId = null;
    _listeningAccess = AdminLocationAccess.none;
    _listeningLocationId = null;
    if (changed) notifyListeners();
  }

  void _cancelSubscriptions() {
    final locations = _locationsSubscription;
    final assigned = _assignedLocationSubscription;
    _locationsSubscription = null;
    _assignedLocationSubscription = null;
    unawaited(locations?.cancel());
    unawaited(assigned?.cancel());
  }

  @override
  void dispose() {
    _session?.removeListener(_handleSessionChanged);
    _cancelSubscriptions();
    super.dispose();
  }
}
