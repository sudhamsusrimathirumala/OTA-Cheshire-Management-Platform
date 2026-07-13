const {randomUUID} = require("node:crypto");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const USER_FIELDS = new Set([
  "firstName",
  "lastName",
  "dateOfBirth",
  "beltRank",
  "phoneNumber",
  "role",
  "locationId",
  "guardianEmail",
  "parentIsStudent",
  "additionalStudents",
]);

const STUDENT_FIELDS = new Set([
  "firstName",
  "lastName",
  "dateOfBirth",
  "beltRank",
  "guardianEmail",
]);

const PRIVILEGED_FIELDS = new Set([
  "uid",
  "firebaseUid",
  "email",
  "accountEmail",
  "googleAccountId",
  "approvalStatus",
  "familyApplicationId",
  "linkedStudentProfileIds",
  "guardianUserIds",
  "linkedUserId",
  "selectedStudentProfileId",
]);

function normalizeEmail(value, fieldName = "email") {
  const email = requiredString(value, fieldName).toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw invalidData(`${fieldName} must be a valid email address.`);
  }
  return email;
}

function optionalString(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") throw invalidData("Expected a string value.");
  const result = value.trim();
  return result.length === 0 ? undefined : result;
}

function requiredString(value, fieldName) {
  const result = optionalString(value);
  if (result === undefined) throw invalidData(`${fieldName} is required.`);
  return result;
}

function parseBirthDate(value, fieldName = "dateOfBirth") {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw invalidData(`${fieldName} must use YYYY-MM-DD.`);
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) {
    throw invalidData(`${fieldName} is not a valid calendar date.`);
  }
  return {isoDate: value, date};
}

function assertAllowedKeys(value, allowed, fieldName) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw invalidData(`${fieldName} must be an object.`);
  }
  for (const key of Object.keys(value)) {
    if (PRIVILEGED_FIELDS.has(key)) {
      throw invalidData(`${key} is server-controlled and cannot be submitted.`);
    }
    if (!allowed.has(key)) {
      throw invalidData(`${key} is not an accepted onboarding field.`);
    }
  }
}

function parseStudent(value, fieldName) {
  assertAllowedKeys(value, STUDENT_FIELDS, fieldName);
  return {
    firstName: requiredString(value.firstName, `${fieldName}.firstName`),
    lastName: requiredString(value.lastName, `${fieldName}.lastName`),
    dateOfBirth: parseBirthDate(value.dateOfBirth, `${fieldName}.dateOfBirth`),
    beltRank: requiredString(value.beltRank, `${fieldName}.beltRank`),
    guardianEmail: normalizeEmail(
      value.guardianEmail,
      `${fieldName}.guardianEmail`,
    ),
  };
}

function parseOnboardingInput(data) {
  assertAllowedKeys(data, USER_FIELDS, "request");
  const role = requiredString(data.role, "role");
  if (role !== "student" && role !== "parent") {
    throw invalidData("role must be student or parent.");
  }
  const parentIsStudent = data.parentIsStudent === true;
  if (data.parentIsStudent !== undefined && typeof data.parentIsStudent !== "boolean") {
    throw invalidData("parentIsStudent must be a boolean.");
  }
  const additionalValues = data.additionalStudents ?? [];
  if (!Array.isArray(additionalValues)) {
    throw invalidData("additionalStudents must be a list.");
  }
  const additionalStudents = additionalValues.map((value, index) =>
    parseStudent(value, `additionalStudents[${index}]`),
  );
  if (role === "student" && (parentIsStudent || additionalStudents.length > 0)) {
    throw invalidData("Student applications cannot include parent profiles.");
  }
  if (role === "parent" && !parentIsStudent && additionalStudents.length === 0) {
    throw invalidData("A parent application must include at least one student.");
  }

  const applicantBirthDate = parseBirthDate(data.dateOfBirth);
  const beltRank = optionalString(data.beltRank);
  if ((role === "student" || parentIsStudent) && beltRank === undefined) {
    throw invalidData("beltRank is required for the applicant profile.");
  }
  const guardianEmail = optionalString(data.guardianEmail);
  if (role === "student" && guardianEmail === undefined) {
    throw invalidData("guardianEmail is required for an independent student.");
  }

  return {
    firstName: requiredString(data.firstName, "firstName"),
    lastName: requiredString(data.lastName, "lastName"),
    dateOfBirth: applicantBirthDate,
    beltRank,
    phoneNumber: optionalString(data.phoneNumber),
    role,
    locationId: requiredString(data.locationId, "locationId"),
    guardianEmail:
      guardianEmail === undefined ? undefined : normalizeEmail(guardianEmail),
    parentIsStudent,
    additionalStudents,
  };
}

function trustedIdentityFromAuth(auth) {
  if (!auth || typeof auth.uid !== "string" || auth.uid.trim().length === 0) {
    throw new HttpsError("unauthenticated", "Authentication is required.", {
      reason: "unauthenticated",
    });
  }
  const email = normalizeEmail(auth.token && auth.token.email, "Auth email");
  const firebaseClaim = auth.token && auth.token.firebase;
  const identities = firebaseClaim && firebaseClaim.identities;
  const googleValues = identities && identities["google.com"];
  const googleAccountId = Array.isArray(googleValues)
    ? optionalString(googleValues[0])
    : undefined;
  return {uid: auth.uid, email, googleAccountId};
}

function academyDateParts(instant, timeZoneId) {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timeZoneId,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).formatToParts(instant);
    return Object.fromEntries(
      parts.filter((part) => part.type !== "literal").map((part) => [
        part.type,
        Number(part.value),
      ]),
    );
  } catch {
    throw invalidLocation("The selected location has an invalid time zone.");
  }
}

function ageOnAcademyDate(birthDate, instant, timeZoneId) {
  const academyDate = academyDateParts(instant, timeZoneId);
  const [year, month, day] = birthDate.isoDate.split("-").map(Number);
  let age = academyDate.year - year;
  if (academyDate.month < month ||
      (academyDate.month === month && academyDate.day < day)) {
    age -= 1;
  }
  return age;
}

function buildApplicationDocuments({
  identity,
  input,
  timeZoneId,
  now,
  profileIds,
  familyApplicationId,
}) {
  if (ageOnAcademyDate(input.dateOfBirth, now, timeZoneId) < 16) {
    throw new HttpsError(
      "failed-precondition",
      "The account holder must be at least 16.",
      {reason: "invalid-age"},
    );
  }

  const profileTemplates = [];
  if (input.role === "student") {
    profileTemplates.push({
      firstName: input.firstName,
      lastName: input.lastName,
      dateOfBirth: input.dateOfBirth,
      beltRank: input.beltRank,
      guardianEmail: input.guardianEmail,
      guardianUserIds: [],
      linkedUserId: identity.uid,
    });
  } else {
    if (input.parentIsStudent) {
      profileTemplates.push({
        firstName: input.firstName,
        lastName: input.lastName,
        dateOfBirth: input.dateOfBirth,
        beltRank: input.beltRank,
        guardianEmail: identity.email,
        guardianUserIds: [],
        linkedUserId: identity.uid,
      });
    }
    for (const student of input.additionalStudents) {
      profileTemplates.push({
        ...student,
        guardianUserIds: [identity.uid],
      });
    }
  }
  if (profileTemplates.length !== profileIds.length) {
    throw new Error("Profile ID allocation did not match the validated request.");
  }

  const familyFields = input.role === "parent" ? {familyApplicationId} : {};
  const profiles = profileTemplates.map((profile, index) => ({
    id: profileIds[index],
    data: {
      firstName: profile.firstName,
      lastName: profile.lastName,
      dateOfBirth: Timestamp.fromDate(profile.dateOfBirth.date),
      beltRank: profile.beltRank,
      locationId: input.locationId,
      guardianEmail: profile.guardianEmail,
      guardianUserIds: profile.guardianUserIds,
      approvalStatus: "pending",
      ...(profile.linkedUserId ? {linkedUserId: profile.linkedUserId} : {}),
      ...familyFields,
      preferredClassGroupIds: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  }));

  const selectedStudentProfileId = profileIds[0];
  return {
    user: {
      firstName: input.firstName,
      lastName: input.lastName,
      email: identity.email,
      role: input.role,
      approvalStatus: "pending",
      locationId: input.locationId,
      linkedStudentProfileIds: profileIds,
      selectedStudentProfileId,
      ...(input.phoneNumber ? {phoneNumber: input.phoneNumber} : {}),
      ...(identity.googleAccountId
        ? {googleAccountId: identity.googleAccountId}
        : {}),
      ...familyFields,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    profiles,
    selectedStudentProfileId,
    familyApplicationId:
      input.role === "parent" ? familyApplicationId : undefined,
  };
}

async function submitOnboardingApplicationCore({
  db = getFirestore(),
  identity,
  data,
  now = new Date(),
  generateFamilyId = randomUUID,
  allocateProfileRef,
}) {
  const input = parseOnboardingInput(data);
  const profileCount = input.role === "student"
    ? 1
    : input.additionalStudents.length + (input.parentIsStudent ? 1 : 0);
  const profileRefFactory = allocateProfileRef ||
    (() => db.collection("studentProfiles").doc());
  const profileRefs = Array.from({length: profileCount}, profileRefFactory);
  const familyApplicationId = input.role === "parent"
    ? generateFamilyId()
    : undefined;
  const userRef = db.collection("users").doc(identity.uid);
  const locationRef = db.collection("locations").doc(input.locationId);

  return db.runTransaction(async (transaction) => {
    const [userSnapshot, locationSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(locationRef),
    ]);
    if (userSnapshot.exists) {
      throw new HttpsError(
        "already-exists",
        "An onboarding application already exists for this account.",
        {reason: "already-submitted"},
      );
    }
    const location = locationSnapshot.data();
    if (!locationSnapshot.exists || !location || location.isActive !== true) {
      throw invalidLocation("The selected location is unavailable.");
    }
    const timeZoneId = optionalString(location.timeZoneId);
    if (!timeZoneId) {
      throw invalidLocation("The selected location has no time zone.");
    }

    const plan = buildApplicationDocuments({
      identity,
      input,
      timeZoneId,
      now,
      profileIds: profileRefs.map((reference) => reference.id),
      familyApplicationId,
    });
    transaction.create(userRef, plan.user);
    for (let index = 0; index < profileRefs.length; index += 1) {
      transaction.create(profileRefs[index], plan.profiles[index].data);
    }
    return {
      userId: identity.uid,
      studentProfileIds: plan.profiles.map((profile) => profile.id),
      selectedStudentProfileId: plan.selectedStudentProfileId,
      ...(plan.familyApplicationId
        ? {familyApplicationId: plan.familyApplicationId}
        : {}),
    };
  });
}

function invalidData(message) {
  return new HttpsError("invalid-argument", message, {reason: "invalid-data"});
}

function invalidLocation(message) {
  return new HttpsError("failed-precondition", message, {
    reason: "invalid-location",
  });
}

module.exports = {
  ageOnAcademyDate,
  buildApplicationDocuments,
  normalizeEmail,
  parseOnboardingInput,
  submitOnboardingApplicationCore,
  trustedIdentityFromAuth,
};
