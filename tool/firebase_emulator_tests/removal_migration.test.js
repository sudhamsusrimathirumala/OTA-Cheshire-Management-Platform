import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildRemovalPlan,
  summarizePlan,
  writesForPlan,
} from '../remove_approval_data.mjs';

function document(collection, id, fields = {}) {
  const typedFields = Object.fromEntries(
    Object.entries(fields).map(([field, value]) => [
      field,
      typeof value === 'boolean'
        ? {booleanValue: value}
        : {stringValue: value},
    ]),
  );
  return {
    name: `projects/ota-management-platform/databases/(default)/documents/${collection}/${id}`,
    fields: typedFields,
  };
}

const location = document('locations', 'cheshire', {isActive: true});

test('legacy profile states all become immediate active access', () => {
  for (const status of ['incomplete', 'pending', 'approved', 'rejected']) {
    const profile = document('studentProfiles', status, {approvalStatus: status});
    const plan = buildRemovalPlan({
      locations: [location], users: [], profiles: [profile], applications: [],
    });
    assert.deepEqual(plan.updates[0].set, {
      locationId: 'cheshire',
      isActive: true,
    });
    assert.deepEqual(plan.updates[0].remove, ['approvalStatus']);
    assert.match(plan.updates[0].document.name, new RegExp(`/${status}$`));
  }
});

test('migration preserves IDs and existing profile data', () => {
  const profile = document('studentProfiles', 'profile-1', {
    locationId: 'cheshire', isActive: false, beltRank: 'Blue',
    applicationId: 'application-1', reviewedBy: 'admin-1',
  });
  const user = document('users', 'user-1', {
    role: 'parent', locationId: 'cheshire', isActive: true,
    approvalStatus: 'approved', familyApplicationId: 'family-1',
  });
  const application = document('membershipApplications', 'application-1');
  const plan = buildRemovalPlan({
    locations: [location], users: [user], profiles: [profile],
    applications: [application],
  });
  const writes = writesForPlan(plan);
  assert.equal(writes[0].update.name, user.name);
  assert.equal(writes[1].update.name, profile.name);
  assert.deepEqual(writes[1].update.fields, {});
  assert.equal(writes[2].delete, application.name);
  assert.equal(profile.fields.beltRank.stringValue, 'Blue');
  assert.equal(profile.fields.isActive.booleanValue, false);
  assert.equal(summarizePlan(plan).applicationDocumentCount, 1);
});

test('second run is empty and therefore safe', () => {
  const migratedUser = document('users', 'user-1', {
    role: 'parent', locationId: 'cheshire', isActive: true,
  });
  const migratedProfile = document('studentProfiles', 'profile-1', {
    locationId: 'cheshire', isActive: true,
  });
  const plan = buildRemovalPlan({
    locations: [location], users: [migratedUser], profiles: [migratedProfile],
    applications: [],
  });
  assert.deepEqual(plan.updates, []);
  assert.deepEqual(plan.deletes, []);
  assert.deepEqual(writesForPlan(plan), []);
});

test('migration refuses zero or multiple active locations', () => {
  assert.throws(
    () => buildRemovalPlan({locations: [], users: [], profiles: [], applications: []}),
    /exactly one active location/,
  );
  assert.throws(
    () => buildRemovalPlan({
      locations: [location, document('locations', 'other', {isActive: true})],
      users: [], profiles: [], applications: [],
    }),
    /found 2/,
  );
});
