const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

test("client rules block direct onboarding relationship writes", {skip: !emulatorAvailable}, async () => {
  const [host, portText] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
  const environment = await initializeTestEnvironment({
    projectId: "demo-ota-onboarding",
    firestore: {
      host,
      port: Number(portText),
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8",
      ),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "pending-user"), {
      firstName: "Pending",
      lastName: "User",
      email: "pending@example.com",
      role: "parent",
      approvalStatus: "pending",
      locationId: "ota-cheshire",
      linkedStudentProfileIds: [],
    });
    await setDoc(doc(db, "resources", "normal-data"), {
      locationId: "ota-cheshire",
    });
    await setDoc(doc(db, "users", "location-admin"), {
      firstName: "Location",
      lastName: "Admin",
      email: "admin@example.com",
      role: "admin",
      approvalStatus: "approved",
      locationId: "ota-cheshire",
      linkedStudentProfileIds: [],
    });
    await setDoc(doc(db, "studentProfiles", "managed-profile"), {
      locationId: "ota-cheshire",
      approvalStatus: "pending",
      guardianUserIds: ["pending-user"],
    });
  });

  const pendingDb = environment.authenticatedContext("pending-user").firestore();
  await assertSucceeds(getDoc(doc(pendingDb, "users", "pending-user")));
  await assertSucceeds(updateDoc(doc(pendingDb, "users", "pending-user"), {
    phoneNumber: "203-555-0100",
  }));
  await assertFails(updateDoc(doc(pendingDb, "users", "pending-user"), {
    linkedStudentProfileIds: ["client-created-profile"],
  }));
  await assertFails(updateDoc(doc(pendingDb, "users", "pending-user"), {
    familyApplicationId: "client-family",
  }));
  await assertFails(updateDoc(doc(pendingDb, "users", "pending-user"), {
    googleAccountId: "client-google-id",
  }));
  await assertFails(updateDoc(doc(pendingDb, "users", "pending-user"), {
    role: "admin",
    approvalStatus: "approved",
  }));
  await assertFails(setDoc(doc(pendingDb, "studentProfiles", "client-profile"), {
    locationId: "ota-cheshire",
    guardianUserIds: ["pending-user"],
    linkedUserId: "pending-user",
    approvalStatus: "pending",
  }));
  await assertFails(getDoc(doc(pendingDb, "resources", "normal-data")));

  const adminDb = environment.authenticatedContext("location-admin").firestore();
  await assertSucceeds(updateDoc(doc(adminDb, "users", "pending-user"), {
    approvalStatus: "approved",
  }));
  await assertSucceeds(updateDoc(doc(adminDb, "studentProfiles", "managed-profile"), {
    approvalStatus: "approved",
  }));
  await assertFails(updateDoc(doc(adminDb, "studentProfiles", "managed-profile"), {
    guardianUserIds: ["location-admin"],
  }));
  assert.ok(true);
  await environment.cleanup();
});
