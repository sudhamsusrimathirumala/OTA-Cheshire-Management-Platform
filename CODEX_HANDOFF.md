# Android Production Compliance Handoff

## Objective

Prepare the Android app changes and compliance evidence needed for the next
public Google Play Production release without deploying, modifying production
data, building a release, or changing Play Console declarations.

## Current milestone

Validation and code changes are complete. Assemble and deliver the final
evidence-based release decision, Data safety worksheet, privacy-policy wording,
and remaining operational release gates.

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
- Resolved the Android `prodReleaseRuntimeClasspath` without building. The
  resolved Firebase BOM is 34.15.0; Crashlytics 20.0.6 transitively includes
  Firebase Sessions 3.0.6 and Installations 19.1.1; Messaging 25.1.0 also uses
  Installations. Firebase Analytics and advertising SDKs are absent.
- Confirmed production initialization enables Crashlytics and registers the FCM
  background handler at Firebase startup. Crashlytics records sanitized error
  types, stack traces, startup checkpoints, the app environment, SDK-collected
  device metadata, Crashlytics/Firebase installation IDs, and Sessions app
  foreground metadata. It never sets a Firebase user identifier.
- Confirmed FCM permission/token registration only proceeds for active Student
  or Parent member sessions with linked profiles. The app stores the FCM token,
  platform, environment, timestamps, and a local random installation ID in the
  member's `pushDevices` subcollection and deletes those records and the token
  best-effort on sign-out/deletion.
- Confirmed Firebase Auth/Firestore handle name, email, Firebase UID, date of
  birth, role, academy location, guardian relationship/email, rank, progress,
  preferences, testing notes, and promotion history. The production Dart code
  has no phone-number collection/read/write path; only compatibility allowances
  remain in Firestore Rules and tests.
- Confirmed `file_picker` is referenced only by the separate development
  Firestore export entrypoint, which refuses release mode. Production
  `main_prod.dart` cannot collect files or documents through it.
- Confirmed production does not collect user-provided videos. YouTube video IDs
  are academy curriculum content; for users 16+ and staff, the iframe is only
  constructed after an explicit action. Under-16 profiles never construct it.
- Confirmed App activity must be declared because Firebase Sessions collects
  session-start/foreground metadata and Firestore stores notification-read state
  and preferred-class interactions. Other in-app messages must remain declared
  because authorized staff enter announcement title/summary/body. Other
  user-generated content should also be declared for staff-authored testing
  notes and event/resource descriptions.
- Confirmed source Android permissions are only INTERNET and
  POST_NOTIFICATIONS. No AD_ID, location, telephony, camera, microphone, media,
  or storage permission is declared. Firebase documents HTTPS transport and
  encryption at rest for the used services. Academy resource links are launched
  externally and may be `http` or `https`; no account data is appended, so this
  is not app-to-backend plaintext transmission, but OTA should inventory links
  and prefer HTTPS before release.
- Re-fetched the published privacy policy and external deletion form. The exact
  public privacy URL and deletion form URL match the app constants, and the form
  works without requiring the app to be installed.
- Corrected member deletion copy to describe the actual exclusive-ownership
  guard. Automatic deletion stops rather than deleting a student profile shared
  with another account. Added the external deletion-request path for all member
  accounts, including accounts without a supported in-app reauthentication
  provider, while preserving authentication and authorization checks.
- Updated the older general curriculum widget fixture to use an explicit adult
  profile so its player expectations remain valid. Dedicated tests separately
  prove that an under-16 profile never constructs the player.

## Files modified

- `CODEX_HANDOFF.md`
- `firestore.rules`
- `lib/screens/signup_screen.dart`
- `lib/screens/curriculum_screen.dart`
- `lib/screens/account_deletion_screen.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/registration_eligibility.dart`
- `test/auth_navigation_test.dart`
- `test/curriculum_admin_test.dart`
- `test/account_deletion_screen_test.dart`
- `test/registration_eligibility_test.dart`
- `test/signup_session_transition_test.dart`
- `test/widget_test.dart`
- `tool/firebase_emulator_tests/client_workflows.js`
- `tool/firebase_emulator_tests/firestore_workflows.test.js`

## Tests run

- `flutter test --no-pub test/registration_eligibility_test.dart test/signup_session_transition_test.dart test/auth_navigation_test.dart test/account_deletion_service_test.dart`: PASS, 53/53.
- Focused Firestore emulator `firestore_workflows.test.js`: PASS, 37/37.
- `flutter test --no-pub test/curriculum_admin_test.dart test/privacy_policy_compliance_test.dart`: PASS, 24/24.
- `flutter test --no-pub test/account_deletion_screen_test.dart test/account_deletion_service_test.dart test/privacy_policy_compliance_test.dart`: PASS, 47/47 before adding the final unsupported-provider regression case.
- Final account-deletion focused rerun: PASS, 48/48.
- `flutter analyze`: PASS, no issues found.
- Final focused compliance suite across registration, authentication,
  curriculum, privacy, deletion, Android startup, Crashlytics diagnostics, push,
  and identity contracts: PASS, 148/148.
- The first focused-suite command named a nonexistent
  `test/push_notification_service_test.dart`; 122 loaded tests passed, but the
  command exited nonzero. The corrected repository filenames were used in the
  final 148/148 run.
- The first full Flutter run found one outdated test fixture: the general
  curriculum fixture had no DOB (therefore correctly failed closed as under
  16) while expecting a player. After assigning that fixture an explicit adult
  DOB, the failed test passed 1/1 and the complete Flutter suite passed 450/450.
- Full Firestore emulator suite, using local demo project
  `demo-ota-compliance`: PASS, 58/58. The expected `PERMISSION_DENIED` emulator
  logs are assertions for rejected unauthorized operations.
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
- Code cannot verify OTA's real-world parental authorization process. Firebase
  collection from users of the parent-managed under-16 experience is disclosed
  and limited to app functionality, authentication, notification delivery, and
  diagnostics, but OTA must document the lawful parent/guardian authorization
  it actually obtains rather than relying only on policy text.
- The published policy needs wording changes: remove phone number unless OTA
  confirms a current collection path; state that under-16 profiles never load
  the embedded YouTube player; describe shared-profile assisted deletion and
  provider diagnostic/installation retention; disclose contact/account email
  processing by the external Google Forms deletion path; and explain whether
  staff-authored institutional content remains after an administrator account
  is deleted. Remove the confusing `Updated automatically every 5 minutes`
  line if it is document content rather than Google Docs chrome.
- The Play Console itself was not available, so its saved answers could not be
  read. The release worksheet must declare Name, Email, User IDs, Other personal
  info, Crash logs, Diagnostics, Device or other IDs, App activity, Other in-app
  messages, and Other user-generated content. Phone number, Files and docs, and
  Videos should be `No` for this code unless another active artifact or
  production process still collects them.

## Shared-file conflict risks

The following likely changes may also be touched by the Flutter Web worktree:

- `lib/screens/signup_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/firebase/profile_service.dart`
- `firestore.rules`

All edits must remain narrowly scoped and documented for integration.

## Exact next action

Run final `flutter analyze`, `git diff --check`, and `git status --short`; create
a local checkpoint commit for the test-fixture and handoff updates; then deliver
the final report. Do not push, merge, build, deploy, or change Play Console.
