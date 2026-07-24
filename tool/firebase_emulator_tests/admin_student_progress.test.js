import fs from 'node:fs';
import {after, before, test} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-active-access';
let env;

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')}});
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'locations', 'cheshire'), {name: 'Cheshire', isActive: true, timeZoneId: 'America/New_York'});
    await setDoc(doc(db, 'locations', 'other'), {name: 'Other', isActive: true, timeZoneId: 'America/Chicago'});
    for (const [id, locationId] of [['admin', 'cheshire'], ['other-admin', 'other'], ['parent', 'cheshire'], ['student', 'cheshire']]) {
      const profileIds = id === 'parent' ? ['parent-profile'] : id === 'student' ? ['student-profile'] : [];
      await setDoc(doc(db, 'users', id), {firstName: id, lastName: 'User', email: `${id}@example.com`, role: id.includes('admin') ? 'admin' : id, isActive: true, locationId, linkedStudentProfileIds: profileIds, ...(profileIds.length ? {selectedStudentProfileId: profileIds[0]} : {}), createdAt: new Date(), updatedAt: new Date()});
    }
    for (const id of ['parent-profile', 'student-profile']) {
      await setDoc(doc(db, 'studentProfiles', id), {firstName: 'Student', lastName: id, dateOfBirth: new Date('2010-01-01'), beltRank: 'White', locationId: 'cheshire', guardianEmail: 'parent@example.com', guardianUserIds: [], preferredClassGroupIds: [], stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'}, promotionHistory: [], testingNotes: [], isActive: true, createdAt: new Date(), updatedAt: new Date()});
    }
  });
});

after(async () => env.cleanup());
const auth = (uid) => env.authenticatedContext(uid, {email: `${uid}@example.com`}).firestore();

test('admin progress update is same-location and admin-only for unlinked profiles', async () => {
  const progress = {beltRank: 'Green', stickerProgress: {current: 2, required: 5, nextRank: 'Green-Blue'}, updatedAt: serverTimestamp()};
  await assertSucceeds(updateDoc(doc(auth('admin'), 'studentProfiles', 'parent-profile'), progress));
  await assertFails(updateDoc(doc(auth('other-admin'), 'studentProfiles', 'parent-profile'), progress));
  await assertFails(updateDoc(doc(auth('parent'), 'studentProfiles', 'student-profile'), progress));
  await assertFails(updateDoc(doc(auth('student'), 'studentProfiles', 'parent-profile'), progress));
  await assertFails(updateDoc(doc(auth('admin'), 'studentProfiles', 'parent-profile'), {...progress, locationId: 'other'}));
});
