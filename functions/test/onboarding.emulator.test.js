const test = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

const {submitOnboardingApplicationCore} = require("../src/onboarding");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = process.env.GCLOUD_PROJECT || "demo-ota-onboarding";

function baseIdentity(uid) {
  return {uid, email: `${uid}@example.com`, googleAccountId: undefined};
}

function studentData(overrides = {}) {
  return {
    firstName: "Student",
    lastName: "Applicant",
    dateOfBirth: "2000-01-01",
    beltRank: "Blue",
    role: "student",
    locationId: "active-location",
    guardianEmail: "guardian@example.com",
    ...overrides,
  };
}

test("callable core commits user and profile atomically", {skip: !emulatorAvailable}, async () => {
  const app = initializeApp({projectId}, `atomic-success-${Date.now()}`);
  const db = getFirestore(app);
  await db.collection("locations").doc("active-location").set({
    isActive: true,
    timeZoneId: "America/New_York",
  });
  const result = await submitOnboardingApplicationCore({
    db,
    identity: baseIdentity("atomic-user"),
    data: studentData(),
    now: new Date("2026-07-13T12:00:00Z"),
  });
  const user = await db.collection("users").doc("atomic-user").get();
  const profile = await db.collection("studentProfiles")
    .doc(result.studentProfileIds[0]).get();
  assert.equal(user.exists, true);
  assert.equal(profile.exists, true);
  assert.equal(user.id, "atomic-user");
  assert.notEqual(user.id, user.data().email);
  assert.equal(profile.data().linkedUserId, "atomic-user");
  await deleteApp(app);
});

test("duplicate and inactive-location submissions are rejected", {skip: !emulatorAvailable}, async () => {
  const app = initializeApp({projectId}, `rejections-${Date.now()}`);
  const db = getFirestore(app);
  await db.collection("locations").doc("active-location").set({
    isActive: true,
    timeZoneId: "America/New_York",
  });
  await db.collection("locations").doc("inactive-location").set({
    isActive: false,
    timeZoneId: "America/New_York",
  });
  await db.collection("users").doc("duplicate-user").set({existing: true});
  await assert.rejects(
    submitOnboardingApplicationCore({
      db,
      identity: baseIdentity("duplicate-user"),
      data: studentData(),
    }),
    (error) => error.code === "already-exists",
  );
  await assert.rejects(
    submitOnboardingApplicationCore({
      db,
      identity: baseIdentity("inactive-user"),
      data: studentData({locationId: "inactive-location"}),
    }),
    (error) => error.details.reason === "invalid-location",
  );
  await deleteApp(app);
});

test("failed profile create leaves no partial family application", {skip: !emulatorAvailable}, async () => {
  const app = initializeApp({projectId}, `atomic-failure-${Date.now()}`);
  const db = getFirestore(app);
  await db.collection("locations").doc("active-location").set({
    isActive: true,
    timeZoneId: "America/New_York",
  });
  const firstRef = db.collection("studentProfiles").doc("atomic-first");
  const conflictingRef = db.collection("studentProfiles").doc("atomic-conflict");
  await conflictingRef.set({existing: true});
  const refs = [firstRef, conflictingRef];
  let index = 0;
  await assert.rejects(submitOnboardingApplicationCore({
    db,
    identity: baseIdentity("atomic-family-user"),
    data: {
      firstName: "Parent",
      lastName: "Applicant",
      dateOfBirth: "1980-01-01",
      role: "parent",
      locationId: "active-location",
      additionalStudents: [
        {
          firstName: "Child",
          lastName: "One",
          dateOfBirth: "2015-01-01",
          beltRank: "Yellow",
          guardianEmail: "guardian@example.com",
        },
        {
          firstName: "Child",
          lastName: "Two",
          dateOfBirth: "2017-01-01",
          beltRank: "White",
          guardianEmail: "guardian@example.com",
        },
      ],
    },
    allocateProfileRef: () => refs[index++],
  }));
  const user = await db.collection("users").doc("atomic-family-user").get();
  const firstProfile = await firstRef.get();
  assert.equal(user.exists, false);
  assert.equal(firstProfile.exists, false);
  assert.equal((await conflictingRef.get()).exists, true);
  await deleteApp(app);
});
