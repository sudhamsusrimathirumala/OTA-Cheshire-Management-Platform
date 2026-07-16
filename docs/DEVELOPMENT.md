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
flutter run --flavor dev -t lib/main_dev.dart
```

The development application initializes Firebase from
`lib/firebase_options_dev.dart`. Production configuration is intentionally
absent. See [Firebase environments](FIREBASE_ENVIRONMENTS.md).

## Firebase Authentication setup

The app uses `firebase_auth`, `google_sign_in`, Firebase UID identity, atomic
profile creation, active-account controls, and location-based access. Provider
linking is intentionally not part of this implementation.

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

Profile creation derives identity from `FirebaseAuth.currentUser` and uses
`FirestoreProfileService` to atomically create the UID user document and
permanent active profiles at one academy location. See
[Authentication, profiles, and academy access](ONBOARDING_BACKEND.md).

This project permanently targets the no-cost Firebase Spark plan. Do not link a
billing account, add a paid service, deploy server functions, or add
monetization. Deploy only Firestore Rules when explicitly required.

## Common Run Targets

Development application:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

Mock services remain available to automated tests and internal development
harnesses. The public Welcome screen exposes no Student or Admin bypass. Real
authenticated sessions always use Firebase and show listener failures instead
of substituting sample data.

Development-only, read-only utilities:

```powershell
flutter run --flavor dev -t lib/firestore_audit_main.dart
flutter run --flavor dev -t lib/firestore_export_main.dart
```

Development-only, write-capable utilities:

```powershell
flutter run --flavor dev -t lib/firestore_cleanup_main.dart
flutter run --flavor dev -t lib/firestore_schema_update_main.dart
flutter run --flavor dev -t lib/seed_firestore_main.dart
flutter run --flavor dev -t tool/seed_firestore.dart
```

Do not run a write-capable target until its current flags and behavior have
been reviewed. Details are in [Firestore operations](FIRESTORE_OPERATIONS.md).

## Quality Checks

```powershell
dart format lib test tool
flutter analyze
flutter test
git diff --check
```

Firestore emulator tests:

```powershell
npm --prefix tool/firebase_emulator_tests install
firebase emulators:exec --only firestore --project demo-ota-active-access "npm --prefix tool/firebase_emulator_tests test"
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
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --release --flavor dev -t lib/main_dev.dart
```

The development Android application ID remains `com.otamanagement.app` because
that is the package registered in the existing development Firebase client.
The `prod` flavor uses an unmistakable placeholder until the academy confirms
its final package name. The current release build type still uses debug signing
and is not ready for production distribution.

The `Build Debug APK Release` GitHub Actions workflow is manual. It builds a
debug APK, renames it to `OTA-Cheshire-debug.apk`, creates a tag named
`apk-<run_number>`, and attaches the APK to a GitHub Release. It does not build
or sign a production release artifact.
