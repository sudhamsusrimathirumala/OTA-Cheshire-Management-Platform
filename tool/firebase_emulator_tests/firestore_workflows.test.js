import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
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
  getDocs,
  collection,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {createProfiles, selectProfile} from './client_workflows.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-membership';
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
  return env.authenticatedContext(uid, {
    email,
    email_verified: true,
    ...claims,
  }).firestore();
}

async function seedAdmin(uid, role = 'admin', locationId = 'cheshire') {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), {
      firstName: 'Academy', lastName: 'Admin', email: `${uid}@example.com`,
      role, approvalStatus: 'approved', locationId,
      linkedStudentProfileIds: [], selectedStudentProfileId: '',
    });
  });
}

async function apply(db, uid, profileId, locationId, own = true) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'studentProfiles', profileId), {
    locationId,
    approvalStatus: 'pending',
    reviewedAt: deleteField(),
    reviewedBy: deleteField(),
    rejectionReason: deleteField(),
    updatedAt: serverTimestamp(),
  });
  if (own) batch.update(doc(db, 'users', uid), {locationId, updatedAt: serverTimestamp()});
  await batch.commit();
}

async function review(db, profileId, reviewerId, approved, reason) {
  await updateDoc(doc(db, 'studentProfiles', profileId), {
    approvalStatus: approved ? 'approved' : 'rejected',
    reviewedAt: serverTimestamp(),
    reviewedBy: reviewerId,
    updatedAt: serverTimestamp(),
    rejectionReason: approved || !reason ? deleteField() : reason,
  });
}

async function leave(db, uid, profileId, own = true) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'studentProfiles', profileId), {
    locationId: deleteField(),
    approvalStatus: 'incomplete',
    reviewedAt: deleteField(),
    reviewedBy: deleteField(),
    rejectionReason: deleteField(),
    updatedAt: serverTimestamp(),
  });
  if (own) batch.update(doc(db, 'users', uid), {locationId: deleteField(), updatedAt: serverTimestamp()});
  await batch.commit();
}

test('verified student atomically creates canonical unassigned records', async () => {
  const db = auth('student', 'Student@Example.com');
  await assertSucceeds(createProfiles(db, {
    uid: 'student', email: 'student@example.com', profileIds: ['student-profile'],
  }));
  const user = (await getDoc(doc(db, 'users', 'student'))).data();
  const profile = (await getDoc(doc(db, 'studentProfiles', 'student-profile'))).data();
  assert.equal(user.approvalStatus, 'incomplete');
  assert.equal('locationId' in user, false);
  assert.equal(profile.approvalStatus, 'incomplete');
  assert.equal('locationId' in profile, false);
});

test('unverified users and partial or elevated initial writes fail', async () => {
  const unverified = env.authenticatedContext('unverified', {
    email: 'unverified@example.com', email_verified: false,
  }).firestore();
  await assertFails(createProfiles(unverified, {
    uid: 'unverified', email: 'unverified@example.com', profileIds: ['p'],
  }));
  const db = auth('partial');
  await assertFails(setDoc(doc(db, 'users', 'partial'), {
    firstName: 'Bad', lastName: 'Write', email: 'partial@example.com',
    role: 'student', approvalStatus: 'approved', locationId: 'cheshire',
    linkedStudentProfileIds: ['missing'], selectedStudentProfileId: 'missing',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  assert.equal((await getDoc(doc(db, 'users', 'partial'))).exists(), false);
});

test('initial profiles cannot assign a location or elevated membership state', async () => {
  const locationDb = auth('initial-location');
  await assertFails(createProfiles(locationDb, {
    uid: 'initial-location', email: 'initial-location@example.com',
    profileIds: ['profile'], profileOverrides: {locationId: 'cheshire'},
  }));
  const approvedDb = auth('initial-approved');
  await assertFails(createProfiles(approvedDb, {
    uid: 'initial-approved', email: 'initial-approved@example.com',
    profileIds: ['profile'], profileOverrides: {approvalStatus: 'approved'},
  }));
});

test('parent creates own and child profiles with exact family relationships', async () => {
  const db = auth('parent');
  await assertSucceeds(createProfiles(db, {
    uid: 'parent', email: 'parent@example.com', role: 'parent',
    familyApplicationId: 'family-1', profileIds: ['parent-profile', 'child-profile'],
  }));
  assert.deepEqual((await getDoc(doc(db, 'users', 'parent'))).data().linkedStudentProfileIds,
      ['parent-profile', 'child-profile']);
  assert.deepEqual((await getDoc(doc(db, 'studentProfiles', 'child-profile'))).data().guardianUserIds,
      ['parent']);
});

test('parent cannot create multiple self-linked profiles', async () => {
  const db = auth('bad-parent');
  await assertFails(createProfiles(db, {
    uid: 'bad-parent', email: 'bad-parent@example.com', role: 'parent',
    familyApplicationId: 'family-bad', profileIds: ['own-1', 'own-2'],
    profileOverrides: {linkedUserId: 'bad-parent', guardianUserIds: []},
  }));
});

test('parent may atomically create an own profile plus ten children', async () => {
  const db = auth('large-family');
  const ids = Array.from({length: 11}, (_, index) => `family-profile-${index}`);
  await assertSucceeds(createProfiles(db, {
    uid: 'large-family', email: 'large-family@example.com', role: 'parent',
    familyApplicationId: 'family-large', profileIds: ids,
  }));
  assert.equal((await getDoc(doc(db, 'users', 'large-family'))).data()
      .linkedStudentProfileIds.length, 11);
});

test('selection is limited to linked profiles', async () => {
  const db = auth('parent');
  await createProfiles(db, {
    uid: 'parent', email: 'parent@example.com', role: 'parent',
    familyApplicationId: 'family-1', profileIds: ['parent-profile', 'child-profile'],
  });
  await assertSucceeds(selectProfile(db, 'parent', 'child-profile'));
  await assertFails(selectProfile(db, 'parent', 'unrelated'));
});

test('application is profile-specific, active-location-only, and cannot self-approve', async () => {
  const db = auth('parent');
  await createProfiles(db, {
    uid: 'parent', email: 'parent@example.com', role: 'parent',
    familyApplicationId: 'family-1', profileIds: ['parent-profile', 'child-profile'],
  });
  await assertFails(apply(db, 'parent', 'parent-profile', 'inactive', true));
  await assertSucceeds(apply(db, 'parent', 'parent-profile', 'cheshire', true));
  assert.equal((await getDoc(doc(db, 'studentProfiles', 'child-profile'))).data().approvalStatus,
      'incomplete');
  await assertFails(updateDoc(doc(db, 'studentProfiles', 'parent-profile'), {
    approvalStatus: 'approved', updatedAt: serverTimestamp(),
  }));
  await assertFails(apply(db, 'parent', 'parent-profile', 'other', true));
});

test('admin reviews only pending applications at the assigned location', async () => {
  const studentDb = auth('student');
  await createProfiles(studentDb, {
    uid: 'student', email: 'student@example.com', profileIds: ['profile'],
  });
  await apply(studentDb, 'student', 'profile', 'cheshire', true);
  await seedAdmin('admin');
  await seedAdmin('wrong-admin', 'admin', 'other');
  await assertFails(review(auth('wrong-admin'), 'profile', 'wrong-admin', true));
  await assertSucceeds(review(auth('admin'), 'profile', 'admin', true));
  assert.equal((await getDoc(doc(auth('admin'), 'studentProfiles', 'profile'))).data().approvalStatus,
      'approved');
  await assertFails(review(auth('admin'), 'profile', 'admin', false, 'duplicate'));
});

test('rejection can be reapplied and leave resets only that profile', async () => {
  const db = auth('parent');
  await createProfiles(db, {
    uid: 'parent', email: 'parent@example.com', role: 'parent',
    familyApplicationId: 'family-1', profileIds: ['parent-profile', 'child-profile'],
  });
  await apply(db, 'parent', 'child-profile', 'cheshire', false);
  await seedAdmin('admin');
  await review(auth('admin'), 'child-profile', 'admin', false, 'Try again');
  await assertSucceeds(apply(db, 'parent', 'child-profile', 'other', false));
  await assertSucceeds(leave(db, 'parent', 'child-profile', false));
  const child = (await getDoc(doc(db, 'studentProfiles', 'child-profile'))).data();
  assert.equal(child.approvalStatus, 'incomplete');
  assert.equal('locationId' in child, false);
  assert.equal((await getDoc(doc(db, 'studentProfiles', 'parent-profile'))).data().approvalStatus,
      'incomplete');
});

test('academy content requires approved selected membership at the same active location', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'events', 'cheshire-event'), {title: 'Class', locationId: 'cheshire'});
    await setDoc(doc(db, 'events', 'other-event'), {title: 'Other', locationId: 'other'});
  });
  const db = auth('student');
  await createProfiles(db, {
    uid: 'student', email: 'student@example.com', profileIds: ['profile'],
  });
  await assertFails(getDoc(doc(db, 'events', 'cheshire-event')));
  await apply(db, 'student', 'profile', 'cheshire', true);
  await seedAdmin('admin');
  await review(auth('admin'), 'profile', 'admin', true);
  await assertSucceeds(getDoc(doc(db, 'events', 'cheshire-event')));
  await assertFails(getDoc(doc(db, 'events', 'other-event')));
  const snapshot = await assertSucceeds(getDocs(query(
    collection(db, 'events'), where('locationId', '==', 'cheshire'),
  )));
  assert.equal(snapshot.size, 1);
});

test('super admin can review across locations but cannot broaden user-created relationships', async () => {
  await seedAdmin('super', 'superAdmin', 'cheshire');
  const studentDb = auth('student');
  await createProfiles(studentDb, {
    uid: 'student', email: 'student@example.com', profileIds: ['profile'],
  });
  await apply(studentDb, 'student', 'profile', 'other', true);
  await assertSucceeds(review(auth('super'), 'profile', 'super', true));
  await assertFails(updateDoc(doc(studentDb, 'users', 'student'), {
    linkedStudentProfileIds: ['profile', 'foreign'], updatedAt: serverTimestamp(),
  }));
});

test('linked member observes deactivation but loses academy content access', async () => {
  const db = auth('inactive-member');
  await createProfiles(db, {
    uid: 'inactive-member', email: 'inactive-member@example.com', profileIds: ['profile'],
  });
  await apply(db, 'inactive-member', 'profile', 'cheshire', true);
  await seedAdmin('admin');
  await review(auth('admin'), 'profile', 'admin', true);
  await env.withSecurityRulesDisabled(async (context) => {
    const unrestricted = context.firestore();
    await setDoc(doc(unrestricted, 'events', 'event'), {
      title: 'Event', locationId: 'cheshire',
    });
    await updateDoc(doc(unrestricted, 'locations', 'cheshire'), {isActive: false});
  });
  const location = await assertSucceeds(getDoc(doc(db, 'locations', 'cheshire')));
  assert.equal(location.data().isActive, false);
  await assertFails(getDoc(doc(db, 'events', 'event')));
});

test('inactive locations cannot be listed for apply or reviewed by an admin', async () => {
  const db = auth('pending-member');
  const activeLocations = await assertSucceeds(getDocs(query(
    collection(db, 'locations'), where('isActive', '==', true),
  )));
  assert.deepEqual(activeLocations.docs.map((item) => item.id).sort(), ['cheshire', 'other']);
  await assertFails(getDocs(collection(db, 'locations')));

  await createProfiles(db, {
    uid: 'pending-member', email: 'pending-member@example.com', profileIds: ['profile'],
  });
  await apply(db, 'pending-member', 'profile', 'cheshire', true);
  await seedAdmin('admin');
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'locations', 'cheshire'), {isActive: false});
  });
  await assertFails(review(auth('admin'), 'profile', 'admin', true));
});

test('admins cannot write academy content at an inactive location', async () => {
  await seedAdmin('inactive-admin', 'admin', 'inactive');
  const db = auth('inactive-admin');
  await assertFails(setDoc(doc(db, 'events', 'new-event'), {
    title: 'Blocked', locationId: 'inactive',
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'events', 'old-event'), {
      title: 'Existing', locationId: 'inactive',
    });
  });
  await assertFails(getDoc(doc(db, 'events', 'old-event')));
  await assertFails(updateDoc(doc(db, 'events', 'old-event'), {title: 'Changed'}));
});

test('super admin reads inactive status without receiving inactive content access', async () => {
  await seedAdmin('super-inactive', 'superAdmin');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'events', 'inactive-event'), {
      title: 'Inactive', locationId: 'inactive',
    });
  });
  const db = auth('super-inactive');
  await assertSucceeds(getDoc(doc(db, 'locations', 'inactive')));
  await assertFails(getDoc(doc(db, 'events', 'inactive-event')));
  await assertFails(setDoc(doc(db, 'events', 'new-inactive-event'), {
    title: 'Blocked', locationId: 'inactive',
  }));
  await assertFails(updateDoc(doc(db, 'events', 'inactive-event'), {title: 'Changed'}));
  await assertFails(deleteDoc(doc(db, 'events', 'inactive-event')));
});

test('super admin scoped content queries survive inactive documents', async () => {
  await seedAdmin('super-active', 'superAdmin');
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'events', 'cheshire-event'), {title: 'One', locationId: 'cheshire'});
    await setDoc(doc(db, 'events', 'other-event'), {title: 'Two', locationId: 'other'});
    await setDoc(doc(db, 'events', 'inactive-event'), {title: 'Hidden', locationId: 'inactive'});
  });
  const db = auth('super-active');
  const cheshire = await assertSucceeds(getDocs(query(
    collection(db, 'events'), where('locationId', '==', 'cheshire'),
  )));
  const other = await assertSucceeds(getDocs(query(
    collection(db, 'events'), where('locationId', '==', 'other'),
  )));
  await assertFails(getDocs(query(
    collection(db, 'events'), where('locationId', '==', 'inactive'),
  )));
  assert.deepEqual([...cheshire.docs, ...other.docs].map((item) => item.id).sort(), [
    'cheshire-event', 'other-event',
  ]);
});
