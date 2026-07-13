# Secure Onboarding Backend

`submitOnboardingApplication` is an authenticated Firebase callable function.
It is the only supported onboarding write path for creating user/profile
relationships. The Flutter app does not write initial `users` or
`studentProfiles` documents directly.

## Callable request

Accepted top-level fields:

- `firstName`, `lastName`, and `dateOfBirth` (`YYYY-MM-DD`)
- `beltRank` when the applicant receives a student profile
- optional `phoneNumber`
- `role`: `student` or `parent`
- `locationId`
- `guardianEmail` for an independent student
- `parentIsStudent`
- `additionalStudents`

Each additional student supplies `firstName`, `lastName`, `dateOfBirth`,
`beltRank`, and `guardianEmail`. Unknown fields are rejected. In particular,
the client cannot submit UID, Auth email, Google provider ID, approval status,
family application ID, selected/linked profile IDs, guardian user IDs, or a
linked user ID.

The function derives identity from the verified callable Auth context. The
Firebase UID becomes `users/{uid}`; contact email comes from the Auth token;
and `googleAccountId`, when present, comes only from the token's `google.com`
identity.

## Validation and writes

The function rejects unauthenticated, duplicate, under-16, invalid-location,
inactive-location, malformed, and incomplete applications. Applicant age is
calculated against the current calendar date in the selected location's IANA
time zone.

One Firestore transaction reads the user and location, then creates the user
and every student profile. Parent applications receive one server-generated
`familyApplicationId`. Server-generated profile IDs are written reciprocally
to `users.linkedStudentProfileIds`; the first profile is selected, with a
parent's own profile allocated first. A failed create aborts the whole
transaction, leaving no partial family application.

The callable returns `userId`, `studentProfileIds`,
`selectedStudentProfileId`, and optional `familyApplicationId`.

## Local validation

Install Functions dependencies and run pure tests:

```powershell
npm --prefix functions install
npm --prefix functions run lint
npm --prefix functions test
```

Run Firestore transaction and rules tests with the local emulator. On this
Windows checkout, Android Studio's bundled JBR can provide Java:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
firebase emulators:exec --only firestore --project demo-ota-onboarding "npm --prefix functions run test:emulator"
```

The `demo-` project ID prevents fallback access to non-emulated Firebase
services.

## Manual release steps

After review, configure the intended Firebase project, confirm Node.js 22 is
supported, rerun all tests, and deploy deliberately:

```powershell
firebase deploy --only functions:submitOnboardingApplication
firebase deploy --only firestore:rules
```

Deployment order must be coordinated with the future onboarding UI. No
function or rule deployment occurs as part of repository development or test
runs.
