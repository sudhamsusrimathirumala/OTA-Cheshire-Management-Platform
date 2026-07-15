import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/app_environment.dart';
import 'package:ota_cheshire_management_platform/firebase_options_dev.dart';
import 'package:ota_cheshire_management_platform/firebase_options_prod.dart';
import 'package:ota_cheshire_management_platform/main.dart' as default_entry;
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/academy_location.dart';
import 'package:ota_cheshire_management_platform/models/membership_application.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/screens/membership_status_screen.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_identity_contract.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/route_authorization.dart';
import 'package:ota_cheshire_management_platform/services/firebase/admin_location_controller.dart';
import 'package:ota_cheshire_management_platform/services/debug_view_controller.dart';
import 'package:ota_cheshire_management_platform/services/location_time_service.dart';

void main() {
  group('production route authorization', () {
    test('signed-out and incomplete sessions cannot open student content', () {
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.dashboard,
          stage: SessionStage.signedOut,
        ),
        isFalse,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.events,
          stage: SessionStage.incomplete,
        ),
        isFalse,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.resources,
          stage: SessionStage.pending,
        ),
        isFalse,
      );
    });

    test(
      'approved student and approved administrator get only their routes',
      () {
        expect(
          isRouteAuthorized(
            routeName: OtaRoutes.dashboard,
            stage: SessionStage.approved,
          ),
          isTrue,
        );
        expect(
          isRouteAuthorized(
            routeName: OtaRoutes.adminDashboard,
            stage: SessionStage.approved,
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
      },
    );

    test('sign-out and leaving a location invalidate protected stacks', () {
      expect(
        protectedAccessWasLost(SessionStage.approved, SessionStage.signedOut),
        isTrue,
      );
      expect(
        protectedAccessWasLost(SessionStage.approved, SessionStage.incomplete),
        isTrue,
      );
      expect(
        protectedAccessWasLost(SessionStage.admin, SessionStage.disabled),
        isTrue,
      );
    });
  });

  group('debug-view routing', () {
    test('student and admin sessions remain distinct', () {
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.schedule,
          stage: SessionStage.signedOut,
          debugMode: DebugViewMode.student,
        ),
        isTrue,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.adminSchedule,
          stage: SessionStage.signedOut,
          debugMode: DebugViewMode.student,
        ),
        isFalse,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.adminSchedule,
          stage: SessionStage.signedOut,
          debugMode: DebugViewMode.admin,
        ),
        isTrue,
      );
      expect(
        isRouteAuthorized(
          routeName: OtaRoutes.schedule,
          stage: SessionStage.signedOut,
          debugMode: DebugViewMode.admin,
        ),
        isFalse,
      );
    });

    test('release builds cannot activate a requested debug mode', () {
      expect(
        debugViewModeForBuild(
          debugBuild: false,
          requestedMode: DebugViewMode.student,
        ),
        DebugViewMode.none,
      );
      expect(
        debugViewModeForBuild(
          debugBuild: false,
          requestedMode: DebugViewMode.admin,
        ),
        DebugViewMode.none,
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
      expect(
        debugViewsAllowed(environment: AppEnvironment.prod, debugBuild: false),
        isFalse,
      );
    });
  });

  group('Firebase environment isolation', () {
    test('development options identify only the development project', () {
      expect(
        DevelopmentFirebaseOptions.android.projectId,
        'ota-management-platform',
      );
      expect(
        DevelopmentFirebaseOptions.android.appId,
        '1:835576059374:android:abd14d2a4564a748822aff',
      );
    });

    test(
      'production options fail closed until academy configuration exists',
      () {
        expect(
          () => ProductionFirebaseOptions.currentPlatform,
          throwsA(isA<StateError>()),
        );
      },
    );

    test('production entrypoint does not import development options', () {
      final source = File('lib/main_prod.dart').readAsStringSync();
      expect(source, isNot(contains('firebase_options_dev')));
      expect(source, isNot(contains('ota-management-platform')));
      expect(source, contains('firebase_options_prod.dart'));
    });

    test('default entrypoint cannot silently select development', () {
      expect(() => default_entry.main(), throwsUnsupportedError);
    });
  });

  group('admin location selection', () {
    const cheshire = AcademyLocation(
      id: 'cheshire',
      name: 'OTA Cheshire',
      timeZoneId: 'America/New_York',
      isActive: true,
    );
    const chicago = AcademyLocation(
      id: 'chicago',
      name: 'OTA Chicago',
      timeZoneId: 'America/Chicago',
      isActive: true,
    );
    const inactive = AcademyLocation(
      id: 'inactive',
      name: 'OTA Inactive',
      timeZoneId: 'America/New_York',
      isActive: false,
    );

    test(
      'Super Admin can select empty active locations but not inactive ones',
      () {
        final controller = AdminLocationController.forTesting(
          role: UserAccountRole.superAdmin,
          locations: const [cheshire, chicago, inactive],
        );
        addTearDown(controller.dispose);

        expect(controller.activeLocationIds, {'cheshire', 'chicago'});
        controller.selectLocation('chicago');
        expect(controller.writeLocationId, 'chicago');
        controller.selectLocation('inactive');
        expect(controller.selectedLocationId, isNull);
      },
    );

    test('deactivation clears only the selected inactive location', () {
      final controller = AdminLocationController.forTesting(
        role: UserAccountRole.superAdmin,
        locations: const [cheshire, chicago],
      );
      addTearDown(controller.dispose);
      controller.selectLocation('chicago');

      controller.replaceLocationsForTesting(const [cheshire, inactive]);

      expect(controller.selectedLocationId, isNull);
      expect(controller.activeLocationIds, {'cheshire'});
    });

    test(
      'location Admin cannot select another academy and sign-out clears selection',
      () {
        final locationAdmin = AdminLocationController.forTesting(
          role: UserAccountRole.admin,
          locations: const [cheshire, chicago],
          assignedLocationId: 'cheshire',
        );
        addTearDown(locationAdmin.dispose);
        locationAdmin.selectLocation('chicago');
        expect(locationAdmin.writeLocationId, 'cheshire');

        final superAdmin = AdminLocationController.forTesting(
          role: UserAccountRole.superAdmin,
          locations: const [cheshire, chicago],
        );
        addTearDown(superAdmin.dispose);
        superAdmin.selectLocation('chicago');
        superAdmin.clearForSignOut();
        expect(superAdmin.selectedLocationId, isNull);
        expect(superAdmin.locations, isEmpty);
      },
    );
  });

  test('active-location results merge and exclude inactive locations', () {
    expect(
      mergeActiveLocationRecords<String>(
        const {
          'cheshire': ['a', 'shared'],
          'chicago': ['b', 'shared'],
          'inactive': ['c'],
        },
        const {'cheshire', 'chicago'},
        idOf: (value) => value,
      ),
      ['a', 'shared', 'b'],
    );
  });

  group('multi-location dates', () {
    test('New York and Chicago use their own date at a UTC boundary', () {
      const service = LocationTimeService();
      service.cacheTimeZone('new-york', 'America/New_York');
      service.cacheTimeZone('chicago', 'America/Chicago');
      final instant = DateTime.utc(2026, 1, 1, 5, 30);

      expect(service.toLocationTime(instant, 'new-york').day, 1);
      expect(service.toLocationTime(instant, 'chicago').day, 31);

      expect(service.ageForStudent(_student('new-york'), instant: instant), 16);
      expect(service.ageForStudent(_student('chicago'), instant: instant), 15);
    });

    test('unknown real locations use neutral UTC instead of Eastern time', () {
      const service = LocationTimeService();
      expect(service.timeZoneIdFor('not-loaded'), 'UTC');
    });
  });

  group('location data scoping', () {
    test(
      'location admin stays scoped while super admin receives all locations',
      () {
        expect(
          recordIsInDataScope(
            stage: SessionStage.admin,
            role: UserAccountRole.admin,
            accountLocationId: 'new-york',
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
      },
    );

    test(
      'student data follows only the approved selected profile location',
      () {
        expect(
          recordIsInDataScope(
            stage: SessionStage.approved,
            role: UserAccountRole.parent,
            accountLocationId: 'new-york',
            selectedProfileLocationId: 'chicago',
            recordLocationId: 'chicago',
          ),
          isTrue,
        );
        expect(
          recordIsInDataScope(
            stage: SessionStage.approved,
            role: UserAccountRole.parent,
            accountLocationId: 'new-york',
            selectedProfileLocationId: 'chicago',
            recordLocationId: 'new-york',
          ),
          isFalse,
        );
      },
    );
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
    expect(
      firebaseIdentityOrDevelopmentFallback<String>(
        'firebase-user',
        developmentFallback: 'sample-user',
        developmentViewActive: false,
        identityName: 'account',
      ),
      'firebase-user',
    );
  });

  group('listener generation guards', () {
    test('ignores stale identities and disposed listeners', () {
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
      expect(
        listenerCallbackIsCurrent(
          disposed: true,
          callbackGeneration: 4,
          currentGeneration: 4,
          callbackIdentity: 'location-a',
          currentIdentity: 'location-a',
        ),
        isFalse,
      );
    });

    test('accepts only the current generation and identity', () {
      expect(
        listenerCallbackIsCurrent(
          disposed: false,
          callbackGeneration: 5,
          currentGeneration: 5,
          callbackIdentity: 'current-user',
          currentIdentity: 'current-user',
        ),
        isTrue,
      );
    });
  });

  group('optional profile location serialization', () {
    test('omits a blank location', () {
      final fields = studentProfileWriteFields(
        _student('', approvalStatus: StudentApprovalStatus.incomplete),
        now: DateTime.utc(2026, 7, 14),
        isCreate: true,
      );
      expect(fields, isNot(contains('locationId')));
    });

    test('includes a non-blank location', () {
      final fields = studentProfileWriteFields(
        _student('chicago', approvalStatus: StudentApprovalStatus.pending),
        now: DateTime.utc(2026, 7, 14),
      );
      expect(fields['locationId'], 'chicago');
    });
  });

  test('student membership routing is determined by profile status', () {
    expect(
      membershipStageForProfileStatus(StudentApprovalStatus.incomplete),
      SessionStage.incomplete,
    );
    expect(
      membershipStageForProfileStatus(StudentApprovalStatus.pending),
      SessionStage.pending,
    );
    expect(
      membershipStageForProfileStatus(StudentApprovalStatus.rejected),
      SessionStage.rejected,
    );
    expect(
      membershipStageForProfileStatus(StudentApprovalStatus.disabled),
      SessionStage.disabled,
    );
    expect(
      membershipStageForProfileStatus(StudentApprovalStatus.approved),
      SessionStage.loading,
    );
  });

  test('location selection uses optional formatted address data', () {
    const addressed = AcademyLocation(
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
    const nameOnly = AcademyLocation(
      id: 'other',
      name: 'Name only academy',
      timeZoneId: 'America/New_York',
      isActive: true,
    );

    expect(locationSelectionSubtitle(addressed), contains('136 Elm St'));
    expect(
      locationSelectionSubtitle(addressed),
      contains('Cheshire, CT 06410'),
    );
    expect(locationSelectionSubtitle(nameOnly), isNull);
  });

  test('membership profile selection permits only incomplete and rejected', () {
    final incomplete = _student(
      '',
      approvalStatus: StudentApprovalStatus.incomplete,
    );
    final rejected = _student(
      'cheshire',
      approvalStatus: StudentApprovalStatus.rejected,
    );
    final pending = _student(
      'cheshire',
      approvalStatus: StudentApprovalStatus.pending,
    );
    final approved = _student('cheshire');
    final disabled = _student(
      'cheshire',
      approvalStatus: StudentApprovalStatus.disabled,
    );

    expect(profileCanApply(incomplete), isTrue);
    expect(profileCanApply(rejected), isTrue);
    expect(profileCanApply(pending), isFalse);
    expect(profileCanApply(approved), isFalse);
    expect(profileCanApply(disabled), isFalse);
    expect(profileApplicationAvailability(pending), contains('awaiting'));
    expect(profileApplicationAvailability(approved), contains('approved'));
    expect(profileApplicationAvailability(disabled), contains('disabled'));
  });

  test('membership application parser accepts complete batch data', () {
    final application = membershipApplicationFromFirestoreData('application', {
      'applicantUserId': 'parent-1',
      'applicantSnapshot': {
        'firstName': 'Alex',
        'lastName': 'Parent',
        'email': 'parent@example.com',
        'role': 'parent',
      },
      'locationId': 'cheshire',
      'studentProfileIds': ['student-1', 'student-2'],
      'status': 'pending',
      'appliedAt': DateTime.utc(2026, 7, 15),
      'updatedAt': DateTime.utc(2026, 7, 15),
    });

    expect(application, isNotNull);
    expect(application!.applicant.displayName, 'Alex Parent');
    expect(application.studentProfileIds, ['student-1', 'student-2']);
    expect(application.status, MembershipApplicationStatus.pending);
  });

  test('membership application parser rejects malformed batch data', () {
    expect(
      membershipApplicationFromFirestoreData('application', {
        'applicantUserId': 'parent-1',
        'applicantSnapshot': {
          'firstName': 'Alex',
          'lastName': 'Parent',
          'email': 'parent@example.com',
          'role': 'parent',
        },
        'locationId': 'cheshire',
        'studentProfileIds': ['student-1', 'student-1'],
        'status': 'pending',
        'appliedAt': DateTime.utc(2026, 7, 15),
        'updatedAt': DateTime.utc(2026, 7, 15),
      }),
      isNull,
    );
  });
}

Student _student(
  String locationId, {
  StudentApprovalStatus approvalStatus = StudentApprovalStatus.approved,
}) {
  return Student(
    id: 'student-1',
    name: 'Test Student',
    canonicalFirstName: 'Test',
    canonicalLastName: 'Student',
    locationId: locationId,
    belt: 'White',
    canonicalBeltRank: 'White',
    dateOfBirth: DateTime(2010, 1, 1),
    guardianEmail: 'guardian@example.com',
    approvalStatus: approvalStatus,
    stickerCount: 0,
    stickersRequired: 10,
    nextRank: 'Yellow',
  );
}
