import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/models/student.dart';
import 'package:ota_cheshire_management_platform/services/firebase/firebase_session_controller.dart';
import 'package:ota_cheshire_management_platform/services/firebase/linked_profile_reconciler.dart';

void main() {
  test(
    'cache partial snapshot preserves an established member session',
    () async {
      var serverLoads = 0;
      final result = await reconcileLinkedProfiles(
        expectedIds: const ['existing', 'new-child'],
        snapshotProfiles: const [_existingProfile],
        isFromCache: true,
        loadMissingFromServer: (_) async {
          serverLoads++;
          return const [];
        },
      );

      expect(result.status, LinkedProfileResolutionStatus.transitional);
      expect(result.missingIds, ['new-child']);
      expect(serverLoads, 0);
      expect(
        sessionStageDuringProfileReconciliation(
          current: SessionStage.member,
          hasEstablishedProfiles: true,
        ),
        SessionStage.member,
      );
    },
  );

  test(
    'server confirmation recovers a profile missing from the query',
    () async {
      var serverLoads = 0;
      final result = await reconcileLinkedProfiles(
        expectedIds: const ['existing', 'new-child'],
        snapshotProfiles: const [_existingProfile],
        isFromCache: false,
        loadMissingFromServer: (ids) async {
          serverLoads++;
          expect(ids, ['new-child']);
          return const [_newChildProfile];
        },
      );

      expect(serverLoads, 1);
      expect(result.status, LinkedProfileResolutionStatus.complete);
      expect(result.profiles.map((profile) => profile.id), [
        'existing',
        'new-child',
      ]);
    },
  );

  test(
    'persistent missing profile fails closed after one confirmation',
    () async {
      var serverLoads = 0;
      final result = await reconcileLinkedProfiles(
        expectedIds: const ['existing', 'missing'],
        snapshotProfiles: const [_existingProfile],
        isFromCache: false,
        loadMissingFromServer: (_) async {
          serverLoads++;
          return const [];
        },
      );

      expect(serverLoads, 1);
      expect(result.status, LinkedProfileResolutionStatus.missing);
      expect(result.missingIds, ['missing']);
    },
  );

  test('unreadable server confirmation fails closed', () async {
    final result = await reconcileLinkedProfiles(
      expectedIds: const ['existing', 'restricted'],
      snapshotProfiles: const [_existingProfile],
      isFromCache: false,
      loadMissingFromServer: (_) async => throw StateError('permission denied'),
    );

    expect(result.status, LinkedProfileResolutionStatus.unreadable);
    expect(result.missingIds, ['restricted']);
  });

  test('initial partial snapshot remains loading', () {
    expect(
      sessionStageDuringProfileReconciliation(
        current: SessionStage.loading,
        hasEstablishedProfiles: false,
      ),
      SessionStage.loading,
    );
  });

  test('unresolved pending account write retains the last valid account', () {
    expect(
      shouldRetainAccountForPendingSnapshot(
        hasPendingWrites: true,
        hasValidAccount: true,
      ),
      isTrue,
    );
    expect(
      shouldRetainAccountForPendingSnapshot(
        hasPendingWrites: false,
        hasValidAccount: true,
      ),
      isFalse,
    );
    expect(
      shouldRetainAccountForPendingSnapshot(
        hasPendingWrites: true,
        hasValidAccount: false,
      ),
      isFalse,
    );
    expect(
      shouldRetainAccountForPendingSnapshot(
        hasPendingWrites: true,
        hasValidAccount: false,
        profileCreationInProgress: true,
      ),
      isTrue,
    );
  });

  test('profile setup stays mounted while account creation is pending', () {
    expect(
      shouldHoldProfileSetupDuringCreation(
        creationInProgress: true,
        current: SessionStage.needsProfiles,
      ),
      isTrue,
    );
    expect(
      shouldHoldProfileSetupDuringCreation(
        creationInProgress: false,
        current: SessionStage.needsProfiles,
      ),
      isFalse,
    );
    expect(
      shouldHoldProfileSetupDuringCreation(
        creationInProgress: true,
        current: SessionStage.member,
      ),
      isFalse,
    );
  });
}

const _existingProfile = Student(
  id: 'existing',
  name: 'Existing Student',
  locationId: 'cheshire',
  belt: 'White',
  stickerCount: 0,
  stickersRequired: 4,
  nextRank: 'Yellow',
);

const _newChildProfile = Student(
  id: 'new-child',
  name: 'New Child',
  locationId: 'cheshire',
  belt: 'White',
  stickerCount: 0,
  stickersRequired: 4,
  nextRank: 'Yellow',
);
