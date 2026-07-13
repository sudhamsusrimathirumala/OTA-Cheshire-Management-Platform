# Spark-Compatible Onboarding

The onboarding foundation uses Firebase Authentication and client-side
Firestore atomic writes. It does not use Cloud Functions or another paid
Google Cloud service.

## Applicant submission

`FirestoreOnboardingService.submitApplication` requires the current Firebase
Auth user, loads the selected active location, evaluates the age gate against
that location's IANA time zone, and validates all application fields. It derives
the UID and normalized account email from Auth. A Google account ID is included
only when it appears in the authenticated user's `google.com` provider entry.

One `WriteBatch` creates exactly:

- `users/{firebaseUid}`
- `onboardingApplications/{firebaseUid}`

The UID is both document IDs. No student profile or permanent family
relationship is created before review. Firestore Rules use `getAfter()` to
require both documents in the same atomic operation. If the batch fails, the
Auth account remains and the user can retry; the service never deletes Auth
users and never uses email as an identity key. `loadCurrentAccountState`
returns `needsOnboarding` when both records are absent, so a later login can
route the authenticated user back into onboarding.

Applications support student applicants and parent applicants with up to ten
additional students. Every future student has a date of birth, belt rank, and
explicit guardian email. The application contains pending data only and cannot
include finalized IDs, guardian user relationships, or approval overrides.

## Admin review

Approved location admins may review pending applications for their own
location. Super Admin may review any location. Approval runs in one Firestore
transaction: it revalidates the reviewer, application, and active location;
creates every approved student profile; writes reciprocal user links; and marks
the user and application approved. Parent approvals generate one shared family
application ID. The parent's own profile is selected first when applicable.

Rejection atomically marks the user and application rejected, records reviewer
metadata and an optional short reason, and creates no profiles. Failed or
duplicate reviews leave no partial writes.

## Local validation

Use the demo project ID so emulator tests cannot reach live Firebase:

```powershell
npm --prefix tool/firebase_emulator_tests install
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
firebase emulators:exec --only firestore --project demo-ota-onboarding "npm --prefix tool/firebase_emulator_tests test"
```

## Release

Only Firestore Security Rules are deployed for this architecture:

```powershell
firebase deploy --only firestore:rules --project ota-management-platform
```

No database seed, migration, or data deployment is part of onboarding release.
