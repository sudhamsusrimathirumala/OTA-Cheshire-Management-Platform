const test = require("node:test");
const assert = require("node:assert/strict");

const {
  buildApplicationDocuments,
  parseOnboardingInput,
  trustedIdentityFromAuth,
} = require("../src/onboarding");

const now = new Date("2026-07-13T16:00:00.000Z");
const identity = {
  uid: "firebase-uid",
  email: "parent@example.com",
  googleAccountId: "google-provider-uid",
};

function studentRequest(overrides = {}) {
  return {
    firstName: "Independent",
    lastName: "Student",
    dateOfBirth: "2005-07-13",
    beltRank: "Blue",
    role: "student",
    locationId: "ota-cheshire",
    guardianEmail: " Guardian@Example.com ",
    ...overrides,
  };
}

function parentRequest(overrides = {}) {
  return {
    firstName: "Pat",
    lastName: "Parent",
    dateOfBirth: "1985-01-02",
    role: "parent",
    locationId: "ota-cheshire",
    parentIsStudent: false,
    additionalStudents: [
      {
        firstName: "Child",
        lastName: "One",
        dateOfBirth: "2015-03-04",
        beltRank: "Yellow",
        guardianEmail: " Parent@Example.com ",
      },
    ],
    ...overrides,
  };
}

function build(data, profileIds, familyApplicationId) {
  return buildApplicationDocuments({
    identity,
    input: parseOnboardingInput(data),
    timeZoneId: "America/New_York",
    now,
    profileIds,
    familyApplicationId,
  });
}

test("student application creates one reciprocal self profile", () => {
  const plan = build(studentRequest(), ["student-profile"]);
  assert.deepEqual(plan.user.linkedStudentProfileIds, ["student-profile"]);
  assert.equal(plan.user.selectedStudentProfileId, "student-profile");
  assert.equal(plan.user.email, "parent@example.com");
  assert.equal(plan.user.googleAccountId, "google-provider-uid");
  assert.equal(plan.profiles[0].data.linkedUserId, "firebase-uid");
  assert.deepEqual(plan.profiles[0].data.guardianUserIds, []);
  assert.equal(plan.profiles[0].data.guardianEmail, "guardian@example.com");
  assert.equal(plan.profiles[0].data.approvalStatus, "pending");
});

test("parent with one child shares one family application ID", () => {
  const plan = build(parentRequest(), ["child-profile"], "family-123");
  assert.equal(plan.user.familyApplicationId, "family-123");
  assert.equal(plan.profiles[0].data.familyApplicationId, "family-123");
  assert.deepEqual(plan.profiles[0].data.guardianUserIds, ["firebase-uid"]);
  assert.equal(plan.profiles[0].data.linkedUserId, undefined);
  assert.deepEqual(plan.user.linkedStudentProfileIds, ["child-profile"]);
});

test("parent who is also a student selects the own profile", () => {
  const plan = build(
    parentRequest({parentIsStudent: true, beltRank: "Black"}),
    ["parent-profile", "child-profile"],
    "family-123",
  );
  assert.equal(plan.user.selectedStudentProfileId, "parent-profile");
  assert.equal(plan.profiles[0].data.linkedUserId, "firebase-uid");
  assert.deepEqual(plan.profiles[0].data.guardianUserIds, []);
  assert.equal(plan.profiles[0].data.guardianEmail, identity.email);
  assert.deepEqual(plan.profiles[1].data.guardianUserIds, ["firebase-uid"]);
});

test("parent with multiple children links every profile reciprocally", () => {
  const secondChild = {
    firstName: "Child",
    lastName: "Two",
    dateOfBirth: "2017-05-06",
    beltRank: "White",
    guardianEmail: "second@example.com",
  };
  const plan = build(
    parentRequest({
      additionalStudents: [
        parentRequest().additionalStudents[0],
        secondChild,
      ],
    }),
    ["child-one", "child-two"],
    "family-456",
  );
  assert.deepEqual(plan.user.linkedStudentProfileIds, [
    "child-one",
    "child-two",
  ]);
  assert.equal(plan.profiles.length, 2);
  assert.ok(plan.profiles.every((profile) =>
    profile.data.familyApplicationId === "family-456"));
});

test("under-16 account holder is rejected using academy-local date", () => {
  assert.throws(
    () => build(studentRequest({dateOfBirth: "2010-07-14"}), ["profile"]),
    (error) => error.details.reason === "invalid-age",
  );
});

test("invalid guardian email is rejected", () => {
  assert.throws(
    () => parseOnboardingInput(studentRequest({guardianEmail: "not-email"})),
    (error) => error.code === "invalid-argument",
  );
});

test("parent without any student profile is rejected", () => {
  assert.throws(
    () => parseOnboardingInput(parentRequest({additionalStudents: []})),
    (error) => error.code === "invalid-argument",
  );
});

test("Google provider ID comes only from authenticated provider data", () => {
  const authIdentity = trustedIdentityFromAuth({
    uid: "firebase-uid",
    token: {
      email: " Contact@Example.com ",
      firebase: {identities: {"google.com": ["google-provider-uid"]}},
    },
  });
  const passwordIdentity = trustedIdentityFromAuth({
    uid: "firebase-uid",
    token: {
      email: "contact@example.com",
      firebase: {identities: {email: ["contact@example.com"]}},
    },
  });
  assert.equal(authIdentity.uid, "firebase-uid");
  assert.equal(authIdentity.email, "contact@example.com");
  assert.equal(authIdentity.googleAccountId, "google-provider-uid");
  assert.equal(passwordIdentity.googleAccountId, undefined);
});

test("privileged identity and relationship fields are rejected", () => {
  for (const privilegedField of [
    "uid",
    "email",
    "googleAccountId",
    "approvalStatus",
    "familyApplicationId",
    "linkedStudentProfileIds",
    "guardianUserIds",
    "linkedUserId",
  ]) {
    assert.throws(
      () => parseOnboardingInput({
        ...studentRequest(),
        [privilegedField]: "client-value",
      }),
      (error) => error.code === "invalid-argument",
    );
  }
});
