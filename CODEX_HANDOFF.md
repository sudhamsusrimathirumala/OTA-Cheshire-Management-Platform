# Android Production Compliance Handoff

## Objective

Prepare the Android app changes and compliance evidence needed for the next
public Google Play Production release without deploying, modifying production
data, building a release, or changing Play Console declarations.

## Current milestone

Implement the selected trusted under-16 registration gate while preserving
parent-managed profiles, existing accounts, federated authentication, and
interrupted onboarding.

## Completed

- Created an isolated worktree at
  `C:\Users\ssvrm\.codex\worktrees\android-production-compliance\OTA-Cheshire-Management-Platform`.
- Created branch `codex/android-production-compliance` from current `main` at
  `8c6760a5e6c198138d3980a0feb58d128a373e95`.
- Confirmed email signup creates Firebase Auth before DOB collection.
- Confirmed Google and Apple buttons on Signup invoke Firebase Auth before DOB
  collection.
- Confirmed Google sign-in on Login can create a new Firebase Auth user because
  Firebase credential sign-in also provisions previously unknown identities.
- Confirmed Flutter profile onboarding rejects an applicant younger than 16,
  but current Firestore rules validate only profile shape and ownership, not
  server-issued age eligibility.
- Confirmed parent-managed child profiles must remain able to contain DOBs for
  students younger than 16.
- Verified current Google Play Families policy requires a neutral age screen
  for mixed-audience handling and accurate disclosure of child data collected
  by APIs/SDKs.
- Verified Firestore Rules expose trusted `request.time` plus timestamp
  `year()`, `month()`, `day()`, and `timestamp.date(...)` operations. Selected
  direct Rules enforcement over a callable proof service, avoiding new runtime
  dependencies and retained proof records.
- Selected the registration design:
  1. collect a freely entered DOB on Signup without presetting the threshold;
  2. block under-16 email/Google/Apple registration before authentication;
  3. enforce exact applicant age again in Firestore Rules during the atomic
     initial user/profile batch;
  4. allow younger DOBs only for parent-managed child profiles;
  5. reject and clean up newly provisioned federated identities initiated from
     Login, directing legitimate new users to Signup;
  6. preserve incomplete Auth users so eligible users can safely resume profile
     onboarding, with Rules enforcing age when onboarding is completed.

## Files modified

- `CODEX_HANDOFF.md`

## Tests run

- None yet; this milestone is still in design/audit.

## Known blockers and unresolved questions

- Federated sign-in from Login must detect and remove a newly provisioned
  identity without breaking existing provider sign-in or Apple revocation
  ordering.
- OTA still needs an operational decision for parental authorization; the app
  must not claim parental consent that the academy has not actually obtained.

## Shared-file conflict risks

The following likely changes may also be touched by the Flutter Web worktree:

- `lib/screens/signup_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/firebase/profile_service.dart`
- `firestore.rules`

All edits must remain narrowly scoped and documented for integration.

## Exact next action

Implement a shared exact calendar-age helper with unit tests, add the neutral
Signup DOB gate, and add exact applicant-age enforcement to Firestore Rules and
the emulator regression suite.
