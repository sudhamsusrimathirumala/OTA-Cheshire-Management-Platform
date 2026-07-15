import {
  deleteField,
  doc,
  serverTimestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

export async function createProfiles(db, {
  uid,
  email,
  role = 'student',
  profileIds,
  familyApplicationId,
  googleAccountId,
  profileOverrides = {},
}) {
  const timestamp = serverTimestamp();
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', uid), {
    firstName: 'Account',
    lastName: 'Holder',
    email: email.toLowerCase(),
    role,
    approvalStatus: 'incomplete',
    linkedStudentProfileIds: profileIds,
    selectedStudentProfileId: profileIds[0],
    ...(familyApplicationId ? {familyApplicationId} : {}),
    ...(googleAccountId ? {googleAccountId} : {}),
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  profileIds.forEach((profileId, index) => {
    const ownProfile = role === 'student' || (role === 'parent' && index === 0 && profileIds.length > 1);
    batch.set(doc(db, 'studentProfiles', profileId), {
      firstName: ownProfile ? 'Account' : `Child${index + 1}`,
      lastName: 'Holder',
      dateOfBirth: new Date(ownProfile ? '2000-01-02T00:00:00Z' : '2015-01-02T00:00:00Z'),
      beltRank: 'White',
      guardianEmail: ownProfile && role === 'student' ? 'guardian@example.com' : email,
      guardianUserIds: ownProfile ? [] : [uid],
      ...(ownProfile ? {linkedUserId: uid} : {}),
      ...(familyApplicationId ? {familyApplicationId} : {}),
      approvalStatus: 'incomplete',
      preferredClassGroupIds: [],
      stickerProgress: {current: 0, required: 0, nextRank: 'Next rank'},
      promotionHistory: [],
      testingNotes: [],
      isActive: true,
      ...profileOverrides,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  });
  await batch.commit();
}

export async function applyToLocation(db, uid, profileId, locationId, ownProfile = true) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'studentProfiles', profileId), {
    locationId,
    approvalStatus: 'pending',
    reviewedAt: serverTimestamp(),
    reviewedBy: 'temporary',
    rejectionReason: 'temporary',
    updatedAt: serverTimestamp(),
  });
  // deleteField cannot be represented by undefined; update again via caller tests
  if (ownProfile) {
    batch.update(doc(db, 'users', uid), {locationId, updatedAt: serverTimestamp()});
  }
  return batch;
}

export async function selectProfile(db, uid, profileId) {
  await updateDoc(doc(db, 'users', uid), {
    selectedStudentProfileId: profileId,
    updatedAt: serverTimestamp(),
  });
}

export async function submitMembershipApplication(db, {
  uid,
  email,
  applicationId,
  locationId,
  profileIds,
  role = 'parent',
}) {
  const timestamp = serverTimestamp();
  const batch = writeBatch(db);
  batch.set(doc(db, 'membershipApplications', applicationId), {
    applicantUserId: uid,
    applicantSnapshot: {
      firstName: 'Account',
      lastName: 'Holder',
      email: email.toLowerCase(),
      role,
    },
    locationId,
    studentProfileIds: profileIds,
    status: 'pending',
    appliedAt: timestamp,
    updatedAt: timestamp,
  });
  profileIds.forEach((profileId) => {
    batch.update(doc(db, 'studentProfiles', profileId), {
      locationId,
      approvalStatus: 'pending',
      applicationId,
      appliedAt: timestamp,
      reviewedAt: deleteField(),
      reviewedBy: deleteField(),
      rejectionReason: deleteField(),
      updatedAt: timestamp,
    });
  });
  await batch.commit();
}

export async function reviewMembershipApplication(db, {
  applicationId,
  profileIds,
  reviewerId,
  approved,
  reason,
}) {
  const timestamp = serverTimestamp();
  const status = approved ? 'approved' : 'rejected';
  const batch = writeBatch(db);
  batch.update(doc(db, 'membershipApplications', applicationId), {
    status,
    reviewedAt: timestamp,
    reviewedBy: reviewerId,
    updatedAt: timestamp,
    rejectionReason: approved || !reason ? deleteField() : reason,
  });
  profileIds.forEach((profileId) => {
    batch.update(doc(db, 'studentProfiles', profileId), {
      approvalStatus: status,
      reviewedAt: timestamp,
      reviewedBy: reviewerId,
      updatedAt: timestamp,
      rejectionReason: approved || !reason ? deleteField() : reason,
    });
  });
  await batch.commit();
}
