import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteField,
  deleteDoc,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-account-deletion';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {rules: fs.readFileSync('../../firestore.rules', 'utf8')},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'locations', 'cheshire'), {
      name: 'Cheshire', isActive: true, timeZoneId: 'America/New_York',
    });
    await setDoc(doc(db, 'locations', 'other'), {
      name: 'Other', isActive: true, timeZoneId: 'America/Chicago',
    });
    await setDoc(doc(db, 'users', 'parent'), account('parent', ['child'], 'cheshire'));
    await setDoc(doc(db, 'users', 'other-parent'), account('parent', ['other-child'], 'cheshire'));
    await setDoc(doc(db, 'users', 'cross-location'), account('student', ['cross-profile'], 'cheshire'));
    await setDoc(doc(db, 'users', 'inactive-parent'), {
      ...account('parent', ['inactive-child'], 'cheshire'), isActive: false,
    });
    await setDoc(doc(db, 'users', 'admin'), account('admin', [], 'cheshire'));
    await setDoc(doc(db, 'users', 'super-admin'), account('superAdmin', [], ''));
    await setDoc(doc(db, 'studentProfiles', 'child'), profile('cheshire', {
      guardianEmail: 'parent@example.com', guardianUserIds: ['parent'],
    }));
    await setDoc(doc(db, 'studentProfiles', 'other-child'), profile('cheshire', {
      guardianEmail: 'other@example.com', guardianUserIds: ['other-parent'],
    }));
    await setDoc(doc(db, 'studentProfiles', 'cross-profile'), profile('other', {
      guardianUserIds: [], linkedUserId: 'cross-location',
    }));
    await setDoc(doc(db, 'studentProfiles', 'inactive-child'), profile('cheshire', {
      guardianEmail: 'inactive-parent@example.com',
      guardianUserIds: ['inactive-parent'],
    }));
    await setDoc(doc(db, 'users', 'parent', 'notificationReads', 'notice'), {
      readAt: new Date(),
    });
    await setDoc(doc(
      db, 'users', 'inactive-parent', 'notificationReads', 'notice',
    ), {readAt: new Date()});
    await setDoc(doc(db, 'users', 'parent', 'pushDevices', 'install'), {
      fcmToken: 'test-token', platform: 'android', appEnvironment: 'dev',
      enabled: true, createdAt: new Date(), updatedAt: new Date(),
      lastSeenAt: new Date(),
    });
    await setDoc(doc(
      db, 'users', 'parent', 'announcementDeliveries', 'targeted',
    ), {announcementId: 'targeted'});
  });
});

after(async () => env.cleanup());

function account(role, linkedStudentProfileIds, locationId) {
  return {
    firstName: 'Account', lastName: 'Holder', email: 'member@example.com',
    role, isActive: true, locationId, linkedStudentProfileIds,
    ...(linkedStudentProfileIds.length
      ? {selectedStudentProfileId: linkedStudentProfileIds[0]}
      : {}),
    createdAt: new Date(), updatedAt: new Date(),
  };
}

function profile(locationId, relationship) {
  return {
    firstName: 'Linked', lastName: 'Student',
    dateOfBirth: new Date('2010-01-01'), beltRank: 'White', locationId,
    preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: new Date(), updatedAt: new Date(), ...relationship,
  };
}

function auth(uid) {
  return env.authenticatedContext(uid, {email: `${uid}@example.com`}).firestore();
}

async function startAccountDeletion(db, uid) {
  await updateDoc(doc(db, 'users', uid), {
    accountDeletionInProgress: true,
    updatedAt: serverTimestamp(),
  });
}

async function deleteLinkedProfile(db, uid, profileId) {
  const userRef = doc(db, 'users', uid);
  const profileRef = doc(db, 'studentProfiles', profileId);
  await runTransaction(db, async (transaction) => {
    const user = (await transaction.get(userRef)).data();
    await transaction.get(profileRef);
    const oldIds = user.linkedStudentProfileIds;
    const remainingIds = oldIds.filter((id) => id !== profileId);
    const selectedId = remainingIds.includes(user.selectedStudentProfileId)
      ? user.selectedStudentProfileId
      : remainingIds[0];
    transaction.update(userRef, {
      linkedStudentProfileIds: remainingIds,
      selectedStudentProfileId: selectedId ?? deleteField(),
      ...(user.parentSelfProfileId === profileId
        ? {parentSelfProfileId: ''}
        : {}),
      profileMutationId: profileId,
      updatedAt: serverTimestamp(),
    });
    transaction.delete(profileRef);
  });
}

async function deleteOwnAccount(db, uid, profileIds) {
  await startAccountDeletion(db, uid);
  for (const profileId of profileIds) {
    await deleteLinkedProfile(db, uid, profileId);
  }
  await deleteDoc(doc(db, 'users', uid));
}

test('member may delete private documents and their complete account', async () => {
  const db = auth('parent');
  await assertSucceeds(deleteDoc(doc(db, 'users', 'parent', 'notificationReads', 'notice')));
  await assertSucceeds(deleteDoc(doc(db, 'users', 'parent', 'pushDevices', 'install')));
  await assertSucceeds(deleteDoc(doc(
    db, 'users', 'parent', 'announcementDeliveries', 'targeted',
  )));
  await assertSucceeds(deleteOwnAccount(db, 'parent', ['child']));
  await assertSucceeds(getDoc(doc(db, 'users', 'parent')).then((value) => {
    if (value.exists()) throw new Error('user still exists');
  }));
});

test('inactive member may delete notification reads and complete deletion', async () => {
  const db = auth('inactive-parent');
  const readRef = doc(
    db, 'users', 'inactive-parent', 'notificationReads', 'notice',
  );
  await assertFails(getDoc(readRef));
  await assertFails(setDoc(readRef, {readAt: serverTimestamp()}));
  await assertFails(updateDoc(readRef, {readAt: serverTimestamp()}));
  await assertFails(deleteDoc(doc(
    auth('parent'), 'users', 'inactive-parent', 'notificationReads', 'notice',
  )));
  await assertSucceeds(deleteDoc(readRef));
  await assertSucceeds(deleteOwnAccount(
    db, 'inactive-parent', ['inactive-child'],
  ));
});

test('complete account deletion supports 9, 10, and 11 linked profiles', async () => {
  for (const count of [9, 10, 11]) {
    const uid = `family-${count}`;
    const profileIds = Array.from(
      {length: count},
      (_, index) => `${uid}-profile-${index}`,
    );
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users', uid), account('parent', profileIds, 'cheshire'));
      for (const profileId of profileIds) {
        await setDoc(doc(db, 'studentProfiles', profileId), profile('cheshire', {
          guardianEmail: `${uid}@example.com`, guardianUserIds: [uid],
        }));
      }
    });
    await assertSucceeds(deleteOwnAccount(auth(uid), uid, profileIds));
  }
});

test('linked profile cannot be deleted outside complete account deletion', async () => {
  await assertFails(deleteDoc(doc(auth('parent'), 'studentProfiles', 'child')));
});

test('member cannot delete only their user document', async () => {
  await assertFails(deleteDoc(doc(auth('parent'), 'users', 'parent')));
});

test('member cannot delete only some linked profiles and then their user', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'users', 'partial-family'),
      account('parent', ['partial-a', 'partial-b'], 'cheshire'),
    );
    for (const profileId of ['partial-a', 'partial-b']) {
      await setDoc(doc(db, 'studentProfiles', profileId), profile('cheshire', {
        guardianEmail: 'partial@example.com',
        guardianUserIds: ['partial-family'],
      }));
    }
  });
  const db = auth('partial-family');
  await assertSucceeds(startAccountDeletion(db, 'partial-family'));
  await assertSucceeds(deleteLinkedProfile(db, 'partial-family', 'partial-a'));
  await assertFails(deleteDoc(doc(db, 'users', 'partial-family')));
  await assertSucceeds(getDoc(doc(db, 'studentProfiles', 'partial-b')).then(
    (value) => {
      if (!value.exists()) throw new Error('remaining profile was deleted');
    },
  ));
});

test("member cannot include another user's profile in account deletion", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', 'parent'), {
      linkedStudentProfileIds: ['child', 'other-child'],
    });
  });
  await assertFails(deleteOwnAccount(
    auth('parent'),
    'parent',
    ['other-child', 'child'],
  ));
});

test('member cannot delete another account or its private documents', async () => {
  const db = auth('parent');
  await assertFails(deleteOwnAccount(db, 'other-parent', ['other-child']));
  await assertFails(deleteDoc(
    doc(db, 'users', 'other-parent', 'notificationReads', 'notice'),
  ));
});

test('admin and super-admin cannot delete their own account', async () => {
  await assertFails(deleteDoc(doc(auth('admin'), 'users', 'admin')));
  await assertFails(deleteDoc(
    doc(auth('super-admin'), 'users', 'super-admin'),
  ));
});

test('cross-location linked profile deletion is rejected', async () => {
  await assertFails(deleteOwnAccount(
    auth('cross-location'),
    'cross-location',
    ['cross-profile'],
  ));
});
