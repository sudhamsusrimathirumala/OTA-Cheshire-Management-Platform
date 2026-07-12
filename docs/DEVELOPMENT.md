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
