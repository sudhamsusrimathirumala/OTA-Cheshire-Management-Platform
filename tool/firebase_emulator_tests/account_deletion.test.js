import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  writeBatch,
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
    await setDoc(doc(db, 'users', 'parent', 'notificationReads', 'notice'), {
      readAt: new Date(),
    });
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

async function deleteOwnAccount(db, uid, profileIds) {
  const batch = writeBatch(db);
  for (const profileId of profileIds) {
    batch.delete(doc(db, 'studentProfiles', profileId));
  }
  batch.delete(doc(db, 'users', uid));
  await batch.commit();
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

test('member cannot include an unlinked profile in account deletion', async () => {
  await assertFails(deleteOwnAccount(
    auth('parent'),
    'parent',
    ['child', 'other-child'],
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
