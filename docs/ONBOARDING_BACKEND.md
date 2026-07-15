# Authentication and Profile Membership

The OTA identity and membership flow uses Firebase Authentication and direct,
Spark-compatible Firestore writes. It deploys no Cloud Functions and requires
no billing account or paid Google Cloud service.

## Authentication and routing

`FirebaseAuthenticationService` supports email/password signup and login,
Google Sign-In, neutral password reset, refresh, sign out, and safe error
mapping. Email ownership verification is not required for profile creation or
academy application. Firebase UID is the permanent identity; email is contact
data. Google provider UID is read only from the authenticated
`google.com` provider entry.

`FirebaseSessionController` observes Auth, `users/{uid}`, linked profiles, the
selected profile, and its location. The startup gate routes signed-out,
profile-creation, incomplete, pending, rejected, disabled,
approved-student, admin, loading, and recoverable-error states without restart.

## Profile creation

Authenticated users complete a three-step flow with a 16+ account-holder gate.
Students create one self-linked profile. Parents may create their own student
profile and up to ten additional children, or one through ten children without
a personal student profile. A single `WriteBatch` creates `users/{uid}` and all
`studentProfiles` documents. Every initial profile has
`approvalStatus: incomplete` and no `locationId`. Parent families share one
`familyApplicationId`; the parent's own profile is selected first when present.

## Profile-specific membership

Application loads active locations from Firestore and lets the applicant select
one or more linked profiles that are `incomplete` or `rejected`. One atomic
transaction creates a `membershipApplications` document and moves every
selected profile to `pending` at one location with the same application ID and
timestamp. Pending and approved profiles are unavailable for another batch.

Admin review updates the pending application and every included profile to
`approved` or `rejected` in one transaction with consistent reviewer metadata.
Per-profile or partial batch review is not permitted. Existing pending profiles
without an application document remain reviewable as legacy one-profile
applications and are not rewritten automatically.

Leaving an approved or rejected membership removes that profile's location and
review fields and restores `incomplete`; other family profiles are not changed.
A pending batch remains intact until the academy reviews it.

Academy data is readable only when the selected profile is approved, has an
active location, and the content document matches that location. A parent
account by itself grants no academy content.

Account approval and academy membership are separate: `users/{uid}` stores the
account-level status, while the selected `studentProfiles/{profileId}` status
controls student and parent membership routing. See
[`DEVELOPMENT_MEMBERSHIP_TESTING.md`](DEVELOPMENT_MEMBERSHIP_TESTING.md) for
the development academy address fields and safe live-admin testing setup.

## Local validation and release

Use a demo emulator project; automated tests do not contact live Firestore:

```powershell
npm --prefix tool/firebase_emulator_tests install
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
firebase emulators:exec --only firestore --project demo-ota-membership "npm --prefix tool/firebase_emulator_tests test"
```

After all tests pass, deploy only Rules:

```powershell
firebase deploy --only firestore:rules --project ota-management-platform
```

No seed, migration, Auth-user creation, database write, or other Firebase
deployment is part of this release.
