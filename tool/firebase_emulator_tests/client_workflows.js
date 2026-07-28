import {deleteDoc, doc, serverTimestamp, updateDoc, writeBatch} from 'firebase/firestore';

export async function createProfiles(db, {
  uid,
  email,
  locationId = 'cheshire',
  role = 'student',
  profileIds,
  googleAccountId,
  parentIsStudent = false,
  omitGuardianEmail = false,
  studentProfileDefaults,
}) {
  const timestamp = serverTimestamp();
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', uid), {
    firstName: 'Account',
    lastName: 'Holder',
    email: email.toLowerCase(),
    role,
    isActive: true,
    locationId,
    linkedStudentProfileIds: profileIds,
    selectedStudentProfileId: profileIds[0],
    ...(googleAccountId ? {googleAccountId} : {}),
    ...(studentProfileDefaults ? {studentProfileDefaults} : {}),
    createdAt: timestamp,
    updatedAt: timestamp,
  });
  profileIds.forEach((profileId, index) => {
    const ownProfile = role === 'student' || (parentIsStudent && index === 0);
    batch.set(doc(db, 'studentProfiles', profileId), {
      firstName: ownProfile ? 'Account' : `Child${index + 1}`,
      lastName: 'Holder',
      dateOfBirth: new Date(
        ownProfile ? '2000-01-02T00:00:00Z' : '2015-01-02T00:00:00Z',
      ),
      beltRank: 'White',
      locationId,
      ...(!omitGuardianEmail ? {
        guardianEmail: ownProfile && role === 'student'
          ? 'guardian@example.com'
          : email,
      } : {}),
      guardianUserIds: ownProfile ? [] : [uid],
      ...(ownProfile ? {linkedUserId: uid} : {}),
      preferredClassGroupIds: [],
      stickerProgress: {current: 0, required: 0, nextRank: 'White-Yellow'},
      promotionHistory: [],
      testingNotes: [],
      isActive: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  });
  await batch.commit();
}

export async function selectProfile(db, uid, profileId) {
  await updateDoc(doc(db, 'users', uid), {
    selectedStudentProfileId: profileId,
    updatedAt: serverTimestamp(),
  });
}

export async function markNotificationRead(db, uid, announcementId) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'users', uid, 'notificationReads', announcementId), {
    readAt: serverTimestamp(),
  });
  await batch.commit();
}

export async function markNotificationUnread(db, uid, announcementId) {
  await deleteDoc(doc(db, 'users', uid, 'notificationReads', announcementId));
}

export async function updatePreferredClass(db, profileId, bulkGroupId) {
  await updateDoc(doc(db, 'studentProfiles', profileId), {
    preferredClassGroupIds: bulkGroupId ? [bulkGroupId] : [],
    updatedAt: serverTimestamp(),
  });
}

export async function updateManagedProfile(db, profileId, overrides = {}) {
  await updateDoc(doc(db, 'studentProfiles', profileId), {
    firstName: 'Updated',
    lastName: 'Student',
    dateOfBirth: new Date('2010-01-02T00:00:00Z'),
    guardianEmail: 'parent@example.com',
    beltRank: 'Yellow',
    stickerProgress: {
      current: 2, required: 3, nextRank: 'Yellow-Green',
    },
    ...overrides,
    updatedAt: serverTimestamp(),
  });
}
