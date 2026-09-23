# OTA Cheshire Flutter Web handoff

## Objective

Implement a production-capable Flutter Web target for iPhone browser and Home Screen use while preserving the existing Android/iOS behavior, production Firebase authorization model, and Guest Reviewer isolation. Prepare but do not deploy Firebase Hosting or change production Firebase settings.

## Current milestone

Milestone 2 complete: Google authentication and account-deletion reauthentication use Firebase Auth popup flows on Web while native behavior remains intact. The next milestone is production Hosting configuration, browser metadata, and documented Firebase Console prerequisites.

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
- `CODEX_HANDOFF.md`

## Tests run

- `flutter pub get`: dependencies resolved, but the command exited 1 because Windows Developer Mode/symlink support is disabled. It created the local package configuration and did not modify tracked dependency files.
- `flutter test --no-pub test/app_bootstrap_test.dart test/startup_diagnostics_test.dart test/firebase_options_prod_web_test.dart`: PASS, 12 tests.
- `flutter analyze --no-pub`: PASS, no issues found.
- `flutter test --no-pub test/firebase_authentication_service_test.dart test/account_deletion_service_test.dart`: PASS, 41 tests.
- `flutter analyze --no-pub` after milestone 2: PASS, no issues found.

## Blockers and unresolved questions

- Production Firebase Web app credentials are not available and must not be invented.
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

## Exact next action

Add production-safe Firebase Hosting rewrites/cache/security headers and OTA browser/PWA metadata. Document required Firebase Web app registration, authorized domains/OAuth setup, privacy-policy review, Web Push deferral, local build inputs, preview-channel validation, and rollback without changing production settings or deploying.
