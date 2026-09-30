import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';

void main() {
  test('same-scope member changes preserve the existing listener set', () {
    expect(
      shouldRestartAppDataListeners(
        currentLocationId: 'academy',
        currentSuperAdmin: false,
        nextLocationId: 'academy',
        nextSuperAdmin: false,
      ),
      isFalse,
    );
    expect(
      shouldRestartAppDataListeners(
        currentLocationId: 'academy',
        currentSuperAdmin: false,
        nextLocationId: 'second-academy',
        nextSuperAdmin: false,
      ),
      isTrue,
    );
  });

  test('required session and content sources remain snapshot listeners', () {
    final session = File(
      'lib/services/firebase/firebase_session_controller.dart',
    ).readAsStringSync();
    final appData = File(
      'lib/services/firebase/firebase_app_data_service.dart',
    ).readAsStringSync();

    for (final collection in ['users', 'studentProfiles', 'locations']) {
      expect(
        session,
        contains('FirestoreCollections.$collection'),
        reason: '$collection must stay in the realtime session graph',
      );
    }
    expect(
      RegExp(r'\.snapshots\(').allMatches(session).length,
      greaterThanOrEqualTo(3),
    );

    for (final collection in [
      'classSessions',
      'announcements',
      'events',
      'resources',
      'studentProfiles',
      'users',
    ]) {
      final listener = RegExp(
        'FirestoreCollections\\.$collection[\\s\\S]{0,500}?\\.snapshots\\(',
      );
      expect(
        listener.hasMatch(appData),
        isTrue,
        reason: '$collection must remain realtime',
      );
    }
  });

  test('profile creation no longer replaces the authenticated session', () {
    final source = File(
      'lib/services/firebase/firebase_session_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> createProfiles(');
    final end = source.indexOf('void dismissCreatedConfirmation()', start);
    final createProfilesBody = source.substring(start, end);

    expect(createProfilesBody, isNot(contains('_replaceAuthUser(')));
    expect(createProfilesBody, contains('_waitForProfileCreationTransition'));
    expect(createProfilesBody, contains('_resumeProfileTransitionAfterWrite'));
  });
}
