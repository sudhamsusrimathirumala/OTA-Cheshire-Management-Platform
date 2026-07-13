import {
  collection,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  writeBatch,
} from 'firebase/firestore';

export function buildSubmission(uid, email, request, googleAccountId) {
  const normalizedEmail = email.trim().toLowerCase();
  const phoneNumber = request.phoneNumber?.trim();
  const user = {
    firstName: request.firstName.trim(),
    lastName: request.lastName.trim(),
    email: normalizedEmail,
    role: request.role,
    approvalStatus: 'pending',
    locationId: request.locationId.trim(),
    linkedStudentProfileIds: [],
    ...(phoneNumber ? {phoneNumber} : {}),
    ...(googleAccountId ? {googleAccountId} : {}),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  const application = {
    applicantUid: uid,
    firstName: request.firstName.trim(),
    lastName: request.lastName.trim(),
    email: normalizedEmail,
    dateOfBirth: request.dateOfBirth,
    role: request.role,
    locationId: request.locationId.trim(),
    status: 'pending',
    parentIsStudent: request.parentIsStudent ?? false,
    additionalStudents: request.additionalStudents ?? [],
    ...(phoneNumber ? {phoneNumber} : {}),
    ...(request.applicantBeltRank
      ? {applicantBeltRank: request.applicantBeltRank.trim()}
      : {}),
    ...(request.guardianEmail
      ? {guardianEmail: request.guardianEmail.trim().toLowerCase()}
      : {}),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
  return {user, application};
}

export async function submitApplication(
  db,
  uid,
  email,
  request,
  googleAccountId,
) {
  const locationRef = doc(db, 'locations', request.locationId.trim());
  let location;
  try {
    location = await getDoc(locationRef);
  } catch (_) {
    throw new Error('invalid-location');
  }
  if (!location.exists() || location.data().isActive !== true ||
      typeof location.data().timeZoneId !== 'string') {
    throw new Error('invalid-location');
  }
  const academyDate = new Date(new Date().toLocaleString('en-US', {
    timeZone: location.data().timeZoneId,
  }));
  const birthDate = request.dateOfBirth.toDate?.() ?? request.dateOfBirth;
  let age = academyDate.getFullYear() - birthDate.getFullYear();
  if (academyDate.getMonth() < birthDate.getMonth() ||
      (academyDate.getMonth() === birthDate.getMonth() &&
       academyDate.getDate() < birthDate.getDate())) age--;
  if (age < 16) throw new Error('invalid-age');
  const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  if (!emailPattern.test(email.trim().toLowerCase())) {
    throw new Error('invalid-email');
  }
  const additionalStudents = request.additionalStudents ?? [];
  if (!Array.isArray(additionalStudents) || additionalStudents.length > 10 ||
      additionalStudents.some((student) =>
        !student.firstName?.trim() || !student.lastName?.trim() ||
        !student.beltRank?.trim() ||
        !emailPattern.test(student.guardianEmail?.trim().toLowerCase() ?? ''))) {
    throw new Error('invalid-additional-students');
  }
  if (request.role === 'student' &&
      (request.parentIsStudent || additionalStudents.length ||
       !request.applicantBeltRank?.trim() ||
       !emailPattern.test(request.guardianEmail?.trim().toLowerCase() ?? ''))) {
    throw new Error('invalid-student-application');
  }
  if (request.role === 'parent' &&
      ((request.parentIsStudent && !request.applicantBeltRank?.trim()) ||
       (!request.parentIsStudent && !additionalStudents.length))) {
    throw new Error('invalid-parent-application');
  }
  const userRef = doc(db, 'users', uid);
  const applicationRef = doc(db, 'onboardingApplications', uid);
  const [user, application] = await Promise.all([
    getDoc(userRef),
    getDoc(applicationRef),
  ]);
  if (user.exists() || application.exists()) {
    throw new Error('application-already-exists');
  }
  const payload = buildSubmission(uid, email, request, googleAccountId);
  const batch = writeBatch(db);
  batch.set(userRef, payload.user);
  batch.set(applicationRef, payload.application);
  await batch.commit();
}

function requireString(data, key) {
  const value = data[key];
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`invalid-${key}`);
  }
  return value.trim();
}

function profileInputs(application) {
  const role = requireString(application, 'role');
  const parentIsStudent = application.parentIsStudent === true;
  const inputs = [];
  let applicantProfileIndex = null;
  if (role === 'student' || parentIsStudent) {
    applicantProfileIndex = 0;
    inputs.push({
      firstName: requireString(application, 'firstName'),
      lastName: requireString(application, 'lastName'),
      dateOfBirth: application.dateOfBirth,
      beltRank: requireString(application, 'applicantBeltRank'),
      guardianEmail:
        role === 'student'
          ? requireString(application, 'guardianEmail').toLowerCase()
          : requireString(application, 'email').toLowerCase(),
      isApplicantProfile: true,
    });
  }
  const students = application.additionalStudents;
  if (!Array.isArray(students) || students.length > 10) {
    throw new Error('invalid-additional-students');
  }
  for (const student of students) {
    inputs.push({
      firstName: requireString(student, 'firstName'),
      lastName: requireString(student, 'lastName'),
      dateOfBirth: student.dateOfBirth,
      beltRank: requireString(student, 'beltRank'),
      guardianEmail: requireString(student, 'guardianEmail').toLowerCase(),
      isApplicantProfile: false,
    });
  }
  if (!inputs.length) throw new Error('application-has-no-students');
  return {inputs, applicantProfileIndex, role};
}

export async function approveApplication(
  db,
  reviewerUid,
  applicantUid,
  {profileIds: candidateProfileIds, familyId} = {},
) {
  const userRef = doc(db, 'users', applicantUid);
  const applicationRef = doc(db, 'onboardingApplications', applicantUid);
  const reviewerRef = doc(db, 'users', reviewerUid);
  return runTransaction(db, async (transaction) => {
    const [reviewerSnapshot, applicationSnapshot, userSnapshot] =
      await Promise.all([
        transaction.get(reviewerRef),
        transaction.get(applicationRef),
        transaction.get(userRef),
      ]);
    if (!reviewerSnapshot.exists() || !applicationSnapshot.exists() ||
        !userSnapshot.exists()) {
      throw new Error('missing-application');
    }
    const reviewer = reviewerSnapshot.data();
    const application = applicationSnapshot.data();
    const user = userSnapshot.data();
    if (reviewer.approvalStatus !== 'approved' ||
        !['admin', 'superAdmin'].includes(reviewer.role) ||
        (reviewer.role === 'admin' &&
          reviewer.locationId !== application.locationId)) {
      throw new Error('invalid-reviewer');
    }
    if (application.status !== 'pending' || user.approvalStatus !== 'pending') {
      throw new Error('duplicate-review');
    }
    const location = await transaction.get(
      doc(db, 'locations', application.locationId),
    );
    if (!location.exists() || location.data().isActive !== true) {
      throw new Error('invalid-location');
    }
    const parsed = profileInputs(application);
    const profileRefs = parsed.inputs.map((_, index) => candidateProfileIds?.[index]
      ? doc(db, 'studentProfiles', candidateProfileIds[index])
      : doc(collection(db, 'studentProfiles')),
    );
    const familyApplicationId = parsed.role === 'parent'
      ? (familyId ?? doc(collection(db, 'onboardingApplications')).id)
      : null;
    for (const profileRef of profileRefs) {
      if ((await transaction.get(profileRef)).exists()) {
        throw new Error('profile-id-collision');
      }
    }
    const timestamp = serverTimestamp();
    parsed.inputs.forEach((student, index) => {
      transaction.set(profileRefs[index], {
        applicationUid: applicantUid,
        firstName: student.firstName,
        lastName: student.lastName,
        dateOfBirth: student.dateOfBirth,
        beltRank: student.beltRank,
        locationId: application.locationId,
        guardianEmail: student.guardianEmail,
        guardianUserIds: student.isApplicantProfile ? [] : [applicantUid],
        ...(student.isApplicantProfile ? {linkedUserId: applicantUid} : {}),
        ...(familyApplicationId ? {familyApplicationId} : {}),
        approvalStatus: 'approved',
        preferredClassGroupIds: [],
        stickerProgress: {current: 0, required: 0, nextRank: 'Next rank'},
        promotionHistory: [],
        testingNotes: [],
        isActive: true,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    });
    const profileIds = profileRefs.map((ref) => ref.id);
    const selectedStudentProfileId =
      profileIds[parsed.applicantProfileIndex ?? 0];
    transaction.update(userRef, {
      approvalStatus: 'approved',
      linkedStudentProfileIds: profileIds,
      selectedStudentProfileId,
      ...(familyApplicationId ? {familyApplicationId} : {}),
      updatedAt: timestamp,
    });
    transaction.update(applicationRef, {
      status: 'approved',
      reviewedAt: timestamp,
      reviewedBy: reviewerUid,
      updatedAt: timestamp,
    });
    return {profileIds, selectedStudentProfileId, familyApplicationId};
  });
}

export async function rejectApplication(
  db,
  reviewerUid,
  applicantUid,
  rejectionReason,
) {
  return runTransaction(db, async (transaction) => {
    const reviewerRef = doc(db, 'users', reviewerUid);
    const userRef = doc(db, 'users', applicantUid);
    const applicationRef = doc(db, 'onboardingApplications', applicantUid);
    const [reviewerSnapshot, applicationSnapshot, userSnapshot] =
      await Promise.all([
        transaction.get(reviewerRef),
        transaction.get(applicationRef),
        transaction.get(userRef),
      ]);
    if (!reviewerSnapshot.exists() || !applicationSnapshot.exists() ||
        !userSnapshot.exists()) {
      throw new Error('missing-application');
    }
    const reviewer = reviewerSnapshot.data();
    const application = applicationSnapshot.data();
    const user = userSnapshot.data();
    if (reviewer.approvalStatus !== 'approved' ||
        !['admin', 'superAdmin'].includes(reviewer.role) ||
        (reviewer.role === 'admin' &&
          reviewer.locationId !== application.locationId)) {
      throw new Error('invalid-reviewer');
    }
    if (application.status !== 'pending' || user.approvalStatus !== 'pending') {
      throw new Error('duplicate-review');
    }
    const location = await transaction.get(
      doc(db, 'locations', application.locationId),
    );
    if (!location.exists() || location.data().isActive !== true) {
      throw new Error('invalid-location');
    }
    const timestamp = serverTimestamp();
    transaction.update(userRef, {
      approvalStatus: 'rejected',
      updatedAt: timestamp,
    });
    transaction.update(applicationRef, {
      status: 'rejected',
      reviewedAt: timestamp,
      reviewedBy: reviewerUid,
      ...(rejectionReason?.trim()
        ? {rejectionReason: rejectionReason.trim()}
        : {}),
      updatedAt: timestamp,
    });
  });
}
