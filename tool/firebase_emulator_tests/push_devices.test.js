import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, serverTimestamp, setDoc} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-push-devices';
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
    await setDoc(doc(db, 'users', 'owner'), account(true));
    await setDoc(doc(db, 'users', 'other'), account(true));
    await setDoc(doc(db, 'users', 'disabled'), account(false));
  });
});

after(async () => env.cleanup());

function account(isActive) {
  return {
    firstName: 'Family', lastName: 'Member', email: 'family@example.com',
    role: 'parent', isActive, locationId: 'cheshire',
    linkedStudentProfileIds: ['student'], selectedStudentProfileId: 'student',
    createdAt: new Date(), updatedAt: new Date(),
  };
}

function auth(uid) {
  return env.authenticatedContext(uid, {email: `${uid}@example.com`}).firestore();
}

function registration(overrides = {}) {
  return {
    fcmToken: 'token-value', platform: 'android', appEnvironment: 'dev',
    enabled: true, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    lastSeenAt: serverTimestamp(), ...overrides,
  };
}

test('active owner can create and read a valid device registration', async () => {
  const reference = doc(auth('owner'), 'users', 'owner', 'pushDevices', 'install-1');
  await assertSucceeds(setDoc(reference, registration()));
  await assertSucceeds(getDoc(reference));
});

test('cross-user device registration is denied', async () => {
  const reference = doc(auth('other'), 'users', 'owner', 'pushDevices', 'install-1');
  await assertFails(setDoc(reference, registration()));
  await assertFails(getDoc(reference));
});

test('disabled account cannot register a device', async () => {
  const reference = doc(auth('disabled'), 'users', 'disabled', 'pushDevices', 'install-1');
  await assertFails(setDoc(reference, registration()));
});

test('device registration rejects extra fields and invalid platform values', async () => {
  const db = auth('owner');
  await assertFails(setDoc(
    doc(db, 'users', 'owner', 'pushDevices', 'extra'),
    registration({deviceName: 'personal phone'}),
  ));
  await assertFails(setDoc(
    doc(db, 'users', 'owner', 'pushDevices', 'platform'),
    registration({platform: 'windows'}),
  ));
});

test('clients cannot read or write dispatch records', async () => {
  const reference = doc(auth('owner'), 'pushDispatches', 'announcement_1');
  await assertFails(setDoc(reference, {status: 'completed'}));
  await assertFails(getDoc(reference));
});
