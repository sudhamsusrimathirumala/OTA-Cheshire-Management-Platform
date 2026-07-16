# Authentication, Profiles, and Academy Access

The OTA identity flow uses Firebase Authentication and direct,
Spark-compatible Firestore writes. It deploys no Cloud Functions and requires
no billing account or paid Google Cloud service.

## Authentication and routing

`FirebaseAuthenticationService` supports email/password signup and login,
Google Sign-In, neutral password reset, refresh, sign out, and safe error
mapping. Email verification is not required to create profiles. Firebase UID
is the permanent identity; email is contact data. A Google provider UID comes
only from the authenticated `google.com` provider entry.

`FirebaseSessionController` observes Auth, `users/{uid}`, linked profiles, the
selected profile, and its location. `AuthGate` is the routing authority. Its
runtime stages are `loading`, `signedOut`, `needsProfiles`, `member`,
`disabled`, `adminDisabled`, `admin`, and `error`.

## Atomic profile creation

Authenticated users complete the existing three-step flow with a 16+ account
holder gate. Students create one self-linked profile. Parents may create their
own student profile and up to ten additional children, or one through ten
children without a personal student profile.

Profile setup reads active `locations` documents:

- Exactly one active location is assigned automatically.
- More than one active location displays one account-level selector.
- No active location blocks creation and presents Retry and Sign out.

The final review shows the academy name and available address. One Firestore
`WriteBatch` creates `users/{uid}` and every `studentProfiles` document. The
user and all profiles receive the same `locationId` and `isActive: true`, so
partial or unassigned onboarding records are not created.

After the batch succeeds, the app shows **Your account is ready**, the academy
location, created profiles, **Continue to Dashboard**, and **Sign out**. The
user then has immediate academy access.

### Parent self-profile defaults

When a parent does not create a personal student profile during onboarding,
the already-collected account-holder birth date and belt are retained in the
optional `users/{uid}.studentProfileDefaults` map. An optional contact email
and initialized sticker progress are stored there as well. Account name,
account email, phone number, and `locationId` remain canonical user fields and
are not duplicated in the defaults.

These defaults are form data only: they do not grant profile access and are
not a student profile. When the parent later chooses **Add my student
profile**, the app reuses the account fields and defaults, asks only for a
genuinely missing birth date or belt, and atomically creates one self-linked
profile while appending its ID to the existing user document. Parents who
create their own profile during onboarding do not receive a duplicate defaults
map because their self-linked profile is immediately canonical.

Reads also recognize the former top-level birth-date, belt, contact-email, and
sticker-progress field names for compatibility. Canonical nested defaults take
priority, and normal reads never rewrite or migrate legacy records.

## Active-access checks

A student or parent may access academy data only when:

- the Firebase-authenticated UID has a valid user document;
- the account role is `student` or `parent` and `isActive` is true;
- the selected profile is linked to that account and exists;
- the selected profile has `isActive` true;
- the user and profile `locationId` values match; and
- the referenced academy location exists and is active.

Missing or malformed data fails closed. Profile switching updates only
`selectedStudentProfileId`; every profile under the account remains at the
same academy location.

Admin accounts are configured manually and are never publicly selectable.
Location Admin access requires role `admin`, `isActive: true`, and an active
assigned location. Super Admin retains the controlled multi-location model.

## Historical Design Decision: Membership Approval (Inactive)

An earlier, intentional design kept permanent profiles separate from academy
membership. Families submitted profile applications to a location, and an
administrator reviewed them before academy content became available. That
approach anticipated controlled enrollment and multiple independently managed
locations.

The final workflow was simplified after reviewing actual release needs. There
is currently one active academy location. Requiring review for every household
adds friction for parents, students, and staff, while authentication and linked
account/profile records already provide the needed identity and household
structure. Young siblings are unlikely to attend unrelated OTA locations, and
older independent students can create and manage their own account. The review
workflow also introduced substantial UI, routing, Firestore Rules,
administrative, backend, and testing complexity.

Immediate access better fits the current academy and helps the application
reach a reliable release state without removing authentication, privacy,
role restrictions, active-record controls, or location isolation. The idea may
be reconsidered if actual expansion or identity-verification needs justify it.

This workflow is retained here as project design history. It is not part of the
current runtime, Firestore schema, security rules, or user experience.
