# Android Production Compliance Handoff

## Objective

Prepare the Android app changes and compliance evidence needed for the next
public Google Play Production release without deploying, modifying production
data, building a release, or changing Play Console declarations.

## Current milestone

Reconcile production data flows, account deletion, and the published privacy
policy into the final Play Data safety worksheet and exact policy wording.

## Completed

- Created an isolated worktree at
  `C:\Users\ssvrm\.codex\worktrees\android-production-compliance\OTA-Cheshire-Management-Platform`.
- Created branch `android-production-compliance` from current `main` at
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
- Added shared exact calendar-age parsing and validation in
  `lib/services/registration_eligibility.dart`.
- Added a neutral, freely entered DOB field to Signup. Under-16 and malformed
  DOBs block email, Google, and Apple registration before authentication.
- Added exact backend enforcement in `firestore.rules`. Initial student and
  parent applicants must be at least 16 based on trusted `request.time`, while
  parent-managed child profiles may remain younger than 16.
- Changed production provider authentication so Login accepts existing
  Google/Apple identities but rejects newly provisioned identities. Apple
  authorization is revoked before deleting the unintended Auth user; provider
  cleanup is best effort and Firestore remains the authoritative completion
  boundary.
- Preserved interrupted onboarding: an existing incomplete Auth identity may
  return to profile setup, but cannot complete an under-16 member write because
  both Flutter validation and Firestore Rules enforce the age boundary.
- Added Flutter regression coverage for parsing, boundary ages, leap days,
  under-16 email/provider attempts, valid signup, and provider-login routing.
- Added Firestore emulator coverage for under-16 student bypass, exactly-16
  registration, adult parent plus younger managed child, and an under-16
  applicant attempting to choose the parent role.
- Verified current YouTube policy states that basic data is shared when an
  embedded player loads, more data is shared on playback, each embedded video's
  Made-for-Kids status must be checked, and a child-directed API client must be
  notified to Google. Privacy-enhanced mode does not eliminate collection.
- Preserved the 16+ and administrator behavior: no autoplay, no iframe before
  the existing affirmative Load action, privacy-enhanced mode, restricted
  related videos, and the pre-load data disclosure.
- Added a conservative fallback for selected profiles under 16. The app never
  constructs a YouTube iframe for those profiles and does not navigate to
  YouTube. It displays a canonical watch URL and lets a parent/guardian copy it
  for use with their own supervised YouTube settings; copying does not contact
  YouTube.
- Added tests proving the player builder is never called for an under-16
  profile, remains available at age 16, and remains available to administrators
  without reading a selected student profile.

## Files modified

- `CODEX_HANDOFF.md`
- `firestore.rules`
- `lib/screens/signup_screen.dart`
- `lib/screens/curriculum_screen.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/registration_eligibility.dart`
- `test/auth_navigation_test.dart`
- `test/curriculum_admin_test.dart`
- `test/registration_eligibility_test.dart`
- `test/signup_session_transition_test.dart`
- `tool/firebase_emulator_tests/client_workflows.js`
- `tool/firebase_emulator_tests/firestore_workflows.test.js`

## Tests run

- `flutter test --no-pub test/registration_eligibility_test.dart test/signup_session_transition_test.dart test/auth_navigation_test.dart test/account_deletion_service_test.dart`: PASS, 53/53.
- Focused Firestore emulator `firestore_workflows.test.js`: PASS, 37/37.
- `flutter test --no-pub test/curriculum_admin_test.dart test/privacy_policy_compliance_test.dart`: PASS, 24/24.
- An initial emulator attempt did not run because Java was absent from `PATH`;
  retrying with Android Studio JBR started the emulator.
- The first retry did not run tests because this new worktree lacked local npm
  packages; `npm ci` restored the locked dependencies, after which 37/37 passed.
- `flutter pub get` resolved dependencies but returned exit code 1 after
  reporting that Windows Developer Mode symlink support is disabled. It still
  generated the package configuration needed for non-plugin unit/widget tests.

## Known blockers and unresolved questions

- OTA still needs an operational decision for parental authorization; the app
  must not claim parental consent that the academy has not actually obtained.
- If provider cleanup fails after Login unexpectedly provisions an identity,
  the session is signed out and Firestore still prevents under-age onboarding;
  the orphaned Auth record may require normal support cleanup.
- Code cannot prove the current Made-for-Kids status of production Firestore
  video IDs or that OTA has notified YouTube that the embedded client is
  child-directed. OTA must inventory IDs, verify status through the YouTube Data
  API, document content review, and complete the applicable Google notification
  before public release.

## Shared-file conflict risks

The following likely changes may also be touched by the Flutter Web worktree:

- `lib/screens/signup_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/firebase/profile_service.dart`
- `firestore.rules`

All edits must remain narrowly scoped and documented for integration.

## Exact next action

Re-audit dependencies, manifests, startup initialization, account deletion,
phone-number paths, file/video/message flows, and the published privacy policy;
record the complete Data safety worksheet and exact proposed wording before
running full validation.
