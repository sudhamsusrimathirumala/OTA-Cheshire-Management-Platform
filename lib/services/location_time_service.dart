import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/academy_location.dart';
import '../models/student_profile.dart';
import 'firestore/firestore_collections.dart';

class LocationTimeService {
  const LocationTimeService();

  static const otaCheshireLocationId = 'ota-cheshire';
  static const otaCheshireTimeZoneId = 'America/New_York';
  static const neutralTimeZoneId = 'UTC';

  static bool _isInitialized = false;
  static final Map<String, String> _timeZoneIds = {
    otaCheshireLocationId: otaCheshireTimeZoneId,
  };

  static void initialize() {
    if (_isInitialized) return;
    tz_data.initializeTimeZones();
    _isInitialized = true;
  }

  String timeZoneIdFor(String locationId) {
    return _timeZoneIds[locationId] ?? neutralTimeZoneId;
  }

  void cacheTimeZone(String locationId, String timeZoneId) {
    initialize();
    if (locationId.trim().isEmpty) return;
    tz.getLocation(timeZoneId);
    _timeZoneIds[locationId] = timeZoneId;
  }

  Future<AcademyLocation> loadLocation(
    FirebaseFirestore firestore,
    String locationId,
  ) async {
    initialize();
    try {
      final snapshot = await firestore
          .collection(FirestoreCollections.locations)
          .doc(locationId)
          .get();
      final data = snapshot.data();
      final timeZoneId = data?['timeZoneId'];
      final name = data?['name'];
      final isActive = data?['isActive'];
      if (timeZoneId is String && timeZoneId.trim().isNotEmpty) {
        // Validate the IANA identifier before it becomes active.
        tz.getLocation(timeZoneId);
        _timeZoneIds[locationId] = timeZoneId;
      }
      return AcademyLocation(
        id: locationId,
        name: name is String && name.isNotEmpty ? name : 'Academy location',
        timeZoneId: timeZoneIdFor(locationId),
        isActive: isActive is bool ? isActive : true,
        addressLine1: _stringValue(data?['addressLine1']),
        addressLine2: _stringValue(data?['addressLine2']),
        city: _stringValue(data?['city']),
        state: _stringValue(data?['state']),
        postalCode: _stringValue(data?['postalCode']),
        country: _stringValue(data?['country']),
        createdAt: _dateTimeValue(data?['createdAt']),
        updatedAt: _dateTimeValue(data?['updatedAt']),
      );
    } catch (_) {
      return AcademyLocation(
        id: locationId,
        name: 'Academy location',
        timeZoneId: timeZoneIdFor(locationId),
        isActive: true,
      );
    }
  }

  tz.Location locationFor(String locationId) {
    initialize();
    return tz.getLocation(timeZoneIdFor(locationId));
  }

  DateTime combineDateAndTime({
    required String locationId,
    required DateTime date,
    required TimeOfDay time,
  }) {
    final local = tz.TZDateTime(
      locationFor(locationId),
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return local.toUtc();
  }

  tz.TZDateTime toLocationTime(DateTime instant, String locationId) {
    return tz.TZDateTime.from(instant.toUtc(), locationFor(locationId));
  }

  String displayLabelFor(String locationId, {DateTime? instant}) {
    final local = toLocationTime(instant ?? DateTime.now(), locationId);
    return local.timeZoneName;
  }

  String friendlyTimeZoneLabelFor(String locationId) {
    return switch (timeZoneIdFor(locationId)) {
      otaCheshireTimeZoneId => 'Eastern Time',
      final id => id,
    };
  }

  int ageForStudent(StudentProfile student, {DateTime? instant}) {
    if (student.locationId.trim().isEmpty) {
      return student.ageOn((instant ?? DateTime.now()).toLocal());
    }
    final academyDate = toLocationTime(
      instant ?? DateTime.now(),
      student.locationId,
    );
    return student.ageOn(academyDate);
  }

  String formatDateTime(DateTime instant, String locationId) {
    final local = toLocationTime(instant, locationId);
    final month = _monthNames[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month ${local.day}, ${local.year} at $hour:$minute $period ${local.timeZoneName}';
  }
}

String? _stringValue(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateTimeValue(Object? value) {
  return switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    _ => null,
  };
}

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
