import fs from 'node:fs';
import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  approveApplication,
  buildSubmission,
  rejectApplication,
  submitApplication,
} from './client_workflows.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-ota-onboarding';
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {rules: fs.readFileSync('../../firestore.rules', 'utf8')},
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'locations', 'cheshire'), {
      name: 'OTA Cheshire',
      isActive: true,
      timeZoneId: 'America/New_York',
    });
    await setDoc(doc(db, 'locations', 'other'), {
      name: 'Other Academy',
      isActive: true,
      timeZoneId: 'America/Chicago',
    });
    await setDoc(doc(db, 'locations', 'inactive'), {
      name: 'Inactive Academy',
      isActive: false,
      timeZoneId: 'America/New_York',
    });
  });
});

after(async () => testEnvironment.cleanup());

function authenticated(uid, email = `${uid}@example.com`, extra = {}) {
  return testEnvironment.authenticatedContext(uid, {email, ...extra})
      .firestore();
}

function studentRequest(overrides = {}) {
  return {
    firstName: 'Student',
    lastName: 'Applicant',
    dateOfBirth: Timestamp.fromDate(new Date('2000-01-02T12:00:00Z')),
    role: 'student',
    locationId: 'cheshire',
    parentIsStudent: false,
    applicantBeltRank: 'Blue',
    guardianEmail: 'guardian@example.com',
    additionalStudents: [],
    ...overrides,
  };
}

function child(firstName = 'Child') {
  return {
    firstName,
    lastName: 'Applicant',
    dateOfBirth: Timestamp.fromDate(new Date('2015-05-06T12:00:00Z')),
    beltRank: 'Yellow',
    guardianEmail: 'parent@example.com',
  };
}

async function seedReviewer(uid, role, locationId = 'cheshire') {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', uid), {
      firstName: 'Approved',
      lastName: 'Reviewer',
      email: `${uid}@example.com`,
      role,
      approvalStatus: 'approved',
      locationId,
      linkedStudentProfileIds: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
}

test('student submission creates exactly user and application atomically', async () => {
  const db = authenticated('student', 'Student@Example.com');
  await assertSucceeds(submitApplication(
    db,
    'student',
    'Student@Example.com',
    studentRequest(),
  ));
  const user = await getDoc(doc(db, 'users', 'student'));
  const application = await getDoc(
    doc(db, 'onboardingApplications', 'student'),
  );
  assert.equal(user.id, 'student');
  assert.equal(application.id, 'student');
  assert.equal(user.data().email, 'student@example.com');
  assert.deepEqual(user.data().linkedStudentProfileIds, []);
  assert.equal(application.data().status, 'pending');
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    assert.equal((await getDoc(doc(
      context.firestore(), 'users', 'student@example.com'))).exists(), false);
    assert.equal((await getDocs(
      collection(context.firestore(), 'studentProfiles'))).size, 0);
  });
});

test('parent variants and optional phone fields are stored canonically', async () => {
  const oneChildDb = authenticated('parent', 'parent@example.com');
  await submitApplication(oneChildDb, 'parent', 'parent@example.com', {
    ...studentRequest(),
    role: 'parent',
    parentIsStudent: false,
    applicantBeltRank: undefined,
    guardianEmail: undefined,
    phoneNumber: ' 555-0100 ',
    additionalStudents: [child()],
  });
  const oneChild = (await getDoc(
    doc(oneChildDb, 'onboardingApplications', 'parent'),
  )).data();
  assert.equal(oneChild.phoneNumber, '555-0100');
  assert.equal(oneChild.additionalStudents.length, 1);

  const parentStudentDb = authenticated('parent-student');
  await submitApplication(
    parentStudentDb,
    'parent-student',
    'parent-student@example.com',
    {
      ...studentRequest(),
      role: 'parent',
      parentIsStudent: true,
      guardianEmail: undefined,
      phoneNumber: ' ',
      additionalStudents: [child()],
    },
  );
  const parentStudent = (await getDoc(
    doc(parentStudentDb, 'onboardingApplications', 'parent-student'),
  )).data();
  assert.equal(parentStudent.parentIsStudent, true);
  assert.equal('phoneNumber' in parentStudent, false);

  const multiDb = authenticated('multi-parent');
  await submitApplication(multiDb, 'multi-parent', 'multi-parent@example.com', {
    ...studentRequest(),
    role: 'parent',
    parentIsStudent: false,
    applicantBeltRank: undefined,
    guardianEmail: undefined,
    additionalStudents: [child('One'), child('Two'), child('Three')],
  });
  assert.equal((await getDoc(
    doc(multiDb, 'onboardingApplications', 'multi-parent'),
  )).data().additionalStudents.length, 3);
});

test('Google ID is accepted only when present in authenticated identity', async () => {
  const googleDb = authenticated('google-user', 'google@example.com', {
    firebase: {identities: {'google.com': ['google-provider-id']}},
  });
  await assertSucceeds(submitApplication(
    googleDb,
    'google-user',
    'google@example.com',
    studentRequest(),
    'google-provider-id',
  ));
  const forgedDb = authenticated('forged-google', 'forged@example.com');
  await assertFails(submitApplication(
    forgedDb,
    'forged-google',
    'forged@example.com',
    studentRequest(),
    'google-provider-id',
  ));
});

test('invalid applicant data and duplicate applications are rejected', async () => {
  await assert.rejects(
    submitApplication(
      authenticated('young'),
      'young',
      'young@example.com',
      studentRequest({
        dateOfBirth: Timestamp.fromDate(new Date('2015-01-01T12:00:00Z')),
      }),
    ),
    /invalid-age/,
  );
  await assert.rejects(
    submitApplication(
      authenticated('inactive'),
      'inactive',
      'inactive@example.com',
      studentRequest({locationId: 'inactive'}),
    ),
    /invalid-location/,
  );
  await assert.rejects(
    submitApplication(
      authenticated('empty-parent'),
      'empty-parent',
      'empty-parent@example.com',
      {...studentRequest(), role: 'parent', parentIsStudent: false,
        applicantBeltRank: undefined, guardianEmail: undefined},
    ),
    /invalid-parent-application/,
  );
  await assert.rejects(
    submitApplication(
      authenticated('bad-guardian'),
      'bad-guardian',
      'bad-guardian@example.com',
      studentRequest({guardianEmail: 'not-an-email'}),
    ),
    /invalid-student-application/,
  );
  const duplicateDb = authenticated('duplicate');
  await submitApplication(
    duplicateDb,
    'duplicate',
    'duplicate@example.com',
    studentRequest(),
  );
  await assert.rejects(
    submitApplication(
      duplicateDb,
      'duplicate',
      'duplicate@example.com',
      studentRequest(),
    ),
    /application-already-exists/,
  );
});

test('unauthenticated and partial or malformed atomic creation is denied', async () => {
  const unauthenticatedDb = testEnvironment.unauthenticatedContext().firestore();
  const unauthenticatedPayload = buildSubmission(
    'anon',
    'anon@example.com',
    studentRequest(),
  );
  const anonymousBatch = writeBatch(unauthenticatedDb);
  anonymousBatch.set(doc(unauthenticatedDb, 'users', 'anon'),
    unauthenticatedPayload.user);
  anonymousBatch.set(doc(unauthenticatedDb, 'onboardingApplications', 'anon'),
    unauthenticatedPayload.application);
  await assertFails(anonymousBatch.commit());

  const db = authenticated('partial');
  const payload = buildSubmission(
    'partial',
    'partial@example.com',
    studentRequest(),
  );
  await assertFails(setDoc(doc(db, 'users', 'partial'), payload.user));
  await assertFails(setDoc(
    doc(db, 'onboardingApplications', 'partial'),
    payload.application,
  ));

  const failedBatch = writeBatch(db);
  failedBatch.set(doc(db, 'users', 'partial'), payload.user);
  failedBatch.set(doc(db, 'onboardingApplications', 'partial'), {
    ...payload.application,
    approvalRoleOverride: 'admin',
  });
  await assertFails(failedBatch.commit());

  const nestedDb = authenticated('nested');
  const nestedPayload = buildSubmission(
    'nested',
    'nested@example.com',
    {...studentRequest(), role: 'parent', parentIsStudent: false,
      applicantBeltRank: undefined, guardianEmail: undefined,
      additionalStudents: [{...child(), guardianUserIds: ['nested']}]},
  );
  const nestedBatch = writeBatch(nestedDb);
  nestedBatch.set(doc(nestedDb, 'users', 'nested'), nestedPayload.user);
  nestedBatch.set(doc(nestedDb, 'onboardingApplications', 'nested'),
    nestedPayload.application);
  await assertFails(nestedBatch.commit());
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    assert.equal((await getDoc(doc(context.firestore(), 'users', 'partial'))).exists(),
      false);
    assert.equal((await getDoc(doc(
      context.firestore(), 'onboardingApplications', 'partial'))).exists(), false);
  });
});

test('applicant reads only own pending records and cannot escalate', async () => {
  const db = authenticated('applicant');
  await submitApplication(
    db,
    'applicant',
    'applicant@example.com',
    studentRequest(),
  );
  await assertSucceeds(getDoc(doc(db, 'users', 'applicant')));
  await assertSucceeds(getDoc(doc(db, 'onboardingApplications', 'applicant')));
  await assertFails(getDoc(doc(db, 'onboardingApplications', 'someone-else')));
  await assertFails(updateDoc(doc(db, 'users', 'applicant'), {
    approvalStatus: 'approved',
    updatedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(db, 'users', 'applicant'), {
    role: 'admin',
    updatedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(db, 'users', 'applicant'), {
    linkedStudentProfileIds: ['forged'],
    updatedAt: Timestamp.now(),
  }));
  await assertFails(setDoc(doc(db, 'studentProfiles', 'forged'), {
    locationId: 'cheshire',
  }));
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'events', 'event'), {
      locationId: 'cheshire', title: 'Private event',
    });
  });
  await assertFails(getDoc(doc(db, 'events', 'event')));
});

test('location admins read only own applications and Super Admin reads all', async () => {
  await seedReviewer('admin', 'admin');
  await seedReviewer('super', 'superAdmin', 'cheshire');
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'onboardingApplications', 'same'), {
      locationId: 'cheshire', status: 'pending',
    });
    await setDoc(doc(context.firestore(), 'onboardingApplications', 'other'), {
      locationId: 'other', status: 'pending',
    });
  });
  const adminDb = authenticated('admin');
  await assertSucceeds(getDoc(
    doc(adminDb, 'onboardingApplications', 'same')));
  await assertFails(getDoc(doc(adminDb, 'onboardingApplications', 'other')));
  const superDb = authenticated('super');
  await assertSucceeds(getDoc(
    doc(superDb, 'onboardingApplications', 'same')));
  await assertSucceeds(getDoc(
    doc(superDb, 'onboardingApplications', 'other')));
});

test('student approval creates one profile and reciprocal links', async () => {
  await seedReviewer('admin', 'admin');
  const applicantDb = authenticated('student');
  await submitApplication(
    applicantDb, 'student', 'student@example.com', studentRequest(),
  );
  const adminDb = authenticated('admin');
  const result = await assertSucceeds(
    approveApplication(adminDb, 'admin', 'student'),
  );
  assert.equal(result.profileIds.length, 1);
  const profile = (await getDoc(
    doc(adminDb, 'studentProfiles', result.profileIds[0]),
  )).data();
  const user = (await getDoc(doc(adminDb, 'users', 'student'))).data();
  assert.equal(profile.linkedUserId, 'student');
  assert.deepEqual(profile.guardianUserIds, []);
  assert.equal(user.selectedStudentProfileId, result.profileIds[0]);
  assert.equal(user.approvalStatus, 'approved');
});

test('parent approvals create all profiles, shared family, and select parent first', async () => {
  await seedReviewer('admin', 'admin');
  const applicantDb = authenticated('parent-student');
  await submitApplication(
    applicantDb,
    'parent-student',
    'parent-student@example.com',
    {...studentRequest(), role: 'parent', parentIsStudent: true,
      guardianEmail: undefined, additionalStudents: [child('One'), child('Two')]},
  );
  const adminDb = authenticated('admin');
  const result = await approveApplication(
    adminDb, 'admin', 'parent-student',
  );
  assert.equal(result.profileIds.length, 3);
  assert.equal(result.selectedStudentProfileId, result.profileIds[0]);
  const profiles = await Promise.all(result.profileIds.map(async (id) =>
    (await getDoc(doc(adminDb, 'studentProfiles', id))).data(),
  ));
  assert.ok(result.familyApplicationId);
  assert.ok(profiles.every((profile) =>
    profile.familyApplicationId === result.familyApplicationId));
  assert.equal(profiles[0].linkedUserId, 'parent-student');
  assert.deepEqual(profiles[1].guardianUserIds, ['parent-student']);
});

test('rejection is atomic and creates no profiles', async () => {
  await seedReviewer('admin', 'admin');
  const applicantDb = authenticated('rejected');
  await submitApplication(
    applicantDb, 'rejected', 'rejected@example.com', studentRequest(),
  );
  const adminDb = authenticated('admin');
  await assertSucceeds(rejectApplication(
    adminDb, 'admin', 'rejected', 'Incomplete information',
  ));
  assert.equal((await getDoc(doc(adminDb, 'users', 'rejected')))
    .data().approvalStatus, 'rejected');
  assert.equal((await getDoc(
    doc(adminDb, 'onboardingApplications', 'rejected'))).data().status,
  'rejected');
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    assert.equal((await getDocs(
      collection(context.firestore(), 'studentProfiles'))).size, 0);
  });
});

test('duplicate and cross-location approval fail; Super Admin can approve', async () => {
  await seedReviewer('admin', 'admin');
  await seedReviewer('super', 'superAdmin');
  const localDb = authenticated('local');
  await submitApplication(localDb, 'local', 'local@example.com', studentRequest());
  const adminDb = authenticated('admin');
  await approveApplication(adminDb, 'admin', 'local');
  await assert.rejects(
    approveApplication(adminDb, 'admin', 'local'),
    /duplicate-review/,
  );

  const otherDb = authenticated('other-student');
  await submitApplication(
    otherDb,
    'other-student',
    'other-student@example.com',
    studentRequest({locationId: 'other'}),
  );
  await assert.rejects(
    approveApplication(adminDb, 'admin', 'other-student'),
  );
  const superDb = authenticated('super');
  await assertSucceeds(
    approveApplication(superDb, 'super', 'other-student'),
  );
});

test('approval transaction failure leaves no partial updates', async () => {
  await seedReviewer('admin', 'admin');
  const applicantDb = authenticated('malformed');
  await submitApplication(
    applicantDb, 'malformed', 'malformed@example.com', studentRequest(),
  );
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(
      doc(context.firestore(), 'onboardingApplications', 'malformed'),
      {applicantBeltRank: ''},
    );
  });
  const adminDb = authenticated('admin');
  await assert.rejects(
    approveApplication(adminDb, 'admin', 'malformed'),
    /invalid-applicantBeltRank/,
  );
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    assert.equal((await getDoc(doc(db, 'users', 'malformed')))
      .data().approvalStatus, 'pending');
    assert.equal((await getDoc(doc(db, 'onboardingApplications', 'malformed')))
      .data().status, 'pending');
    assert.equal((await getDocs(collection(db, 'studentProfiles'))).size, 0);
  });
});

test('profile ID collision rejects approval without partial updates', async () => {
  await seedReviewer('admin', 'admin');
  const applicantDb = authenticated('collision');
  await submitApplication(
    applicantDb, 'collision', 'collision@example.com', studentRequest(),
  );
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'studentProfiles', 'collision-id'), {
      locationId: 'cheshire',
      firstName: 'Existing',
    });
  });
  const adminDb = authenticated('admin');
  await assert.rejects(
    approveApplication(adminDb, 'admin', 'collision', {
      profileIds: ['collision-id'],
    }),
    /profile-id-collision/,
  );
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    assert.equal((await getDoc(doc(db, 'users', 'collision')))
      .data().approvalStatus, 'pending');
    assert.equal((await getDoc(doc(db, 'onboardingApplications', 'collision')))
      .data().status, 'pending');
  });
});
