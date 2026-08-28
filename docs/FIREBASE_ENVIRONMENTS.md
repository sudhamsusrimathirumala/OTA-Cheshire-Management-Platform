# Firebase environments

## Ownership and isolation

The repository defines two explicit environments:

- `dev` belongs to the existing `ota-management-platform` Firebase project.
- `prod` belongs to the academy Firebase project
  `ota-management-platform-e4847`.

Environment choice comes from the entrypoint and native flavor, not from
`kDebugMode`. `main_dev.dart` imports only development options. `main_prod.dart`
imports only the production options. Debug Student/Admin shortcuts additionally
require the dev environment and a debug build.

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

The prod flavor is named `Olympic Taekwondo Academy` and uses the permanent
Android application ID `com.otacheshire.app`. Its matching configuration is:

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
development options. The prod bundle ID is `com.otacheshire.app`, matching the
production Firebase iOS app. Production configurations use
`Runner/Info-Prod.plist`, which contains the `REVERSED_CLIENT_ID` URL scheme
from the production Firebase plist; dev configurations continue to use
`Runner/Info.plist` unchanged.

On a Mac with Xcode, CocoaPods/Flutter tooling, and Apple signing access:

```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter build ios --flavor prod -t lib/main_prod.dart
flutter build ipa --flavor prod -t lib/main_prod.dart
```

Before those commands, the academy must provide the Apple Team ID and signing
certificate/profile. Enable Email/Password and Google providers and verify
password-reset authorized domains/action settings. Email/password and reset
code is platform-neutral Firebase Auth code; Google Sign-In uses the configured
production URL scheme.

Never commit Apple signing certificates, `.p12` files, private keys,
provisioning profiles, App Store Connect API private keys, or keystore
passwords.

## Firebase options

`lib/firebase_options_dev.dart` contains normal client configuration generated
for `ota-management-platform`. `lib/firebase_options_prod.dart` contains the
Android and iOS client configurations for `ota-management-platform-e4847` and
remains fail-closed on platforms that have not been configured. Production
values must not contain development project IDs, app IDs, sender IDs, storage
buckets, or API keys.

## CLI and deployment safety

`.firebaserc` defines separate `dev` and `prod` aliases. Never run an
unqualified deployment. Firestore Rules commands must always name the alias:

```powershell
firebase deploy --only firestore:rules --project dev
firebase deploy --only firestore:rules --project prod
```

Production deployment remains forbidden until a human explicitly authorizes
the production target. Verify the resolved project in the CLI output before
approving any deployment. The development project currently remains on Spark.
Blaze billing and Cloud Functions deployment remain pending explicit academy
approval and must never be inferred from the presence of Functions code in this
repository.

## Academy-provided items still required

- A refreshed development iOS plist for the registered dev bundle.
- Firebase Auth provider setup, OAuth support email, and authorized domains.
- Android debug/release SHA fingerprints and OAuth clients.
- Apple signing/team configuration.
- Private Android and Apple release-signing material, stored outside Git.
- Explicit Blaze billing approval and authorization for the reviewed Functions
  deployment target.
