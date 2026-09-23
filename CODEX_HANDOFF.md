# OTA Cheshire Flutter Web handoff

## Objective

Implement a production-capable Flutter Web target for iPhone browser and Home Screen use while preserving the existing Android/iOS behavior, production Firebase authorization model, and Guest Reviewer isolation. Prepare but do not deploy Firebase Hosting or change production Firebase settings.

## Current milestone

Repository-side Web implementation and validation are complete. The work is blocked only on authorized external production setup, genuine Firebase Web values, integration with the Android branch's authentication changes, and physical/preview browser validation.

## Completed

- Created the isolated managed worktree at `C:\Users\ssvrm\.codex\worktrees\ota-flutter-web\OTA-Cheshire-Management-Platform` from current `main`.
- Created the isolated Web branch at commit `8c6760a`; it is named `flutter-web` per the repository naming requirement.
- Rechecked the Web implementation brief and current repository configuration.
- Confirmed the production Firebase options and repository mappings still have Android/iOS only.
- Added deferred production Firebase Web options sourced only from compile-time `OTA_FIREBASE_WEB_*` values, with an actionable safe startup failure when required values are absent.
- Moved Crashlytics construction behind native/stub conditional imports so Flutter Web does not load or invoke Crashlytics.
- Deferred Firebase Messaging, local notifications, and push-navigation setup on Web while preserving the existing native path.
- Hardened startup diagnostics so a failed Crashlytics attachment is not treated as active reporting.
- Added focused coverage for Web Firebase option validation, safe startup errors, Web push deferral, and reporter attachment failure.
- Added a testable Firebase Web authentication adapter using `signInWithPopup` and `reauthenticateWithPopup`.
- Configured Google Web authentication to request `prompt=select_account` so signed-out users can deliberately switch accounts.
- Kept Firebase Auth as the canonical Web sign-out and avoided the unsupported native `google_sign_in` cleanup path on Web.
- Mapped Web popup cancellation to safe, non-destructive sign-in/deletion cancellation behavior.
- Prepared the existing classic Hosting site for `build/web` with SPA rewrites, source-map exclusion, conservative caching, and baseline security headers; no deployment was run.
- Added OTA title/description/theme/Home Screen metadata and a stable manifest root ID/scope.
- Replaced default Flutter Web icons with deterministic square derivatives of the repository's existing OTA logo; the logo artwork itself was not redrawn.
- Documented exact production Web app registration, Firebase Auth/OAuth/Apple prerequisites, build definitions, preview-channel workflow, rollback, privacy wording, Web Push deferral, and physical-iPhone checks.
- Expanded narrow-screen coverage to Welcome, Resources, Guest, Admin Dashboard, and Admin Profile; fixed real Welcome vertical and Admin Profile horizontal overflows.

## Files modified

- `lib/app_bootstrap.dart`
- `lib/firebase_options_prod.dart`
- `lib/main_prod.dart`
- `lib/services/startup_diagnostics.dart`
- `lib/services/startup_crash_reporter_native.dart`
- `lib/services/startup_crash_reporter_stub.dart`
- `lib/services/startup_failure.dart`
- `test/app_bootstrap_test.dart`
- `test/startup_diagnostics_test.dart`
- `test/firebase_options_prod_web_test.dart`
- `lib/services/firebase/web_authentication.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/firebase/account_deletion_service.dart`
- `test/firebase_authentication_service_test.dart`
- `test/account_deletion_service_test.dart`
- `firebase.json`
- `web/index.html`
- `web/manifest.json`
- `web/favicon.png`
- `web/icons/*.png`
- `README.md`
- `docs/CODEBASE_GUIDE.md`
- `lib/screens/welcome_screen.dart`
- `lib/screens/admin/admin_profile_screen.dart`
- `test/layout_overflow_regression_test.dart`
- `test/web_deployment_config_test.dart`
- `CODEX_HANDOFF.md`

## Tests run

- `flutter pub get`: dependencies resolved, but the command exited 1 because Windows Developer Mode/symlink support is disabled. It created the local package configuration and did not modify tracked dependency files.
- `flutter test --no-pub test/app_bootstrap_test.dart test/startup_diagnostics_test.dart test/firebase_options_prod_web_test.dart`: PASS, 12 tests.
- `flutter analyze --no-pub`: PASS, no issues found.
- `flutter test --no-pub test/firebase_authentication_service_test.dart test/account_deletion_service_test.dart`: PASS, 41 tests.
- `flutter analyze --no-pub` after milestone 2: PASS, no issues found.
- `flutter test --no-pub test/web_deployment_config_test.dart test/privacy_policy_compliance_test.dart`: PASS, 11 tests after correcting the new test's map matcher.
- `flutter test --no-pub test/layout_overflow_regression_test.dart test/schedule_layout_regression_test.dart`: PASS, 12 tests before expanding route coverage.
- Expanded `test/layout_overflow_regression_test.dart`: initially found real Welcome/Admin Profile overflows; after fixes, PASS, 6 viewport/text-scale combinations.
- `flutter analyze --no-pub` after milestone 3: PASS, no issues found.
- `flutter test --no-pub --platform chrome ...`: INCONCLUSIVE; the local Chrome harness never connected or emitted a result after two minutes and was stopped. Do not count as a browser pass.
- `firebase hosting:sites:list --project prod`: read-only PASS; confirms site `ota-management-platform-e4847` at `https://ota-management-platform-e4847.web.app` with no associated Web App ID.
- `firebase apps:list --project prod`: read-only PASS; lists Android/iOS only and confirms no production Web app registration.
- First Firestore emulator attempt: did not run the Rules tests because this fresh worktree lacked `tool/firebase_emulator_tests/node_modules`; emulator startup itself was successful and production access was disabled by the `demo-*` project.
- `npm --prefix tool/firebase_emulator_tests ci`: PASS, 87 locked packages installed, 0 vulnerabilities reported.
- `firebase emulators:exec --only firestore --project demo-ota-active-access "npm --prefix tool/firebase_emulator_tests test"`: PASS, 54/54 tests.
- `flutter test --no-pub`: PASS, 450/450 tests.
- Official documentation review: confirms Firebase Auth popup support, Firebase Web config registration, FCM Web VAPID/service-worker requirements, iOS 16.4+ Home Screen Web Push constraints, and current Web support declarations for the audited plugins.

## Blockers and unresolved questions

- Production Firebase Web app credentials are not available and must not be invented.
- A production Web release build was not run because genuine production Web app values do not exist yet.
- The local Chrome test harness did not connect; preview Chrome and physical iPhone Safari runtime checks remain required.
- The installed Firebase CLI exposes no read-only deployed-Rules retrieval command, so checked-in Rules were audited but were not proven byte-for-byte identical to the deployed production ruleset.
- Production Firebase/Apple/Google console settings must remain unchanged without explicit authorization.
- Apple Web Sign-In cannot be completed until Apple Service ID, Team ID, Key ID, and private key configuration exists.
- iPhone OS-level Web Push is intentionally outside the first release.

## Shared-file conflict risk

The Android compliance task is in a separate worktree. Likely shared files requiring reconciliation later include:

- `lib/app_bootstrap.dart`
- `lib/services/startup_diagnostics.dart`
- `lib/services/firebase/firebase_authentication_service.dart`
- `lib/services/firebase/account_deletion_service.dart`
- `firebase.json`
- `web/index.html`
- authentication, account-deletion, startup, and layout tests

Current observed overlap with the Android compliance branch:

- `lib/services/firebase/firebase_authentication_service.dart` is modified by both branches. The Android branch adds provider registration-vs-sign-in safeguards and this branch adds Web popup/sign-out behavior; these changes must be reconciled manually rather than choosing either whole file.
- Both worktrees maintain their own `CODEX_HANDOFF.md`; do not merge one over the other mechanically.
- The Android worktree currently has uncommitted changes to `lib/screens/account_deletion_screen.dart` and `test/account_deletion_screen_test.dart`. This Web branch changes the deletion service/tests, so preserve both layers during integration.

## Exact next action

Manually integrate the Android branch's registration safeguards with this branch's Web popup logic in `lib/services/firebase/firebase_authentication_service.dart`, then rerun both branches' authentication/signup tests. After an authorized operator registers the production Firebase Web app, supply the generated `OTA_FIREBASE_WEB_*` values, run the documented release build and Hosting preview workflow, and complete the physical iPhone Safari/Home Screen checklist. Do not deploy the live site without explicit approval.
