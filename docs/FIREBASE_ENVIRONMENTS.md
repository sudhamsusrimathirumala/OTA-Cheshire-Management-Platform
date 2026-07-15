# Firebase environments

## Ownership and isolation

The repository defines two explicit environments:

- `dev` belongs to the existing `ota-management-platform` Firebase project.
- `prod` will belong to a separate academy-owned Firebase project that does not
  exist in this repository yet.

Environment choice comes from the entrypoint and native flavor, not from
`kDebugMode`. `main_dev.dart` imports only development options. `main_prod.dart`
imports only the production placeholder, which throws a clear configuration
error and contains no development project identifiers. Debug Student/Admin
shortcuts additionally require the dev environment and a debug build.

`lib/main.dart` is deliberately fail-closed and never chooses an environment.
Android pins every Flutter compilation task to the entrypoint for its selected
flavor, even if a conflicting `-t` is supplied. Each iOS build configuration
sets `FLUTTER_TARGET` to its matching entrypoint, so direct Xcode builds and
archives follow the selected scheme.

Supported combinations are dev debug, dev release, and prod release. Routine
prod debug builds are intentionally not part of the workflow.

## Android

Use:

```powershell
flutter run --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --release --flavor dev -t lib/main_dev.dart
```

The dev flavor is named `OTA Dev` and currently uses
`com.otamanagement.app`, the package already registered in the development
Firebase project. Changing it to a `.dev` package requires registering a new
Android app in that project and downloading a matching configuration; editing
the package inside the existing file would create invalid credentials.

The prod flavor is named `Olympic Taekwondo Academy` and currently uses
`com.academy.olympictaekwondo.placeholder`. The academy must confirm the final
package name, register it in the production Firebase project, and provide:

`android/app/src/prod/google-services.json`

The development file is isolated at:

`android/app/src/dev/google-services.json`

For Google Sign-In, register debug and release SHA-1 and SHA-256 fingerprints
for each Android Firebase app and download a refreshed matching file. Release
distribution also requires a private signing keystore configured outside Git.

## iOS

The shared Xcode project contains `dev` and `prod` schemes plus matching
Debug/Release/Profile configurations. Each sets `APP_ENVIRONMENT`; the copy
script accepts only:

- `ios/Firebase/dev/GoogleService-Info.plist`
- `ios/Firebase/prod/GoogleService-Info.plist`

There is no fallback between them, and a missing matching plist fails the
Xcode build clearly. The current dev bundle ID remains
`com.example.otaCheshireManagementPlatform` to match the existing generated
development options. The prod bundle ID is the placeholder
`com.academy.olympictaekwondo.placeholder`. Both must be reviewed in the
Firebase console and Apple Developer account before release.

On a Mac with Xcode, CocoaPods/Flutter tooling, and Apple signing access:

```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter build ios --flavor prod -t lib/main_prod.dart
flutter build ipa --flavor prod -t lib/main_prod.dart
```

Before those commands, the academy must provide the final production bundle
ID, Apple Team ID, signing certificate/profile, and production plist. Register
the iOS app in Firebase, enable Email/Password and Google providers, add the
`REVERSED_CLIENT_ID` URL scheme from the matching plist in Xcode, and verify
email verification and password-reset authorized domains/action settings.
Email/password, verification, and reset code is platform-neutral Firebase Auth
code; Google Sign-In requires this native URL-scheme setup.

Never commit Apple signing certificates, `.p12` files, private keys,
provisioning profiles, App Store Connect API private keys, or keystore
passwords.

## Firebase options

`lib/firebase_options_dev.dart` contains normal client configuration generated
for `ota-management-platform`. `lib/firebase_options_prod.dart` is a deliberate
fail-closed placeholder. After the academy project exists, generate production
options for the final package/bundle identifiers and review the diff to ensure
that no development project ID, app ID, sender ID, storage bucket, or API key
appears in the production file.

## CLI and deployment safety

`.firebaserc` defines `dev` and a deliberately invalid prod placeholder. Never
run an unqualified deployment. Firestore Rules commands must always name the
alias:

```powershell
firebase deploy --only firestore:rules --project dev
firebase deploy --only firestore:rules --project prod
```

Production deployment is forbidden until the academy project ID replaces the
placeholder and a human explicitly confirms the production target. Verify the
resolved project in the CLI output before approving any deployment. This
repository remains Spark-only: do not add billing, Cloud Functions, or paid
services.

## Academy-provided items still required

- Production Firebase project ID and ownership/access details.
- Final Android application ID and matching production JSON.
- Final iOS bundle ID and matching production plist.
- A refreshed development iOS plist for the registered dev bundle.
- Firebase Auth provider setup, OAuth support email, and authorized domains.
- Android debug/release SHA fingerprints and OAuth clients.
- iOS reversed-client-ID URL scheme and Apple signing/team configuration.
- Private Android and Apple release-signing material, stored outside Git.
