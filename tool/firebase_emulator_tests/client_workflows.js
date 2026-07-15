import {doc, serverTimestamp, updateDoc, writeBatch} from 'firebase/firestore';

export async function createProfiles(db, {
  uid,
  email,
  locationId = 'cheshire',
  role = 'student',
  profileIds,
  googleAccountId,
  parentIsStudent = false,
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
      guardianEmail: ownProfile && role === 'student'
        ? 'guardian@example.com'
        : email,
      guardianUserIds: ownProfile ? [] : [uid],
      ...(ownProfile ? {linkedUserId: uid} : {}),
      preferredClassGroupIds: [],
      stickerProgress: {current: 0, required: 0, nextRank: 'Next rank'},
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
