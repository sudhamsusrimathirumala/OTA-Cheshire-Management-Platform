import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/app_environment.dart';
import 'package:ota_cheshire_management_platform/firebase_options_dev.dart';
import 'package:ota_cheshire_management_platform/firebase_options_prod.dart';
import 'package:ota_cheshire_management_platform/main.dart' as default_entry;
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/services/debug_view_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/route_authorization.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';

void main() {
  group('active access route authorization', () {
    test('signed-out and disabled sessions cannot open student content', () {
      for (final stage in [
        SessionStage.signedOut,
        SessionStage.needsProfiles,
        SessionStage.disabled,
        SessionStage.error,
      ]) {
        expect(
          isRouteAuthorized(routeName: OtaRoutes.dashboard, stage: stage),
          isFalse,
        );
      }
    });

    test('member and administrator get only their protected routes', () {
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.dashboard,
          stage: SessionStage.member,
        ),
        isTrue,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.adminDashboard,
          stage: SessionStage.member,
        ),
        isFalse,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.adminDashboard,
          stage: SessionStage.admin,
        ),
        isTrue,
      );
    });

    test('losing active access invalidates protected stacks', () {
      expect(
        protectedAccessWasLost(SessionStage.member, SessionStage.signedOut),
        isTrue,
      );
      expect(
        protectedAccessWasLost(SessionStage.member, SessionStage.disabled),
        isTrue,
      );
      expect(
        protectedAccessWasLost(SessionStage.admin, SessionStage.adminDisabled),
        isTrue,
      );
    });
  });

  group('active academy access', () {
    test('valid active account and selected profile grant access', () {
      expect(
        hasActiveAcademyAccessFor(
          account: _account(),
          selectedProfile: _student(),
          locationActive: true,
        ),
        isTrue,
      );
    });

    test('profile switching preserves access within the account location', () {
      final account = _account(
        linkedIds: const ['student-1', 'student-2'],
        selectedId: 'student-2',
      );
      expect(
        hasActiveAcademyAccessFor(
          account: account,
          selectedProfile: _student(id: 'student-2'),
          locationActive: true,
        ),
        isTrue,
      );
    });

    test('inactive or mismatched records fail closed', () {
      final cases = <({UserAccount account, Student profile, bool location})>[
        (
          account: _account(isActive: false),
          profile: _student(),
          location: true,
        ),
        (
          account: _account(),
          profile: _student(isActive: false),
          location: true,
        ),
        (account: _account(), profile: _student(), location: false),
        (
          account: _account(),
          profile: _student(locationId: 'other'),
          location: true,
        ),
        (
          account: _account(selectedId: 'other'),
          profile: _student(),
          location: true,
        ),
      ];
      for (final value in cases) {
        expect(
          hasActiveAcademyAccessFor(
            account: value.account,
            selectedProfile: value.profile,
            locationActive: value.location,
          ),
          isFalse,
        );
      }
      expect(
        hasActiveAcademyAccessFor(
          account: null,
          selectedProfile: _student(),
          locationActive: true,
        ),
        isFalse,
      );
    });
  });

  group('administrator access', () {
    test('active location administrator reaches the admin dashboard', () {
      expect(
        adminAccessStageFor(
          account: _account(role: UserAccountRole.admin),
          locationActive: true,
        ),
        SessionStage.admin,
      );
    });

    test('disabled administrator and inactive location are blocked', () {
      expect(
        adminAccessStageFor(
          account: _account(role: UserAccountRole.admin, isActive: false),
          locationActive: true,
        ),
        SessionStage.adminDisabled,
      );
      expect(
        adminAccessStageFor(
          account: _account(role: UserAccountRole.admin),
          locationActive: false,
        ),
        SessionStage.adminDisabled,
      );
    });

    test('Super Admin remains active without one assigned location', () {
      expect(
        adminAccessStageFor(
          account: _account(role: UserAccountRole.superAdmin, locationId: ''),
        ),
        SessionStage.admin,
      );
    });
  });

  group('debug-view and Firebase environment isolation', () {
    test('debug views require both dev environment and debug build', () {
      expect(
        debugViewsAllowed(environment: AppEnvironment.dev, debugBuild: true),
        isTrue,
      );
      expect(
        debugViewsAllowed(environment: AppEnvironment.dev, debugBuild: false),
        isFalse,
      );
      expect(
        debugViewsAllowed(environment: AppEnvironment.prod, debugBuild: true),
        isFalse,
      );
    });

    test('production environment cannot activate the debug controller', () {
      AppEnvironmentConfig.initialize(AppEnvironment.prod);
      addTearDown(() {
        debugViewController.clear();
        AppEnvironmentConfig.initialize(AppEnvironment.dev);
      });
      debugViewController.enterStudent();
      expect(debugViewController.mode, DebugViewMode.none);
    });

    test('development options identify only the development project', () {
      expect(
        DevelopmentFirebaseOptions.android.projectId,
        'ota-management-platform',
      );
    });

    test('production configuration and entrypoints fail closed', () {
      expect(
        () => ProductionFirebaseOptions.currentPlatform,
        throwsA(isA<StateError>()),
      );
      final source = File('lib/main_prod.dart').readAsStringSync();
      expect(source, isNot(contains('firebase_options_dev')));
      expect(source, isNot(contains('ota-management-platform')));
      expect(() => default_entry.main(), throwsUnsupportedError);
    });
  });

  group('location scoping and time', () {
    const cheshire = AcademyLocation(
      id: 'cheshire',
      name: 'OTA Cheshire',
      timeZoneId: 'America/New_York',
      isActive: true,
      addressLine1: '136 Elm St',
      city: 'Cheshire',
      state: 'CT',
      postalCode: '06410',
      country: 'US',
    );
    const chicago = AcademyLocation(
      id: 'chicago',
      name: 'OTA Chicago',
      timeZoneId: 'America/Chicago',
      isActive: true,
    );

    test('location admin stays scoped while Super Admin spans locations', () {
      expect(
        recordIsInDataScope(
          stage: SessionStage.admin,
          role: UserAccountRole.admin,
          accountLocationId: 'cheshire',
          selectedProfileLocationId: null,
          recordLocationId: 'chicago',
        ),
        isFalse,
      );
      expect(
        recordIsInDataScope(
          stage: SessionStage.admin,
          role: UserAccountRole.superAdmin,
          accountLocationId: '',
          selectedProfileLocationId: null,
          recordLocationId: 'chicago',
        ),
        isTrue,
      );
    });

    test('student data follows only the active selected profile location', () {
      expect(
        recordIsInDataScope(
          stage: SessionStage.member,
          role: UserAccountRole.parent,
          accountLocationId: 'cheshire',
          selectedProfileLocationId: 'cheshire',
          recordLocationId: 'cheshire',
        ),
        isTrue,
      );
      expect(
        recordIsInDataScope(
          stage: SessionStage.member,
          role: UserAccountRole.parent,
          accountLocationId: 'cheshire',
          selectedProfileLocationId: 'cheshire',
          recordLocationId: 'chicago',
        ),
        isFalse,
      );
    });

    test('location selection uses the available formatted address', () {
      expect(cheshire.formattedAddress, contains('136 Elm St'));
      expect(chicago.formattedAddress, isEmpty);
    });

    test('academy local dates respect UTC boundaries', () {
      const service = LocationTimeService();
      service.cacheTimeZone('new-york', 'America/New_York');
      service.cacheTimeZone('chicago', 'America/Chicago');
      final instant = DateTime.utc(2026, 1, 1, 5, 30);
      expect(service.toLocationTime(instant, 'new-york').day, 1);
      expect(service.toLocationTime(instant, 'chicago').day, 31);
    });
  });

  test('normal Firebase mode never substitutes mock identity', () {
    expect(
      () => firebaseIdentityOrDevelopmentFallback<String>(
        null,
        developmentFallback: 'sample-user',
        developmentViewActive: false,
        identityName: 'account',
      ),
      throwsStateError,
    );
  });

  test('profile parser requires location and boolean active state', () {
    final valid = studentProfileFromFirestoreData('student-1', {
      'firstName': 'Test',
      'lastName': 'Student',
      'locationId': 'cheshire',
      'beltRank': 'White',
      'dateOfBirth': DateTime.utc(2010, 1, 1),
      'isActive': true,
    });
    expect(valid, isNotNull);
    expect(valid!.isActive, isTrue);
    expect(
      studentProfileFromFirestoreData('student-1', {
        'firstName': 'Test',
        'lastName': 'Student',
        'beltRank': 'White',
        'dateOfBirth': DateTime.utc(2010, 1, 1),
        'isActive': true,
      }),
      isNull,
    );
    expect(
      studentProfileFromFirestoreData('student-1', {
        'firstName': 'Test',
        'lastName': 'Student',
        'locationId': 'cheshire',
        'beltRank': 'White',
        'dateOfBirth': DateTime.utc(2010, 1, 1),
      }),
      isNull,
    );
  });

  test('listener callbacks reject stale identities', () {
    expect(
      listenerCallbackIsCurrent(
        disposed: false,
        callbackGeneration: 3,
        currentGeneration: 4,
        callbackIdentity: 'old-profile',
        currentIdentity: 'new-profile',
      ),
      isFalse,
    );
  });
}

UserAccount _account({
  UserAccountRole role = UserAccountRole.parent,
  bool isActive = true,
  String locationId = 'cheshire',
  List<String> linkedIds = const ['student-1'],
  String selectedId = 'student-1',
}) => UserAccount(
  id: 'user-1',
  firstName: 'Account',
  lastName: 'Holder',
  email: 'account@example.com',
  role: role,
  isActive: isActive,
  locationId: locationId,
  linkedStudentProfileIds: linkedIds,
  selectedStudentProfileId: selectedId,
);

Student _student({
  String id = 'student-1',
  String locationId = 'cheshire',
  bool isActive = true,
}) => Student(
  id: id,
  name: 'Test Student',
  locationId: locationId,
  belt: 'White',
  dateOfBirth: DateTime(2010, 1, 1),
  stickerCount: 0,
  stickersRequired: 10,
  nextRank: 'Yellow',
  isActive: isActive,
);
