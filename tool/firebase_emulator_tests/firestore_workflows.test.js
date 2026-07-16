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
  deleteDoc,
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
import {
  createProfiles,
  markNotificationRead,
  selectProfile,
  updateManagedProfile,
  updatePreferredClass,
} from './client_workflows.js';

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
  selfManaged = role === 'student',
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
        locationId: profileLocationId,
        ...(selfManaged ? {linkedUserId: uid} : {guardianEmail: `${uid}@example.com`}),
        guardianUserIds: selfManaged ? [] : [uid], preferredClassGroupIds: [],
        stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
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

test('self-managed student may omit guardian email without creating access', async () => {
  const uid = 'self-managed';
  const db = auth(uid);
  await assertSucceeds(createProfiles(db, {
    uid, email: `${uid}@example.com`, profileIds: ['self-profile'],
    omitGuardianEmail: true,
  }));
  const profile = (await getDoc(doc(db, 'studentProfiles', 'self-profile'))).data();
  assert.equal(profile.guardianEmail, undefined);
  assert.deepEqual(profile.guardianUserIds, []);
  assert.equal(profile.linkedUserId, uid);
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

test('managed profile edits allow canonical fields and reject escalation', async () => {
  await seedAccount({uid: 'parent'});
  await seedAccount({uid: 'other'});
  const db = auth('parent');
  const profileRef = doc(db, 'studentProfiles', 'parent-profile');
  await assertSucceeds(updateDoc(profileRef, {
    firstName: 'Updated', beltRank: 'Yellow',
    stickerProgress: {current: 7, required: 3, nextRank: 'Yellow-Green'},
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updatePreferredClass(
    db, 'parent-profile', 'level-2-standard',
  ));
  await assertSucceeds(updateDoc(doc(db, 'users', 'parent'), {
    firstName: 'Updated', phoneNumber: '555-0100',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    locationId: 'other', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    guardianUserIds: ['other'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    isActive: false, updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    promotionHistory: ['unauthorized'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(auth('other'), 'studentProfiles', 'parent-profile'), {
    preferredClassGroupIds: ['other-group'], updatedAt: serverTimestamp(),
  }));
});

test('parent edits selected and nonselected linked profiles through exact relationships', async () => {
  await seedAccount({
    uid: 'parent',
    profileIds: ['selected-child', 'other-child'],
    selectedProfileId: 'selected-child',
  });
  const db = auth('parent');
  await assertSucceeds(updateManagedProfile(db, 'selected-child'));
  await assertSucceeds(updateManagedProfile(db, 'other-child', {
    firstName: 'Other', guardianEmail: 'guardian@example.com',
    beltRank: 'Blue',
    stickerProgress: {current: 4, required: 5, nextRank: 'Blue-Red'},
  }));

  const other = (await getDoc(doc(db, 'studentProfiles', 'other-child'))).data();
  assert.equal(other.firstName, 'Other');
  assert.equal(other.guardianEmail, 'guardian@example.com');
  assert.equal(other.beltRank, 'Blue');
  assert.deepEqual(other.stickerProgress, {
    current: 4, required: 5, nextRank: 'Blue-Red',
  });
});

test('parent edits a linked self profile but invalid management is denied', async () => {
  await seedAccount({uid: 'parent-self', selfManaged: true});
  await assertSucceeds(updateManagedProfile(
    auth('parent-self'), 'parent-self-profile', {guardianEmail: 'self@example.com'},
  ));

  await seedAccount({uid: 'other-parent'});
  await assertFails(updateManagedProfile(
    auth('other-parent'), 'parent-self-profile', {guardianEmail: 'other@example.com'},
  ));

  await seedAccount({uid: 'wrong-location-edit', profileLocationId: 'other'});
  await assertFails(updateManagedProfile(
    auth('wrong-location-edit'), 'wrong-location-edit-profile',
  ));
  await seedAccount({uid: 'inactive-edit', profileActive: false});
  await assertFails(updateManagedProfile(
    auth('inactive-edit'), 'inactive-edit-profile',
  ));

  const selfRef = doc(auth('parent-self'), 'studentProfiles', 'parent-self-profile');
  await assertFails(updateDoc(selfRef, {
    linkedUserId: 'other-parent', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(selfRef, {
    isActive: false, updatedAt: serverTimestamp(),
  }));
});

test('unchanged legacy profile fields do not block a supported edit', async () => {
  await seedAccount({uid: 'legacy-parent'});
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'legacy-parent-profile'),
      {
        preferredClassGroupIds: 'legacy-group',
        promotionHistory: 'legacy-history',
        testingNotes: null,
        stickerProgress: {current: 0, required: 0, nextRank: 'Legacy rank'},
      },
    );
  });
  await assertSucceeds(updateDoc(
    doc(auth('legacy-parent'), 'studentProfiles', 'legacy-parent-profile'),
    {firstName: 'Legacy Updated', updatedAt: serverTimestamp()},
  ));
});

test('preference-only updates accept legacy profile data and reject other changes', async () => {
  await seedAccount({uid: 'parent'});
  await seedAccount({uid: 'other'});
  const db = auth('parent');
  const profileRef = doc(db, 'studentProfiles', 'parent-profile');
  await assertSucceeds(updatePreferredClass(db, 'parent-profile', 'level-4-standard'));
  await assertSucceeds(updatePreferredClass(db, 'parent-profile', null));

  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'parent-profile'),
      {stickerProgress: {current: 0, required: 0, nextRank: 'Legacy rank'}},
    );
  });
  await assertSucceeds(updatePreferredClass(db, 'parent-profile', 'level-2-standard'));
  await assertFails(updateDoc(profileRef, {
    preferredClassGroupIds: ['level-3-standard'], beltRank: 'Yellow',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    preferredClassGroupIds: ['level-3-standard'],
    stickerProgress: {current: 1, required: 1, nextRank: 'White-Yellow'},
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    preferredClassGroupIds: ['level-3-standard'], guardianUserIds: ['other'],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updatePreferredClass(
    auth('other'), 'parent-profile', 'level-3-standard',
  ));

  await seedAccount({uid: 'disabled-preference', isActive: false});
  await assertFails(updatePreferredClass(
    auth('disabled-preference'), 'disabled-preference-profile', 'level-1-standard',
  ));
  await seedAccount({uid: 'inactive-preference', profileActive: false});
  await assertFails(updatePreferredClass(
    auth('inactive-preference'), 'inactive-preference-profile', 'level-1-standard',
  ));
  await seedAccount({
    uid: 'wrong-location-preference', profileLocationId: 'other',
  });
  await assertFails(updatePreferredClass(
    auth('wrong-location-preference'),
    'wrong-location-preference-profile',
    'level-1-standard',
  ));
});

test('parent preference updates require the selected exact profile relationship', async () => {
  await seedAccount({
    uid: 'family',
    profileIds: ['selected-child', 'nonselected-child'],
    selectedProfileId: 'selected-child',
  });
  const db = auth('family');
  await assertSucceeds(updatePreferredClass(
    db, 'selected-child', 'level-1-standard',
  ));
  await assertSucceeds(updatePreferredClass(
    db, 'selected-child', 'teen-adult-standard',
  ));
  await assertSucceeds(updatePreferredClass(db, 'selected-child', null));
  await assertFails(updatePreferredClass(
    db, 'nonselected-child', 'level-2-standard',
  ));

  await seedAccount({uid: 'family-self', selfManaged: true});
  await assertSucceeds(updatePreferredClass(
    auth('family-self'), 'family-self-profile', 'level-3-standard',
  ));
});

test('parent adds and removes a child only through atomic family writes', async () => {
  await seedAccount({uid: 'parent'});
  const db = auth('parent');
  const userRef = doc(db, 'users', 'parent');
  const childRef = doc(db, 'studentProfiles', 'new-child');
  let batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile', 'new-child'],
    updatedAt: serverTimestamp(),
  });
  batch.set(childRef, {
    firstName: 'New', lastName: 'Child',
    dateOfBirth: new Date('2015-01-02T00:00:00Z'), beltRank: 'White',
    locationId: 'cheshire', guardianEmail: 'parent@example.com',
    guardianUserIds: ['parent'], preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile'],
    selectedStudentProfileId: 'parent-profile',
    updatedAt: serverTimestamp(),
  });
  batch.update(childRef, {isActive: false, updatedAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
  await env.withSecurityRulesDisabled(async (context) => {
    const removed = await getDoc(
      doc(context.firestore(), 'studentProfiles', 'new-child'),
    );
    assert.equal(removed.data().isActive, false);
  });

  const finalBatch = writeBatch(db);
  finalBatch.update(userRef, {
    linkedStudentProfileIds: [], updatedAt: serverTimestamp(),
  });
  finalBatch.update(doc(db, 'studentProfiles', 'parent-profile'), {
    isActive: false, updatedAt: serverTimestamp(),
  });
  await assertFails(finalBatch.commit());
});

test('parent atomically adds one linked self student profile', async () => {
  await seedAccount({uid: 'parent'});
  const db = auth('parent');
  const userRef = doc(db, 'users', 'parent');
  const selfRef = doc(db, 'studentProfiles', 'parent-self');
  let batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile', 'parent-self'],
    updatedAt: serverTimestamp(),
  });
  batch.set(selfRef, {
    firstName: 'Account', lastName: 'Parent',
    dateOfBirth: new Date('1990-01-02T00:00:00Z'), beltRank: 'Green',
    locationId: 'cheshire', guardianUserIds: [], linkedUserId: 'parent',
    preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'Green-Blue'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile', 'parent-self', 'duplicate-self'],
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(db, 'studentProfiles', 'duplicate-self'), {
    firstName: 'Duplicate', lastName: 'Parent',
    dateOfBirth: new Date('1990-01-02T00:00:00Z'), beltRank: 'White',
    locationId: 'cheshire', guardianUserIds: [], linkedUserId: 'parent',
    preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test('notification read state uses the exact private nested client path', async () => {
  await seedAccount({uid: 'reader'});
  await seedAccount({uid: 'other'});
  const ownRef = doc(auth('reader'), 'users', 'reader', 'notificationReads', 'notice');
  await assertSucceeds(markNotificationRead(auth('reader'), 'reader', 'notice'));
  await assertSucceeds(getDoc(ownRef));
  await assertSucceeds(updateDoc(ownRef, {readAt: serverTimestamp()}));
  await assertSucceeds(getDocs(
    collection(auth('reader'), 'users', 'reader', 'notificationReads'),
  ));
  await assertFails(getDoc(
    doc(auth('other'), 'users', 'reader', 'notificationReads', 'notice'),
  ));
  await assertFails(setDoc(
    doc(auth('other'), 'users', 'reader', 'notificationReads', 'other-write'),
    {readAt: serverTimestamp()},
  ));
  await assertFails(setDoc(
    doc(auth('reader'), 'users', 'reader', 'notificationReads', 'bad'),
    {readAt: serverTimestamp(), extra: true},
  ));
  await assertFails(getDoc(
    doc(env.unauthenticatedContext().firestore(),
      'users', 'reader', 'notificationReads', 'notice'),
  ));

  const batchDb = auth('reader');
  const batch = writeBatch(batchDb);
  for (const id of ['notice-2', 'notice-3']) {
    batch.set(doc(batchDb, 'users', 'reader', 'notificationReads', id), {
      readAt: serverTimestamp(),
    });
  }
  await assertSucceeds(batch.commit());
  await assertSucceeds(deleteDoc(ownRef));
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
    beltRank: 'Yellow',
    stickerProgress: {current: 0, required: 0, nextRank: 'Yellow-Green'},
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'studentProfiles', 'cheshire-parent-profile'), {
    locationId: 'other', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users', 'cheshire-parent'), {
    role: 'admin', updatedAt: serverTimestamp(),
  }));
});

test('location admin cannot change administrator activation', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  await seedAccount({uid: 'second-admin', role: 'admin', profileIds: []});
  await seedAccount({uid: 'member'});
  await seedAccount({uid: 'super', role: 'superAdmin', profileIds: []});
  const adminDb = auth('admin');
  await assertSucceeds(updateDoc(doc(adminDb, 'users', 'member'), {
    isActive: false, updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(adminDb, 'users', 'second-admin'), {
    isActive: false, updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(auth('super'), 'users', 'second-admin'), {
    isActive: false, updatedAt: serverTimestamp(),
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
