import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/models/user_account.dart';
import 'package:ota_cheshire_management_platform/routes.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_identity_contract.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_app_data_service.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/route_authorization.dart';
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
