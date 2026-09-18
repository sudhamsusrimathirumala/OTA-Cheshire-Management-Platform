const assert = require("node:assert/strict");
const test = require("node:test");

const {
  safeErrorMessage,
  validateExistingIdentity,
} = require("../scripts/provision_guest_account.cjs");

test("new reviewer identities do not require password rotation", () => {
  assert.doesNotThrow(() => validateExistingIdentity({
    created: true,
    existingDocument: false,
    existingRole: null,
    authDisabled: true,
    hasGuestClaim: false,
    hasPasswordProvider: true,
    adoptDisabled: false,
    rotate: false,
  }));
});

test("existing guest identities require explicit password rotation", () => {
  assert.throws(() => validateExistingIdentity({
    created: false,
    existingDocument: true,
    existingRole: "guest",
    authDisabled: false,
    hasGuestClaim: true,
    hasPasswordProvider: true,
    adoptDisabled: false,
    rotate: false,
  }), /--rotate-password/);
  assert.doesNotThrow(() => validateExistingIdentity({
    created: false,
    existingDocument: true,
    existingRole: "guest",
    authDisabled: false,
    hasGuestClaim: true,
    hasPasswordProvider: true,
    adoptDisabled: false,
    rotate: true,
  }));
});

test("existing real accounts are never adopted or overwritten", () => {
  for (const role of ["admin", "superAdmin", "parent", "student"]) {
    assert.throws(() => validateExistingIdentity({
      created: false,
      existingDocument: true,
      existingRole: role,
      authDisabled: true,
      hasGuestClaim: false,
      hasPasswordProvider: true,
      adoptDisabled: true,
      rotate: true,
    }), /non-guest OTA account/);
  }
});

test("incomplete identities require explicit disabled-state adoption", () => {
  assert.throws(() => validateExistingIdentity({
    created: false,
    existingDocument: false,
    existingRole: null,
    authDisabled: false,
    hasGuestClaim: false,
    hasPasswordProvider: true,
    adoptDisabled: true,
    rotate: true,
  }), /Refusing to adopt/);
  assert.throws(() => validateExistingIdentity({
    created: false,
    existingDocument: false,
    existingRole: null,
    authDisabled: true,
    hasGuestClaim: false,
    hasPasswordProvider: true,
    adoptDisabled: false,
    rotate: true,
  }), /Refusing to adopt/);
  assert.doesNotThrow(() => validateExistingIdentity({
    created: false,
    existingDocument: false,
    existingRole: null,
    authDisabled: true,
    hasGuestClaim: false,
    hasPasswordProvider: true,
    adoptDisabled: true,
    rotate: true,
  }));
});

test("incomplete guest metadata requires disabled-state adoption", () => {
  const identity = {
    created: false,
    existingDocument: true,
    existingRole: "guest",
    hasGuestClaim: false,
    hasPasswordProvider: true,
    adoptDisabled: true,
    rotate: true,
  };
  assert.throws(() => validateExistingIdentity({
    ...identity,
    authDisabled: false,
  }), /incomplete reviewer identity/);
  assert.doesNotThrow(() => validateExistingIdentity({
    ...identity,
    authDisabled: true,
  }));
});

test("existing non-password identities are never adopted", () => {
  assert.throws(() => validateExistingIdentity({
    created: false,
    existingDocument: true,
    existingRole: "guest",
    authDisabled: true,
    hasGuestClaim: false,
    hasPasswordProvider: false,
    adoptDisabled: true,
    rotate: true,
  }), /not an email\/password reviewer account/);
});

test("unexpected Firebase errors never expose their message text", () => {
  const secret = "reviewer+secret@example.com password-value";
  assert.equal(
    safeErrorMessage({code: "auth/internal-error", message: secret}),
    "Firebase operation failed (auth/internal-error).",
  );
  assert.equal(
    safeErrorMessage(new Error(secret)),
    "An unexpected provisioning operation failed.",
  );
});
