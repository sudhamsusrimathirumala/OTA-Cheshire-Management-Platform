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
const rotatePassword = args.has("--rotate-password");
const email = process.env.OTA_GUEST_EMAIL?.trim().toLowerCase();
const password = process.env.OTA_GUEST_PASSWORD;

class SafeProvisioningError extends Error {}

function fail(message) {
  console.error(`Guest provisioning stopped: ${message}`);
  process.exitCode = 1;
}

function safeErrorMessage(error) {
  if (error instanceof SafeProvisioningError) return error.message;
  const code = typeof error?.code === "string" &&
      /^[a-z0-9_/-]+$/i.test(error.code) ? error.code : null;
  return code ? `Firebase operation failed (${code}).` :
    "An unexpected provisioning operation failed.";
}

function validateExistingIdentity({
  created,
  existingDocument,
  existingRole,
  authDisabled,
  hasGuestClaim,
  hasPasswordProvider,
  adoptDisabled,
  rotate,
}) {
  if (created) return;
  if (existingDocument && existingRole !== "guest") {
    throw new SafeProvisioningError(
      "The existing identity belongs to a non-guest OTA account.",
    );
  }
  if (!hasPasswordProvider) {
    throw new SafeProvisioningError(
      "The existing identity is not an email/password reviewer account.",
    );
  }
  const incompleteGuest = !existingDocument || !hasGuestClaim;
  if (incompleteGuest && (!adoptDisabled || !authDisabled)) {
    throw new SafeProvisioningError(
      "The email belongs to an incomplete reviewer identity. Refusing to adopt it.",
    );
  }
  if (!rotate) {
    throw new SafeProvisioningError(
      "An existing reviewer identity requires --rotate-password before it can be enabled.",
    );
  }
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
  validateExistingIdentity({
    created,
    existingDocument: existing.exists,
    existingRole: existing.exists ? existing.get("role") : null,
    authDisabled: user.disabled === true,
    hasGuestClaim: user.customClaims?.otaGuest === true,
    hasPasswordProvider: user.providerData.some(
      (provider) => provider.providerId === "password",
    ),
    adoptDisabled: adoptDisabledAuth,
    rotate: rotatePassword,
  });

  await auth.updateUser(user.uid, {disabled: true});
  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims ?? {}),
    otaGuest: true,
  });
  const existingCreatedAt = existing.exists ? existing.get("createdAt") : null;
  await userRef.set({
    firstName: "OTA",
    lastName: "Reviewer",
    email,
    role: "guest",
    isActive: true,
    linkedStudentProfileIds: [],
    createdAt: existingCreatedAt ?? FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await auth.updateUser(user.uid, {
    disabled: false,
    ...(!created ? {password} : {}),
  });

  console.log("Guest reviewer identity provisioned successfully.");
  console.log("The email remains unverified and no credentials were printed.");
}

if (require.main === module) {
  main().catch((error) => fail(safeErrorMessage(error)));
}

module.exports = {safeErrorMessage, validateExistingIdentity};
