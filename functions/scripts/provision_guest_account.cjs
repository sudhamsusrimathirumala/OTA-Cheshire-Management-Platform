#!/usr/bin/env node

/*
 * Provisions the single OTA reviewer identity. This tool is deliberately
 * apply-gated and reads credentials only from the process environment.
 * It never marks the email verified and never prints the email or password.
 */

const {applicationDefault, getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

const args = new Set(process.argv.slice(2));
const valueFor = (prefix) => process.argv.slice(2)
  .find((value) => value.startsWith(`${prefix}=`))?.slice(prefix.length + 1);
const projectId = valueFor("--project");
const confirmedProjectId = valueFor("--confirm-project");
const apply = args.has("--apply");
const adoptDisabledAuth = args.has("--adopt-disabled-auth");
const email = process.env.OTA_GUEST_EMAIL?.trim().toLowerCase();
const password = process.env.OTA_GUEST_PASSWORD;

function fail(message) {
  console.error(`Guest provisioning stopped: ${message}`);
  process.exitCode = 1;
}

async function main() {
  if (!projectId || projectId !== confirmedProjectId) {
    fail("--project and --confirm-project must contain the same explicit Firebase project ID.");
    return;
  }
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    fail("OTA_GUEST_EMAIL must contain a valid academy-controlled address.");
    return;
  }
  if (!password || password.length < 16) {
    fail("OTA_GUEST_PASSWORD must contain at least 16 characters.");
    return;
  }
  if (!apply) {
    console.log("Dry run only: inputs are valid; no Firebase connection or mutation was attempted.");
    console.log("Re-run with --apply after deployment approval and credential review.");
    return;
  }

  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId});
  }
  const auth = getAuth();
  const firestore = getFirestore();
  let user;
  let created = false;
  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
    user = await auth.createUser({
      email,
      password,
      disabled: true,
      emailVerified: false,
      displayName: "OTA App Reviewer",
    });
    created = true;
  }

  if (user.email?.toLowerCase() !== email) {
    throw new Error("The existing Auth identity does not match the requested address.");
  }
  const userRef = firestore.collection("users").doc(user.uid);
  const existing = await userRef.get();
  if (existing.exists && existing.get("role") !== "guest") {
    throw new Error("The existing UID belongs to a non-guest OTA account.");
  }
  if (!created && !existing.exists && user.customClaims?.otaGuest !== true) {
    if (!adoptDisabledAuth || user.disabled !== true) {
      throw new Error(
        "The email already belongs to an unprovisioned Auth identity. Refusing to adopt it.",
      );
    }
  }

  await auth.updateUser(user.uid, {disabled: true});
  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims ?? {}),
    otaGuest: true,
  });
  await userRef.set({
    firstName: "OTA",
    lastName: "Reviewer",
    email,
    role: "guest",
    isActive: true,
    linkedStudentProfileIds: [],
    ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await auth.updateUser(user.uid, {disabled: false});

  console.log("Guest reviewer identity provisioned successfully.");
  console.log("The email remains unverified and no credentials were printed.");
}

main().catch((error) => {
  fail(error instanceof Error ? error.message : "unknown provisioning failure");
});
