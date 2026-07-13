# Development Guide

## Requirements

- Flutter SDK and bundled Dart SDK
- Android Studio or VS Code
- Android SDK and an Android emulator or device
- Valid Firebase platform configuration and Firestore access
- Git

Visual Studio is required only for Windows desktop builds, specifically the C++
desktop workload. It is not required for Android or web development.

## Setup

```powershell
flutter pub get
flutter doctor
flutter devices
flutter run
```

The normal application initializes Firebase from `lib/firebase_options.dart`.

## Firebase Authentication setup

The code includes `firebase_auth`, `google_sign_in`, a Firebase UID identity
contract, and provider-data extraction. Full login, signup, linking,
onboarding, and approval screens are intentionally not implemented yet.

Manual Firebase/platform setup still required:

1. In Firebase Console Authentication, enable Email/Password.
2. Enable Google, select a project support email, and save the provider.
3. Add Android debug/release SHA-1 and SHA-256 fingerprints when required,
   then refresh `google-services.json` and generated FlutterFire options.
4. For iOS/macOS, refresh `GoogleService-Info.plist` and configure the reversed
   client-ID URL scheme. Do not commit private keys or client secrets.
5. For web, add authorized domains and configure the correct OAuth web client,
   then refresh Firebase platform configuration.
6. Re-run `flutterfire configure` after Firebase app/provider configuration
   changes and review generated files before committing.

Onboarding must create `users/{FirebaseAuth.currentUser.uid}` with only safe
fields, role `student` or `parent`, and initial approval `incomplete` or
`pending`. It must not query by email as identity, choose an admin role,
self-approve, or set `googleAccountId` except from authenticated `google.com`
provider data. Normal academy data remains unavailable until approval. The
rules in `firestore.rules` must be reviewed with emulator tests before deploy;
this repository change does not deploy them.

## Common Run Targets

Normal application:

```powershell
flutter run -t lib/main.dart
```

Development-only, read-only utilities:

```powershell
flutter run -t lib/firestore_audit_main.dart
flutter run -t lib/firestore_export_main.dart
```

Development-only, write-capable utilities:

```powershell
flutter run -t lib/firestore_cleanup_main.dart
flutter run -t lib/firestore_schema_update_main.dart
flutter run -t lib/seed_firestore_main.dart
flutter run -t tool/seed_firestore.dart
```

Do not run a write-capable target until its current flags and behavior have
been reviewed. Details are in [Firestore operations](FIRESTORE_OPERATIONS.md).

## Quality Checks

```powershell
dart format lib test
flutter analyze
flutter test
git diff --check
```

## Safe Development Rules

- Keep development-only write flags disabled except during an explicitly
  approved operation, and disable them immediately afterward.
- Do not run seed, migration, cleanup, or historical schema tools casually.
- Do not commit an enabled write switch.
- Verify the Firebase project ID before any database write operation.
- Never place credentials, tokens, or private keys in documentation.
- Keep database utilities out of normal production navigation.

## Android APK

Local builds:

```powershell
flutter build apk
flutter build apk --release
```

The Android application ID is `com.otamanagement.app`. The current release
build type still uses debug signing and is not ready for production
distribution.

The `Build Debug APK Release` GitHub Actions workflow is manual. It builds a
debug APK, renames it to `OTA-Cheshire-debug.apk`, creates a tag named
`apk-<run_number>`, and attaches the APK to a GitHub Release. It does not build
or sign a production release artifact.
