import {execSync} from 'node:child_process';
import {createRequire} from 'node:module';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const allowedProjectId = 'ota-management-platform';
const removalFields = Object.freeze({
  users: ['approvalStatus', 'familyApplicationId'],
  studentProfiles: [
    'approvalStatus',
    'applicationId',
    'appliedAt',
    'reviewedAt',
    'reviewedBy',
    'rejectionReason',
    'familyApplicationId',
  ],
});
const applicationCollection = 'membershipApplications';
const confirmationText = 'REMOVE DEVELOPMENT APPROVAL DATA';

function fieldValue(document, field) {
  const value = document.fields?.[field];
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  return undefined;
}

function documentId(document) {
  return document.name.split('/').at(-1);
}

function updateForUser(document, soleLocationId) {
  const role = fieldValue(document, 'role');
  const oldStatus = fieldValue(document, 'approvalStatus');
  const currentActive = fieldValue(document, 'isActive');
  const set = {};
  if (typeof currentActive !== 'boolean') {
    set.isActive = role === 'admin' || role === 'superAdmin'
      ? oldStatus !== 'disabled'
      : true;
  } else if ((role === 'student' || role === 'parent') && !currentActive) {
    set.isActive = true;
  }
  if ((role === 'student' || role === 'parent') &&
      !fieldValue(document, 'locationId')) {
    set.locationId = soleLocationId;
  }
  return {
    set,
    remove: removalFields.users.filter((field) => document.fields?.[field]),
  };
}

function updateForProfile(document, soleLocationId) {
  const set = {};
  if (!fieldValue(document, 'locationId')) set.locationId = soleLocationId;
  if (typeof fieldValue(document, 'isActive') !== 'boolean') {
    set.isActive = true;
  }
  return {
    set,
    remove: removalFields.studentProfiles.filter(
      (field) => document.fields?.[field],
    ),
  };
}

export function buildRemovalPlan({locations, users, profiles, applications}) {
  const activeLocations = locations.filter(
    (document) => fieldValue(document, 'isActive') === true,
  );
  if (activeLocations.length !== 1) {
    throw new Error(
      `Expected exactly one active location; found ${activeLocations.length}.`,
    );
  }
  const locationId = documentId(activeLocations[0]);
  const updates = [];
  for (const document of users) {
    const change = updateForUser(document, locationId);
    if (Object.keys(change.set).length || change.remove.length) {
      updates.push({collection: 'users', document, ...change});
    }
  }
  for (const document of profiles) {
    const change = updateForProfile(document, locationId);
    if (Object.keys(change.set).length || change.remove.length) {
      updates.push({collection: 'studentProfiles', document, ...change});
    }
  }
  const deletes = applications.map((document) => ({
    collection: applicationCollection,
    document,
  }));
  return {projectId: allowedProjectId, locationId, updates, deletes};
}

export function summarizePlan(plan) {
  const userUpdates = plan.updates.filter(
    (operation) => operation.collection === 'users',
  );
  const profileUpdates = plan.updates.filter(
    (operation) => operation.collection === 'studentProfiles',
  );
  return {
    projectId: plan.projectId,
    activeLocationId: plan.locationId,
    userCount: userUpdates.length,
    profileCount: profileUpdates.length,
    applicationDocumentCount: plan.deletes.length,
    documents: [
      ...plan.updates.map((operation) => ({
        path: `${operation.collection}/${documentId(operation.document)}`,
        fieldsSet: operation.set,
        fieldsRemoved: operation.remove,
      })),
      ...plan.deletes.map((operation) => ({
        path: `${operation.collection}/${documentId(operation.document)}`,
        deleteDocument: true,
      })),
    ],
  };
}

function firestoreValue(value) {
  if (typeof value === 'boolean') return {booleanValue: value};
  if (typeof value === 'string') return {stringValue: value};
  throw new Error(`Unsupported migration value: ${typeof value}`);
}

export function writesForPlan(plan) {
  return [
    ...plan.updates.map((operation) => ({
      update: {
        name: operation.document.name,
        fields: Object.fromEntries(
          Object.entries(operation.set).map(([field, value]) => [
            field,
            firestoreValue(value),
          ]),
        ),
      },
      updateMask: {
        fieldPaths: [...Object.keys(operation.set), ...operation.remove],
      },
      currentDocument: {exists: true},
    })),
    ...plan.deletes.map((operation) => ({delete: operation.document.name})),
  ];
}

async function requestJson(url, token, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'x-goog-user-project': allowedProjectId,
      ...options.headers,
    },
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

async function firebaseCliAccessToken() {
  const login = JSON.parse(execSync('firebase login:list --json', {
    encoding: 'utf8',
    windowsHide: true,
  }));
  const account = login.result?.[0];
  if (!account?.user || !account?.tokens) {
    throw new Error('No signed-in Firebase CLI account is available.');
  }
  const globalRoot = execSync('npm root -g', {
    encoding: 'utf8',
    windowsHide: true,
  }).trim();
  const require = createRequire(import.meta.url);
  const {requireAuth} = require(
    path.join(globalRoot, 'firebase-tools', 'lib', 'requireAuth.js'),
  );
  const api = require(
    path.join(globalRoot, 'firebase-tools', 'lib', 'apiv2.js'),
  );
  await requireAuth({
    project: allowedProjectId,
    user: account.user,
    tokens: account.tokens,
  });
  return api.getAccessToken();
}

async function readCollection(projectId, collectionId, token) {
  const documents = [];
  let pageToken;
  do {
    const url = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}` +
      `/databases/(default)/documents/${collectionId}`,
    );
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const result = await requestJson(url, token);
    documents.push(...(result.documents ?? []));
    pageToken = result.nextPageToken;
  } while (pageToken);
  return documents;
}

async function commitWrites(projectId, writes, token) {
  const endpoint = `https://firestore.googleapis.com/v1/projects/${projectId}` +
    '/databases/(default)/documents:commit';
  for (let start = 0; start < writes.length; start += 400) {
    await requestJson(endpoint, token, {
      method: 'POST',
      body: JSON.stringify({writes: writes.slice(start, start + 400)}),
    });
  }
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const projectArg = process.argv.find((value) => value.startsWith('--project='));
  const projectId = projectArg?.split('=', 2)[1] ?? allowedProjectId;
  if (projectId !== allowedProjectId) {
    throw new Error(`Refusing to access project ${projectId}.`);
  }
  const token = process.env.GOOGLE_OAUTH_ACCESS_TOKEN ||
    await firebaseCliAccessToken();
  const [locations, users, profiles, applications] = await Promise.all([
    readCollection(projectId, 'locations', token),
    readCollection(projectId, 'users', token),
    readCollection(projectId, 'studentProfiles', token),
    readCollection(projectId, applicationCollection, token),
  ]);
  const plan = buildRemovalPlan({locations, users, profiles, applications});
  const summary = summarizePlan(plan);
  console.log(JSON.stringify({dryRun: !args.has('--apply'), ...summary}, null, 2));
  if (!args.has('--apply')) return;
  if (!args.has(`--confirm=${confirmationText}`)) {
    throw new Error(`Write mode requires --confirm="${confirmationText}".`);
  }
  const writes = writesForPlan(plan);
  if (writes.length) await commitWrites(projectId, writes, token);
  console.log(JSON.stringify({
    applied: true,
    userCount: summary.userCount,
    profileCount: summary.profileCount,
    applicationDocumentCount: summary.applicationDocumentCount,
    writeCount: writes.length,
  }, null, 2));
}

const invokedDirectly = process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;
if (invokedDirectly) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
