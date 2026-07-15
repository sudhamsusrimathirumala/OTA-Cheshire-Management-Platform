import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {createProfiles, selectProfile} from './client_workflows.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-active-access';
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
      name: 'OTA Cheshire', isActive: true, timeZoneId: 'America/New_York',
      addressLine1: '136 Elm St', city: 'Cheshire', state: 'CT',
      postalCode: '06410', country: 'US',
    });
    await setDoc(doc(db, 'locations', 'other'), {
      name: 'Other', isActive: true, timeZoneId: 'America/Chicago',
    });
    await setDoc(doc(db, 'locations', 'inactive'), {
      name: 'Inactive', isActive: false, timeZoneId: 'America/New_York',
    });
  });
});

after(async () => env.cleanup());

function auth(uid, email = `${uid}@example.com`, claims = {}) {
  return env.authenticatedContext(uid, {email, ...claims}).firestore();
}

async function seedAccount({
  uid,
  role = 'parent',
  locationId = 'cheshire',
  isActive = true,
  profileIds = [`${uid}-profile`],
  selectedProfileId = profileIds[0],
  profileActive = true,
  profileLocationId = locationId,
}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid), {
      firstName: 'Account', lastName: uid, email: `${uid}@example.com`,
      role, isActive, locationId,
      linkedStudentProfileIds: profileIds,
      ...(selectedProfileId ? {selectedStudentProfileId: selectedProfileId} : {}),
      createdAt: new Date(), updatedAt: new Date(),
    });
    for (const profileId of profileIds) {
      await setDoc(doc(db, 'studentProfiles', profileId), {
        firstName: 'Student', lastName: profileId,
        dateOfBirth: new Date('2010-01-02T00:00:00Z'), beltRank: 'White',
        locationId: profileLocationId, guardianEmail: `${uid}@example.com`,
        guardianUserIds: [uid], preferredClassGroupIds: [],
        stickerProgress: {current: 0, required: 0, nextRank: 'Next rank'},
        promotionHistory: [], testingNotes: [], isActive: profileActive,
        createdAt: new Date(), updatedAt: new Date(),
      });
    }
  });
}

async function seedContent() {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const base = {locationId: 'cheshire', createdAt: new Date(), updatedAt: new Date()};
    await setDoc(doc(db, 'classSessions', 'active-class'), {...base, isActive: true});
    await setDoc(doc(db, 'classSessions', 'inactive-class'), {...base, isActive: false});
    await setDoc(doc(db, 'announcements', 'published'), {...base, status: 'published'});
    await setDoc(doc(db, 'announcements', 'draft'), {...base, status: 'draft'});
    await setDoc(doc(db, 'events', 'published'), {
      ...base, isPublished: true, isArchived: false,
    });
    await setDoc(doc(db, 'events', 'unpublished'), {
      ...base, isPublished: false, isArchived: false,
    });
    await setDoc(doc(db, 'resources', 'published'), {
      ...base, isPublished: true, isArchived: false,
    });
    await setDoc(doc(db, 'resources', 'archived'), {
      ...base, isPublished: true, isArchived: true,
    });
    await setDoc(doc(db, 'events', 'other-event'), {
      ...base, locationId: 'other', isPublished: true, isArchived: false,
    });
  });
}

test('authenticated user reads active locations before account setup', async () => {
  const db = auth('new-user');
  await assertSucceeds(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'locations', 'inactive')));
});

test('student atomically creates active records at one location', async () => {
  const db = auth('student', 'Student@Example.com');
  await assertSucceeds(createProfiles(db, {
    uid: 'student', email: 'student@example.com', profileIds: ['profile-1'],
  }));
  const user = (await getDoc(doc(db, 'users', 'student'))).data();
  const profile = (await getDoc(doc(db, 'studentProfiles', 'profile-1'))).data();
  assert.equal(user.locationId, 'cheshire');
  assert.equal(user.isActive, true);
  assert.equal(profile.locationId, 'cheshire');
  assert.equal(profile.isActive, true);
});

test('parent atomically creates one-location household profiles', async () => {
  const db = auth('parent');
  await assertSucceeds(createProfiles(db, {
    uid: 'parent', email: 'parent@example.com', role: 'parent',
    profileIds: ['child-1', 'child-2'],
  }));
  for (const id of ['child-1', 'child-2']) {
    const profile = (await getDoc(doc(db, 'studentProfiles', id))).data();
    assert.equal(profile.locationId, 'cheshire');
    assert.deepEqual(profile.guardianUserIds, ['parent']);
  }
});

test('account creation rejects partial, elevated, mismatched, and inactive-location writes', async () => {
  const db = auth('owner');
  await assertFails(setDoc(doc(db, 'users', 'owner'), {
    firstName: 'Bad', lastName: 'Write', email: 'owner@example.com',
    role: 'student', isActive: true, locationId: 'cheshire',
    linkedStudentProfileIds: ['missing'], selectedStudentProfileId: 'missing',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(createProfiles(db, {
    uid: 'other', email: 'owner@example.com', profileIds: ['other-profile'],
  }));
  await assertFails(createProfiles(db, {
    uid: 'owner', email: 'wrong@example.com', profileIds: ['wrong-profile'],
  }));
  await assertFails(createProfiles(db, {
    uid: 'owner', email: 'owner@example.com', role: 'admin',
    profileIds: ['admin-profile'],
  }));
  await assertFails(createProfiles(db, {
    uid: 'owner', email: 'owner@example.com', locationId: 'inactive',
    profileIds: ['inactive-profile'],
  }));
});

test('parent cannot claim another user profile or change ownership', async () => {
  await seedAccount({uid: 'owner'});
  await seedAccount({uid: 'other'});
  const db = auth('owner');
  await assertFails(selectProfile(db, 'owner', 'other-profile'));
  await assertFails(updateDoc(doc(db, 'studentProfiles', 'owner-profile'), {
    guardianUserIds: ['other'], updatedAt: serverTimestamp(),
  }));
});

test('active matching account reads only published student content', async () => {
  await seedAccount({uid: 'member'});
  await seedContent();
  const db = auth('member');
  await assertSucceeds(getDoc(doc(db, 'classSessions', 'active-class')));
  await assertSucceeds(getDoc(doc(db, 'announcements', 'published')));
  await assertSucceeds(getDoc(doc(db, 'events', 'published')));
  await assertSucceeds(getDoc(doc(db, 'resources', 'published')));
  await assertFails(getDoc(doc(db, 'classSessions', 'inactive-class')));
  await assertFails(getDoc(doc(db, 'announcements', 'draft')));
  await assertFails(getDoc(doc(db, 'events', 'unpublished')));
  await assertFails(getDoc(doc(db, 'resources', 'archived')));
  await assertFails(getDoc(doc(db, 'events', 'other-event')));

  await assertSucceeds(getDocs(query(
    collection(db, 'events'),
    where('locationId', '==', 'cheshire'),
    where('isPublished', '==', true),
    where('isArchived', '==', false),
  )));
});

test('signed-out, wrong-location, inactive account, and inactive profile are denied', async () => {
  await seedContent();
  await seedAccount({uid: 'wrong', locationId: 'other', profileLocationId: 'other'});
  await seedAccount({uid: 'disabled', isActive: false});
  await seedAccount({uid: 'inactive-profile', profileActive: false});
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'events', 'published')));
  await assertFails(getDoc(doc(auth('wrong'), 'events', 'published')));
  await assertFails(getDoc(doc(auth('disabled'), 'events', 'published')));
  await assertFails(getDoc(doc(auth('inactive-profile'), 'events', 'published')));
});

test('location admin reads and edits only assigned-location records', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  await seedAccount({uid: 'cheshire-parent'});
  await seedAccount({
    uid: 'other-parent', locationId: 'other', profileLocationId: 'other',
  });
  await seedContent();
  const db = auth('admin');
  await assertSucceeds(getDoc(doc(db, 'users', 'cheshire-parent')));
  await assertSucceeds(getDoc(doc(db, 'studentProfiles', 'cheshire-parent-profile')));
  await assertFails(getDoc(doc(db, 'users', 'other-parent')));
  await assertFails(getDoc(doc(db, 'studentProfiles', 'other-parent-profile')));
  await assertSucceeds(getDoc(doc(db, 'announcements', 'draft')));
  await assertSucceeds(updateDoc(doc(db, 'studentProfiles', 'cheshire-parent-profile'), {
    beltRank: 'Yellow', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'studentProfiles', 'cheshire-parent-profile'), {
    locationId: 'other', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users', 'cheshire-parent'), {
    role: 'admin', updatedAt: serverTimestamp(),
  }));
});

test('disabled admin and inactive assigned location are denied', async () => {
  await seedAccount({uid: 'disabled-admin', role: 'admin', isActive: false, profileIds: []});
  await seedAccount({
    uid: 'inactive-admin', role: 'admin', locationId: 'inactive', profileIds: [],
  });
  await seedAccount({uid: 'member'});
  await assertFails(getDoc(doc(auth('disabled-admin'), 'users', 'member')));
  await assertFails(getDoc(doc(auth('inactive-admin'), 'users', 'member')));
});
