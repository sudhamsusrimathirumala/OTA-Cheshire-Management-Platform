# Android Production Compliance Handoff

## Objective

Prepare the Android app changes and compliance evidence needed for the next
public Google Play Production release without deploying, modifying production
data, building a release, or changing Play Console declarations.

## Current milestone

The clarified audience-model correction and validation are complete. The app
now distinguishes authenticated users from the subjects of linked student
records. Deliver the final evidence and integrate carefully with Flutter Web.

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
- Added exact backend enforcement in `firestore.rules`. Initial Student
  applicants must be at least 16 and Parent/Guardian applicants must be adults
  (18+) based on trusted `request.time`, while managed child profiles may remain
  younger than 16.
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
  registration, adult parent plus younger managed child, and an under-18
  applicant attempting to choose the Parent role.
- Verified current YouTube policy states that basic data is shared when an
  embedded player loads, more data is shared on playback, each embedded video's
  Made-for-Kids status must be checked, and a child-directed API client must be
  notified to Google. Privacy-enhanced mode does not eliminate collection.
- Preserved the 16+ and administrator behavior: no autoplay, no iframe before
  the existing affirmative Load action, privacy-enhanced mode, restricted
  related videos, and the pre-load data disclosure.
- Corrected the YouTube eligibility model after product clarification. A linked
  student's age is no longer treated as the authenticated user's age. Student,
  Parent, Admin, and Super Admin accounts may load curriculum video after the
  existing affirmative action; a parent may do so while a 10-year-old linked
  profile is selected. Guest Reviewer remains blocked from constructing the
  player.
- Removed the under-16-profile YouTube fallback and its copy-link behavior.
  Preserved click-to-load, no autoplay, privacy-enhanced mode, strict related
  videos, disabled annotations, and the pre-load disclosure.
- Audited every production profile-age use. Remaining uses are independent
  account onboarding, age display, belt/class training recommendations, and
  profile administration; none authorizes general app functionality.
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
  are academy curriculum content. The iframe is constructed only after an
  eligible authenticated user explicitly chooses to load it; the selected
  linked student's age does not control the adult account's access.
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
  cover authenticated-role video eligibility.
- Re-fetched the September 23, 2026 privacy policy. Its audience and YouTube
  description now match the corrected account/profile distinction.
- Corrected another audience-model edge: Parent/Guardian account holders are
  now required to be 18+ in the onboarding UI, profile service, and Firestore
  Rules. Student account eligibility remains 16+. This does not restrict
  parent- or staff-managed profiles for younger students.

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
- Clarified-audience focused Flutter suite: PASS, 97/97. A first attempt failed
  to compile after a new test referenced `SignInWithAppleButton` without its
  package import; adding the test-only import fixed it.
- Clarified curriculum suite: PASS, 18/18. It covers Parent with linked ages 10
  and 16, authenticated Student age 16, Admin, Super Admin, and Guest Reviewer.
- `flutter analyze --no-pub`: PASS, no issues found.
- Final clarified-audience focused suite including role-specific age checks:
  PASS, 122/122.
- Final full `flutter test --no-pub`: PASS, 454/454.
- Final full Firestore emulator suite: PASS, 59/59, including explicit proof
  that a location admin may update an under-16 student's training record.
- An initial emulator attempt did not run because Java was absent from `PATH`;
  retrying with Android Studio JBR started the emulator.
- The first retry did not run tests because this new worktree lacked local npm
  packages; `npm ci` restored the locked dependencies, after which 37/37 passed.
- `flutter pub get` resolved dependencies but returned exit code 1 after
  reporting that Windows Developer Mode symlink support is disabled. It still
  generated the package configuration needed for non-plugin unit/widget tests.

## Known blockers and unresolved questions

- The updated policy says any required authorization is handled through OTA's
  enrollment or academy processes. Code cannot verify that operational process;
  OTA must retain evidence supporting the statement.
- If provider cleanup fails after Login unexpectedly provisions an identity,
  the session is signed out and Firestore still prevents under-age onboarding;
  the orphaned Auth record may require normal support cleanup.
- YouTube requires the Made-for-Kids status of every embedded video to be
  checked regardless of the videos' public availability. OTA must inventory
  the production video IDs and document the result. Whether the API client or a
  portion of it is legally child-directed for authenticated 16-17-year-olds is
  a jurisdiction-specific determination; if it is, OTA must complete Google's
  child-directed notification and associated requirements.
- Genuine policy wording questions remain: guardian phone number is not
  collected by current production Dart code; deletion wording does not explain
  that shared profiles require assisted handling; and the policy links to, but
  does not expressly describe, Google Forms processing of deletion-request
  contact/account emails.
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
- `lib/screens/curriculum_screen.dart`

The `flutter-web` branch already removes the old selected-profile age gate from
`curriculum_screen.dart`, so integration may conflict on the same lines. Keep
this branch's authenticated-role/Guest Reviewer behavior. The Web branch also
changes authentication, account deletion, and startup; do not resolve those
files by taking this older branch wholesale. Preserve Web popup authentication,
Web reauthentication, platform-specific Crashlytics, and Hosting while retaining
the Android 16+ registration safeguards and Rules changes.

## Exact next action

Integrate the Android compliance commits with `flutter-web` using a deliberate
file-by-file conflict resolution. Re-run Web and Android authentication tests,
the full Flutter suite, and the Rules emulator after integration. Do not push,
deploy, build, or change Play Console unless the user gives a new explicit
instruction.
