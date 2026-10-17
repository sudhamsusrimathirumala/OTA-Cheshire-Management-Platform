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
  markNotificationUnread,
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
  profileDateOfBirth = new Date('2010-01-02T00:00:00Z'),
  selfManaged = role === 'student',
}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', uid), {
      firstName: 'Account', lastName: uid, email: `${uid}@example.com`,
      role, isActive, locationId,
      linkedStudentProfileIds: profileIds,
      ...(selectedProfileId ? {selectedStudentProfileId: selectedProfileId} : {}),
      ...(role === 'parent' ? {
        parentSelfProfileId: selfManaged ? selectedProfileId : '',
      } : {}),
      createdAt: new Date(), updatedAt: new Date(),
    });
    for (const profileId of profileIds) {
      await setDoc(doc(db, 'studentProfiles', profileId), {
        firstName: 'Student', lastName: profileId,
        dateOfBirth: profileDateOfBirth, beltRank: 'White',
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
    await setDoc(doc(db, 'announcements', 'published'), {
      ...base, status: 'published', audienceType: 'everyone',
    });
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

async function seedGuestMismatch(uid, role) {
  const memberProfileIds = ['parent', 'student'].includes(role)
    ? [`${uid}-profile`]
    : [];
  await seedAccount({
    uid,
    role,
    profileIds: memberProfileIds,
    selectedProfileId: memberProfileIds[0],
  });
  await seedAccount({uid: 'real-member'});
  await seedContent();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const privateData = {createdAt: new Date()};
    await setDoc(
      doc(db, 'users', uid, 'notificationReads', 'private'),
      {readAt: new Date()},
    );
    await setDoc(
      doc(db, 'users', uid, 'pushDevices', 'private'),
      {...privateData, fcmToken: 'private-token'},
    );
    await setDoc(
      doc(db, 'users', uid, 'announcementDeliveries', 'private'),
      privateData,
    );
  });
}

async function assertGuestClaimCannotUseRole(uid, role) {
  await seedGuestMismatch(uid, role);
  const db = auth(uid, `${uid}@example.com`, {otaGuest: true});

  await assertFails(getDoc(doc(db, 'users', uid)));
  await assertFails(getDoc(doc(db, 'users', 'real-member')));
  await assertFails(getDocs(collection(db, 'users')));
  await assertFails(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'classSessions', 'active-class')));
  await assertFails(getDoc(doc(db, 'announcements', 'published')));
  await assertFails(getDoc(doc(db, 'events', 'published')));
  await assertFails(getDoc(doc(db, 'resources', 'published')));
  for (const profileId of [`${uid}-profile`, 'real-member-profile']) {
    await assertFails(getDoc(doc(db, 'studentProfiles', profileId)));
  }
  await assertFails(updateDoc(doc(db, 'users', uid), {
    firstName: 'Changed', updatedAt: serverTimestamp(),
  }));
  await assertFails(deleteDoc(doc(db, 'users', 'real-member')));
  await assertFails(updateDoc(doc(db, 'locations', 'cheshire'), {
    name: 'Changed by guest claim',
  }));
  for (const collectionName of [
    'notificationReads',
    'pushDevices',
    'announcementDeliveries',
  ]) {
    await assertFails(deleteDoc(
      doc(db, 'users', uid, collectionName, 'private'),
    ));
  }
}

test('authenticated user reads active locations before account setup', async () => {
  const db = auth('new-user');
  await assertSucceeds(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'locations', 'inactive')));
});

test('guest claim can read only its own guest account record', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', 'reviewer'), {
      firstName: 'OTA', lastName: 'Reviewer', email: 'reviewer@example.com',
      role: 'guest', isActive: true, linkedStudentProfileIds: [],
      createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'users', 'real-member'), {
      firstName: 'Real', lastName: 'Member', email: 'real@example.com',
      role: 'parent', isActive: true, locationId: 'cheshire',
      linkedStudentProfileIds: ['real-profile'],
      selectedStudentProfileId: 'real-profile',
      createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'studentProfiles', 'real-profile'), {
      firstName: 'Real', lastName: 'Student', locationId: 'cheshire',
      isActive: true,
    });
  });
  await seedContent();
  const db = auth('reviewer', 'reviewer@example.com', {otaGuest: true});

  await assertSucceeds(getDoc(doc(db, 'users', 'reviewer')));
  await assertFails(getDoc(doc(db, 'users', 'real-member')));
  await assertFails(getDocs(collection(db, 'users')));
  await assertFails(getDoc(doc(db, 'studentProfiles', 'real-profile')));
  await assertFails(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'classSessions', 'active-class')));
  await assertFails(getDoc(doc(db, 'announcements', 'published')));
  await assertFails(getDoc(doc(db, 'events', 'published')));
  await assertFails(getDoc(doc(db, 'resources', 'published')));
  await assertFails(updateDoc(doc(db, 'users', 'reviewer'), {
    firstName: 'Changed', updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(
    doc(db, 'users', 'reviewer', 'notificationReads', 'published'),
    {readAt: serverTimestamp()},
  ));
  await assertFails(getDoc(
    doc(db, 'users', 'reviewer', 'announcementDeliveries', 'published'),
  ));
  await assertFails(setDoc(
    doc(db, 'users', 'reviewer', 'pushDevices', 'installation'),
    {
      fcmToken: 'guest-token', platform: 'android', appEnvironment: 'prod',
      enabled: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      lastSeenAt: serverTimestamp(),
    },
  ));
});

test('guest claim cannot use public onboarding when its user record is absent', async () => {
  await seedContent();
  const db = auth('unconfigured-reviewer', 'reviewer@example.com', {otaGuest: true});
  await assertFails(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'classSessions', 'active-class')));
  await assertFails(createProfiles(db, {
    uid: 'unconfigured-reviewer', email: 'reviewer@example.com',
    profileIds: ['guest-profile'],
  }));
});

test('guest claim overrides an inconsistent admin role', async () => {
  await assertGuestClaimCannotUseRole('guest-admin', 'admin');
});

test('guest claim overrides an inconsistent superAdmin role', async () => {
  await assertGuestClaimCannotUseRole('guest-super-admin', 'superAdmin');
});

test('guest claim overrides an inconsistent parent role', async () => {
  await assertGuestClaimCannotUseRole('guest-parent', 'parent');
});

test('guest claim overrides an inconsistent student role', async () => {
  await assertGuestClaimCannotUseRole('guest-student', 'student');
});

test('role-only guest identity remains restricted without the claim', async () => {
  await seedGuestMismatch('role-only-guest', 'guest');
  const db = auth('role-only-guest');

  await assertSucceeds(getDoc(doc(db, 'users', 'role-only-guest')));
  await assertFails(getDoc(doc(db, 'users', 'real-member')));
  await assertFails(getDocs(collection(db, 'users')));
  await assertFails(getDoc(doc(db, 'locations', 'cheshire')));
  await assertFails(getDoc(doc(db, 'classSessions', 'active-class')));
  await assertFails(updateDoc(doc(db, 'users', 'role-only-guest'), {
    firstName: 'Changed', updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(
    doc(db, 'users', 'role-only-guest', 'notificationReads', 'new'),
    {readAt: serverTimestamp()},
  ));
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

test('independent registration rejects an under-16 student bypass', async () => {
  const now = new Date();
  const under16 = new Date(Date.UTC(
    now.getUTCFullYear() - 15,
    now.getUTCMonth(),
    now.getUTCDate(),
  ));
  const db = auth('underage-student');
  await assertFails(createProfiles(db, {
    uid: 'underage-student',
    email: 'underage-student@example.com',
    profileIds: ['underage-profile'],
    applicantDateOfBirth: under16,
  }));
});

test('independent registration accepts a student aged exactly 16', async () => {
  const now = new Date();
  const exactly16 = new Date(Date.UTC(
    now.getUTCFullYear() - 16,
    now.getUTCMonth(),
    now.getUTCDate(),
  ));
  const db = auth('sixteen-student');
  await assertSucceeds(createProfiles(db, {
    uid: 'sixteen-student',
    email: 'sixteen-student@example.com',
    profileIds: ['sixteen-profile'],
    applicantDateOfBirth: exactly16,
  }));
});

test('adult parent registration permits an under-16 managed child', async () => {
  const db = auth('adult-parent');
  await assertSucceeds(createProfiles(db, {
    uid: 'adult-parent',
    email: 'adult-parent@example.com',
    role: 'parent',
    profileIds: ['managed-child'],
    applicantDateOfBirth: new Date('1990-01-02T00:00:00Z'),
  }));
  const child = (await getDoc(
    doc(db, 'studentProfiles', 'managed-child'),
  )).data();
  assert.equal(child.dateOfBirth.toDate().getUTCFullYear(), 2015);
});

test('under-18 applicant cannot bypass the adult gate by choosing parent', async () => {
  const now = new Date();
  const under18 = new Date(Date.UTC(
    now.getUTCFullYear() - 17,
    now.getUTCMonth(),
    now.getUTCDate(),
  ));
  const db = auth('underage-parent');
  await assertFails(createProfiles(db, {
    uid: 'underage-parent',
    email: 'underage-parent@example.com',
    role: 'parent',
    profileIds: ['managed-child'],
    applicantDateOfBirth: under18,
  }));
});

test('location admin may update an under-16 student training record', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  await seedAccount({
    uid: 'younger-student-parent',
    profileDateOfBirth: new Date('2018-01-02T00:00:00Z'),
  });
  const db = auth('admin');
  await assertSucceeds(updateDoc(
    doc(db, 'studentProfiles', 'younger-student-parent-profile'),
    {
      beltRank: 'Yellow',
      stickerProgress: {current: 0, required: 0, nextRank: 'Yellow-Green'},
      updatedAt: serverTimestamp(),
    },
  ));
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

test('parent onboarding supports 9, 10, and 11 linked profiles', async () => {
  for (const count of [9, 10, 11]) {
    const uid = `family-${count}`;
    const profileIds = Array.from(
      {length: count},
      (_, index) => `${uid}-profile-${index}`,
    );
    const db = auth(uid);
    await assertSucceeds(createProfiles(db, {
      uid,
      email: `${uid}@example.com`,
      role: 'parent',
      profileIds,
      parentIsStudent: count === 11,
    }));
    const user = (await getDoc(doc(db, 'users', uid))).data();
    assert.equal(user.linkedStudentProfileIds.length, count);
    assert.equal(
      user.parentSelfProfileId,
      count === 11 ? profileIds[0] : '',
    );
  }
});

test('parent onboarding may atomically retain self-profile defaults', async () => {
  const db = auth('parent-defaults');
  await assertSucceeds(createProfiles(db, {
    uid: 'parent-defaults', email: 'parent-defaults@example.com', role: 'parent',
    profileIds: ['defaults-child'],
    studentProfileDefaults: {
      dateOfBirth: new Date('1990-02-03T00:00:00Z'),
      beltRank: 'Green', guardianEmail: 'contact@example.com',
      stickerProgress: {current: 0, required: 0, nextRank: 'Green-Blue'},
    },
  }));
  const user = (await getDoc(doc(db, 'users', 'parent-defaults'))).data();
  assert.equal(user.studentProfileDefaults.beltRank, 'Green');
  assert.equal(user.studentProfileDefaults.guardianEmail, 'contact@example.com');

  await assertFails(createProfiles(auth('invalid-defaults'), {
    uid: 'invalid-defaults', email: 'invalid-defaults@example.com', role: 'parent',
    profileIds: ['invalid-defaults-child'],
    studentProfileDefaults: {
      dateOfBirth: new Date('1990-02-03T00:00:00Z'), beltRank: 'Not a belt',
      stickerProgress: {current: 0, required: 0, nextRank: 'Invented'},
    },
  }));
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
  await assertSucceeds(updateDoc(doc(db, 'users', 'owner'), {
    linkedStudentProfileIds: ['owner-profile', 'other-profile'],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(getDoc(doc(db, 'studentProfiles', 'other-profile')));
  await assertFails(selectProfile(db, 'owner', 'other-profile'));

  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'owner-profile'),
      {guardianUserIds: ['owner', 'other']},
    );
  });
  await assertFails(getDoc(doc(db, 'studentProfiles', 'owner-profile')));
  await assertFails(updateDoc(doc(db, 'studentProfiles', 'owner-profile'), {
    firstName: 'Claimed', updatedAt: serverTimestamp(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'owner-profile'),
      {guardianUserIds: ['owner'], linkedUserId: ''},
    );
  });
  await assertFails(getDoc(doc(db, 'studentProfiles', 'owner-profile')));

  await seedContent();
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'users', 'owner'), {
      selectedStudentProfileId: 'other-profile',
    });
  });
  await assertFails(getDoc(doc(db, 'announcements', 'published')));
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
  await assertFails(updateDoc(profileRef, {
    beltRank: 'Blue', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    beltRank: 'Blue',
    stickerProgress: {current: 1, required: 5, nextRank: 'Green-Blue'},
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    stickerProgress: {current: -1, required: 5, nextRank: 'Yellow-Green'},
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

test('linked profile edits ignore selection but require authoritative ownership', async () => {
  await seedAccount({
    uid: 'parent',
    profileIds: ['selected-child', 'other-child'],
    selectedProfileId: 'selected-child',
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const seedDb = context.firestore();
    await updateDoc(doc(seedDb, 'studentProfiles', 'selected-child'), {
      guardianUserIds: [], linkedUserId: 'legacy-linked-user',
    });
    await updateDoc(doc(seedDb, 'studentProfiles', 'other-child'), {
      guardianUserIds: ['legacy-guardian'], linkedUserId: 'legacy-linked-user',
    });
  });
  const db = auth('parent');
  await assertFails(updateManagedProfile(db, 'selected-child'));
  await assertFails(updateManagedProfile(db, 'other-child', {
    firstName: 'Other', guardianEmail: 'guardian@example.com',
    beltRank: 'Blue',
    stickerProgress: {current: 4, required: 5, nextRank: 'Blue-Red'},
  }));

  await assertFails(getDoc(doc(db, 'studentProfiles', 'other-child')));
});

test('student edits linked profile while invalid linked access is denied', async () => {
  await seedAccount({uid: 'student-account', role: 'student'});
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'student-account-profile'),
      {linkedUserId: 'legacy-user', guardianUserIds: ['legacy-guardian']},
    );
  });
  await assertFails(updateManagedProfile(
    auth('student-account'), 'student-account-profile',
    {guardianEmail: 'student@example.com'},
  ));

  await seedAccount({uid: 'other-parent'});
  await assertFails(updateManagedProfile(
    auth('other-parent'), 'student-account-profile',
    {guardianEmail: 'other@example.com'},
  ));

  await seedAccount({uid: 'wrong-location-edit', profileLocationId: 'other'});
  await assertFails(updateManagedProfile(
    auth('wrong-location-edit'), 'wrong-location-edit-profile',
  ));
  await seedAccount({uid: 'inactive-edit', profileActive: false});
  await assertFails(updateManagedProfile(
    auth('inactive-edit'), 'inactive-edit-profile',
  ));
  await seedAccount({uid: 'inactive-account-edit', isActive: false});
  await assertFails(updateManagedProfile(
    auth('inactive-account-edit'), 'inactive-account-edit-profile',
  ));

  const selfRef = doc(
    auth('student-account'), 'studentProfiles', 'student-account-profile',
  );
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
    preferredClassGroupIds: ['level 3'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    preferredClassGroupIds: ['level-1-standard', 'level-2-standard'],
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(profileRef, {
    preferredClassGroupIds: [`x${'a'.repeat(100)}`],
    updatedAt: serverTimestamp(),
  }));
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

test('linked profile preference updates do not require current selection', async () => {
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
  await assertSucceeds(updatePreferredClass(
    db, 'nonselected-child', 'level-2-standard',
  ));

  await seedAccount({uid: 'family-self', selfManaged: true});
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'studentProfiles', 'family-self-profile'),
      {linkedUserId: 'legacy-user', guardianUserIds: ['legacy-guardian']},
    );
  });
  await assertFails(updatePreferredClass(
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

  await assertFails(updateDoc(userRef, {
    linkedStudentProfileIds: ['parent-profile'],
    selectedStudentProfileId: 'parent-profile',
    profileMutationId: 'new-child',
    updatedAt: serverTimestamp(),
  }));

  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile'],
    selectedStudentProfileId: 'parent-profile',
    profileMutationId: 'new-child',
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
  await assertFails(getDoc(childRef));

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
    parentSelfProfileId: 'parent-self',
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
    parentSelfProfileId: 'duplicate-self',
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

  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile'],
    selectedStudentProfileId: 'parent-profile',
    parentSelfProfileId: '',
    profileMutationId: 'parent-self',
    updatedAt: serverTimestamp(),
  });
  batch.update(selfRef, {isActive: false, updatedAt: serverTimestamp()});
  await assertSucceeds(batch.commit());
  await env.withSecurityRulesDisabled(async (context) => {
    const removed = await getDoc(
      doc(context.firestore(), 'studentProfiles', 'parent-self'),
    );
    assert.equal(removed.data().isActive, false);
  });

  const replacementRef = doc(db, 'studentProfiles', 'parent-self-replacement');
  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: ['parent-profile', 'parent-self-replacement'],
    parentSelfProfileId: 'parent-self-replacement',
    updatedAt: serverTimestamp(),
  });
  batch.set(replacementRef, {
    firstName: 'Account', lastName: 'Parent',
    dateOfBirth: new Date('1990-01-02T00:00:00Z'), beltRank: 'Green',
    locationId: 'cheshire', guardianUserIds: [], linkedUserId: 'parent',
    preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'Green-Blue'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test('family add, self-add, remove, and select work at the 11-profile boundary', async () => {
  const childFields = (uid) => ({
    firstName: 'Boundary', lastName: 'Child',
    dateOfBirth: new Date('2015-01-02T00:00:00Z'), beltRank: 'White',
    locationId: 'cheshire', guardianEmail: `${uid}@example.com`,
    guardianUserIds: [uid], preferredClassGroupIds: [],
    stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
    promotionHistory: [], testingNotes: [], isActive: true,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });

  const childIds = Array.from({length: 10}, (_, index) => `near-child-${index}`);
  await seedAccount({uid: 'near-limit', profileIds: childIds});
  const db = auth('near-limit');
  const userRef = doc(db, 'users', 'near-limit');
  const addedRef = doc(db, 'studentProfiles', 'near-child-10');
  let batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: [...childIds, 'near-child-10'],
    updatedAt: serverTimestamp(),
  });
  batch.set(addedRef, childFields('near-limit'));
  await assertSucceeds(batch.commit());
  await assertSucceeds(selectProfile(db, 'near-limit', 'near-child-10'));

  const overflowRef = doc(db, 'studentProfiles', 'near-child-11');
  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: [...childIds, 'near-child-10', 'near-child-11'],
    updatedAt: serverTimestamp(),
  });
  batch.set(overflowRef, childFields('near-limit'));
  await assertFails(batch.commit());

  batch = writeBatch(db);
  batch.update(userRef, {
    linkedStudentProfileIds: [...childIds, 'near-child-10'].filter(
      (id) => id !== 'near-child-0',
    ),
    selectedStudentProfileId: 'near-child-10',
    profileMutationId: 'near-child-0',
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(db, 'studentProfiles', 'near-child-0'), {
    isActive: false, updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  const selfChildIds = Array.from(
    {length: 10},
    (_, index) => `self-child-${index}`,
  );
  await seedAccount({uid: 'self-near-limit', profileIds: selfChildIds});
  const selfDb = auth('self-near-limit');
  const selfRef = doc(selfDb, 'studentProfiles', 'boundary-self');
  batch = writeBatch(selfDb);
  batch.update(doc(selfDb, 'users', 'self-near-limit'), {
    linkedStudentProfileIds: [...selfChildIds, 'boundary-self'],
    parentSelfProfileId: 'boundary-self',
    updatedAt: serverTimestamp(),
  });
  batch.set(selfRef, {
    ...childFields('self-near-limit'),
    guardianUserIds: [], linkedUserId: 'self-near-limit',
  });
  await assertSucceeds(batch.commit());
});

test('notification read state uses the exact private nested client path', async () => {
  await seedAccount({uid: 'reader'});
  await seedAccount({uid: 'other'});
  await seedAccount({uid: 'inactive-reader', isActive: false});
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
  await assertSucceeds(markNotificationUnread(auth('reader'), 'reader', 'notice'));
  assert.equal((await getDoc(ownRef)).exists(), false);
  await assertFails(markNotificationUnread(auth('other'), 'reader', 'notice-2'));

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(
      context.firestore(), 'users', 'inactive-reader',
      'notificationReads', 'notice',
    ), {readAt: new Date()});
  });
  const inactiveRef = doc(
    auth('inactive-reader'), 'users', 'inactive-reader',
    'notificationReads', 'notice',
  );
  await assertFails(getDoc(inactiveRef));
  await assertFails(updateDoc(inactiveRef, {readAt: serverTimestamp()}));
  await assertSucceeds(deleteDoc(inactiveRef));
});

test('admin content writes accept app schemas and reject injected fields', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  const db = auth('admin');
  const now = new Date();
  const announcementRef = doc(db, 'announcements', 'admin-schema');
  const classRef = doc(db, 'classSessions', 'admin-schema');
  const eventRef = doc(db, 'events', 'admin-schema');
  const resourceRef = doc(db, 'resources', 'admin-schema');

  await assertSucceeds(setDoc(announcementRef, {
    title: 'Notice', summary: 'Summary', body: 'Body',
    announcementType: 'general', priority: 'general', requiresAction: false,
    status: 'draft', audienceType: 'everyone', locationId: 'cheshire',
    targetBelts: [], targetClassTypeIds: [], targetStudentProfileIds: [],
    targetUserIds: [], createdAt: now, updatedAt: now,
  }));
  await assertSucceeds(setDoc(classRef, {
    className: 'Level 1', classTypeId: 'level-1',
    bulkGroupId: 'level-1-standard', locationId: 'cheshire', weekday: 2,
    startMinutes: 600, endMinutes: 660, eligibleBelts: ['White'],
    description: 'Class', isActive: true, createdAt: now, updatedAt: now,
  }));
  await assertSucceeds(setDoc(eventRef, {
    title: 'Seminar', description: 'Event', locationId: 'cheshire',
    eventType: 'seminar', startDateTime: new Date('2027-01-01T15:00:00Z'),
    endDateTime: new Date('2027-01-01T16:00:00Z'), linkedResourceIds: [],
    isPublished: false, isArchived: false, createdAt: now, updatedAt: now,
  }));
  await assertSucceeds(setDoc(resourceRef, {
    title: 'Registration', description: 'Form', resourceSection: 'general',
    category: 'registration', linkUrl: 'https://example.com/form',
    locationId: 'cheshire', isPublished: false, isArchived: false,
    createdAt: now, updatedAt: now,
  }));

  await assertSucceeds(updateDoc(announcementRef, {
    status: 'archived', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(classRef, {
    isActive: false, updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(eventRef, {
    isArchived: true, updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(resourceRef, {
    isArchived: true, updatedAt: serverTimestamp(),
  }));

  for (const reference of [announcementRef, classRef, eventRef, resourceRef]) {
    await assertFails(updateDoc(reference, {
      injectedAdminField: true, updatedAt: serverTimestamp(),
    }));
  }
  await assertFails(updateDoc(eventRef, {
    locationId: 'other', updatedAt: serverTimestamp(),
  }));
  await assertFails(setDoc(doc(db, 'resources', 'bad-schema'), {
    title: 'Bad', description: 'Bad', resourceSection: 'general',
    category: 'registration', locationId: 'cheshire', isPublished: false,
    isArchived: false, createdAt: now, updatedAt: now, unexpected: true,
  }));
});

test('real admin can duplicate published content into independent draft documents', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  const db = auth('admin');
  const now = new Date();
  const original = {
    title: 'Notice', summary: 'Summary', body: 'Body',
    announcementType: 'general', priority: 'important', requiresAction: false,
    status: 'published', audienceType: 'everyone', locationId: 'cheshire',
    targetBelts: [], targetClassTypeIds: [], targetStudentProfileIds: [],
    targetUserIds: [], createdAt: now, updatedAt: now, publishedAt: now,
  };
  const notice = doc(db, 'announcements', 'source-notice');
  const noticeCopy = doc(collection(db, 'announcements'));
  await assertSucceeds(setDoc(notice, original));
  await assertSucceeds(setDoc(noticeCopy, {
    ...Object.fromEntries(
      Object.entries(original).filter(([field]) => field !== 'publishedAt'),
    ),
    status: 'draft', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  const noticeResult = (await getDoc(noticeCopy)).data();
  assert.equal(noticeResult.status, 'draft');
  assert.equal(noticeResult.publishedAt, undefined);
  assert.equal((await getDoc(notice)).data().status, 'published');

  const resource = {
    title: 'Form', description: 'Registration', resourceSection: 'general',
    category: 'registration', linkUrl: 'https://example.com/form',
    locationId: 'cheshire', isPublished: true, isArchived: false,
    createdAt: now, updatedAt: now,
  };
  const resourceOriginal = doc(db, 'resources', 'source-form');
  const resourceCopy = doc(collection(db, 'resources'));
  await assertSucceeds(setDoc(resourceOriginal, resource));
  await assertSucceeds(setDoc(resourceCopy, {
    ...resource, isPublished: false, isArchived: false,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(resourceCopy)).data().isPublished, false);
  assert.equal((await getDoc(resourceOriginal)).data().isPublished, true);

  const event = {
    title: 'Seminar', description: 'Source event', locationId: 'cheshire',
    eventType: 'seminar',
    startDateTime: new Date('2027-01-04T15:00:00Z'),
    endDateTime: new Date('2027-01-04T16:00:00Z'),
    linkedResourceIds: [], isPublished: true, isArchived: false,
    reminders: {mode: 'none', offsetsMinutes: []},
    createdAt: now, updatedAt: now,
  };
  const eventOriginal = doc(db, 'events', 'source-seminar');
  const eventCopy = doc(collection(db, 'events'));
  await assertSucceeds(setDoc(eventOriginal, event));
  await assertSucceeds(setDoc(eventCopy, {
    ...event, isPublished: false,
    startDateTime: new Date('2027-01-11T15:00:00Z'),
    endDateTime: new Date('2027-01-11T16:00:00Z'),
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(eventCopy)).data().isPublished, false);
  assert.equal((await getDoc(eventOriginal)).data().isPublished, true);
});

test('admins may archive legacy content without editing its other fields', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const base = {
      locationId: 'cheshire', createdAt: new Date(), updatedAt: new Date(),
      legacyField: 'preserved',
    };
    for (const id of ['archive', 'edit', 'location', 'inject']) {
      await setDoc(doc(db, 'announcements', `legacy-${id}`), {
        ...base, title: 'Legacy announcement', status: 'published',
      });
      await setDoc(doc(db, 'events', `legacy-${id}`), {
        ...base, title: 'Legacy event', eventType: 'closure',
        isArchived: false,
      });
      await setDoc(doc(db, 'resources', `legacy-${id}`), {
        ...base, title: 'Legacy resource', category: 'academyInfo',
        isArchived: false,
      });
    }
  });

  const db = auth('admin');
  await assertSucceeds(updateDoc(doc(db, 'announcements', 'legacy-archive'), {
    status: 'archived', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(db, 'events', 'legacy-archive'), {
    isArchived: true, updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(doc(db, 'resources', 'legacy-archive'), {
    isArchived: true, updatedAt: serverTimestamp(),
  }));

  for (const collectionName of ['announcements', 'events', 'resources']) {
    await assertFails(updateDoc(doc(db, collectionName, 'legacy-edit'), {
      title: 'Unauthorized edit', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, collectionName, 'legacy-location'), {
      ...(collectionName === 'announcements'
        ? {status: 'archived'}
        : {isArchived: true}),
      locationId: 'other', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, collectionName, 'legacy-inject'), {
      ...(collectionName === 'announcements'
        ? {status: 'archived'}
        : {isArchived: true}),
      injectedAdminField: true, updatedAt: serverTimestamp(),
    }));
  }
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
    collection(db, 'announcements'),
    where('locationId', '==', 'cheshire'),
    where('status', '==', 'published'),
    where('audienceType', '==', 'everyone'),
  )));
  await assertSucceeds(getDocs(query(
    collection(db, 'events'),
    where('locationId', '==', 'cheshire'),
    where('isPublished', '==', true),
    where('isArchived', '==', false),
  )));
});

test('targeted announcements are readable only through the recipient inbox', async () => {
  await seedAccount({uid: 'recipient'});
  await seedAccount({uid: 'non-recipient'});
  await seedAccount({
    uid: 'other-location', locationId: 'other', profileLocationId: 'other',
  });
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const content = {
      announcementId: 'targeted', title: 'Private update', summary: 'Summary',
      body: 'Recipient-only body', announcementType: 'general',
      priority: 'general', requiresAction: false, status: 'published',
      audienceType: 'students', locationId: 'cheshire',
      publishedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
      targetStudentProfileIds: ['recipient-profile'],
    };
    await setDoc(doc(db, 'announcements', 'targeted'), content);
    await setDoc(
      doc(db, 'users', 'recipient', 'announcementDeliveries', 'targeted'),
      content,
    );
  });

  await assertFails(getDoc(doc(auth('recipient'), 'announcements', 'targeted')));
  await assertFails(getDoc(
    doc(auth('non-recipient'), 'announcements', 'targeted'),
  ));
  await assertSucceeds(getDoc(doc(auth('admin'), 'announcements', 'targeted')));
  await assertSucceeds(getDoc(doc(
    auth('recipient'), 'users', 'recipient',
    'announcementDeliveries', 'targeted',
  )));
  await assertFails(getDoc(doc(
    auth('non-recipient'), 'users', 'recipient',
    'announcementDeliveries', 'targeted',
  )));
  await assertFails(getDoc(doc(
    auth('other-location'), 'users', 'recipient',
    'announcementDeliveries', 'targeted',
  )));

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await updateDoc(doc(db, 'announcements', 'targeted'), {
      body: 'Changed target body', targetStudentProfileIds: ['non-recipient-profile'],
    });
    await deleteDoc(doc(
      db, 'users', 'recipient', 'announcementDeliveries', 'targeted',
    ));
  });
  await assertFails(getDoc(doc(auth('recipient'), 'announcements', 'targeted')));
  const removed = await assertSucceeds(getDoc(doc(
    auth('recipient'), 'users', 'recipient',
    'announcementDeliveries', 'targeted',
  )));
  assert.equal(removed.exists(), false);
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


test('event recurrence/reminders remain admin-only, location scoped and server queue private', async () => {
  for (const [uid, role, locationId] of [['admin', 'admin', 'cheshire'], ['super', 'superAdmin', 'cheshire'],
    ['parent', 'parent', 'cheshire'], ['student', 'student', 'cheshire'], ['guest', 'guest', 'cheshire'], ['other-admin', 'admin', 'other']]) {
    await seedAccount({uid, role, locationId, profileIds: ['parent', 'student'].includes(role) ? [`${uid}-profile`] : []});
  }
  const start = new Date('2027-01-04T14:00:00Z');
  const eventSchedule = {version: 1, timeZoneId: 'America/New_York', firstOccurrenceId: 'd20270104',
    rule: {frequency: 'daily', startDate: '2027-01-04', endDate: '2027-01-05', startMinutes: 540,
      endMinutes: 900, endDayOffset: 0, intervalWeeks: 1, weekdays: [], customDates: [], weekdayTimes: {}, maxOccurrences: 180},
    occurrences: [{id: 'd20270104', startMillis: start.getTime(), endMillis: start.getTime() + 3600000, canceled: false}]};
  const data = {title: 'Camp', description: 'Sessions', locationId: 'cheshire', eventType: 'summerCamp',
    startDateTime: start, endDateTime: new Date(start.getTime() + 3600000), linkedResourceIds: [],
    isPublished: false, isArchived: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    eventSchedule, reminders: {mode: 'first', offsetsMinutes: [1440, 60]}};
  await assertSucceeds(setDoc(doc(auth('admin'), 'events', 'series'), data));
  for (const uid of ['parent', 'student', 'guest', 'other-admin']) {
    await assertFails(setDoc(doc(auth(uid), 'events', `copy-${uid}`), data));
    await assertFails(updateDoc(doc(auth(uid), 'events', 'series'), {reminders: {mode: 'every', offsetsMinutes: [60]}}));
  }
  await assertSucceeds(setDoc(doc(auth('super'), 'events', 'independent-copy'), data));
  const admin = auth('admin');
  await assertFails(updateDoc(doc(admin, 'events', 'series'), {reminders: {mode: 'first', offsetsMinutes: [-1]}}));
  await assertFails(updateDoc(doc(admin, 'events', 'series'), {eventSchedule: {...eventSchedule, occurrences: Array(181).fill(eventSchedule.occurrences[0])}}));
  await assertFails(updateDoc(doc(admin, 'events', 'series'), {eventSchedule: {...eventSchedule, timeZoneId: 'America/Chicago'}}));
  await assertFails(updateDoc(doc(admin, 'events', 'series'), {reminders: {mode: 'first', offsetsMinutes: [60], sendNow: true}}));
  for (const uid of ['admin', 'super', 'parent', 'guest']) {
    await assertFails(setDoc(doc(auth(uid), 'eventReminders', 'forged'), {status: 'pending'}));
    await assertFails(getDoc(doc(auth(uid), 'eventReminders', 'forged')));
    await assertFails(setDoc(doc(auth(uid), 'eventReminders', 'forged', 'targets', 'token'), {status: 'sent'}));
  }
});

test('event resource references are revalidated on duplication/publication', async () => {
  await seedAccount({uid: 'admin', role: 'admin', profileIds: []});
  const db = auth('admin');
  const resource = {title: 'Form', description: '', resourceSection: 'general', category: 'registration',
    locationId: 'cheshire', isPublished: false, isArchived: false, createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(db, 'resources', 'form'), resource));
  const event = {title: 'Seminar', description: 'Details', eventType: 'seminar', locationId: 'cheshire',
    startDateTime: new Date('2027-01-01T15:00:00Z'), endDateTime: new Date('2027-01-01T16:00:00Z'),
    linkedResourceIds: ['form'], primaryRegistrationResourceId: 'form', isPublished: false, isArchived: false,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(db, 'events', 'draft-copy'), event));
  await assertFails(updateDoc(doc(db, 'events', 'draft-copy'), {isPublished: true, updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db, 'resources', 'form'), {isPublished: true, updatedAt: serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(db, 'events', 'draft-copy'), {isPublished: true, updatedAt: serverTimestamp()}));
  await assertFails(setDoc(doc(db, 'events', 'invalid-copy'), {...event, linkedResourceIds: ['missing'], primaryRegistrationResourceId: 'missing'}));
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'resources', 'other-form'), {...resource, locationId: 'other', isPublished: true});
  });
  await assertFails(setDoc(doc(db, 'events', 'cross-location-copy'), {...event, linkedResourceIds: ['other-form'], primaryRegistrationResourceId: 'other-form'}));
});
