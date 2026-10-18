# Build an unsigned OTA production AAB in GitHub Actions

This method needs **no local Android SDK** and **no keystore, upload key, or signing passwords**. GitHub's hosted Linux runner builds the production Flutter app and provides an unsigned Android App Bundle (AAB) as a downloadable artifact.

**Important:** An unsigned AAB is an intermediate build artifact; Google Play **will not accept it** for upload. To publish an update to the existing `com.otacheshire.app` Play Console listing, you must sign it with the academy's established upload key. The separate `Build Signed Android App Bundle` workflow exists for that purpose.

## Build instructions

1. Open [GitHub Actions: Build Unsigned Production AAB](https://github.com/sudhamsusrimathirumala/OTA-Cheshire-Management-Platform/actions/workflows/build-unsigned-android-aab.yml).
2. Select **Run workflow** and the **main** branch.
3. For `version_code`, leave `10` or choose another positive integer. This is the Android version code for the produced bundle; if you plan to sign and submit it to Google Play later, the code must exceed every version code previously uploaded there.
4. Start the run. It will install Flutter/Android build tools remotely, analyze code, run the feedback/bug-report test, compile the `prod` flavor and verify that the AAB is *unsigned*.
5. On success, download the `ota-prod-UNSIGNED-aab-vc...-run...` artifact from the workflow run's **Artifacts** section, then extract the ZIP.
6. The extracted `OTA-Cheshire-prod-UNSIGNED-vc<code>.aab` is the unsigned production bundle. GitHub retains the downloadable artifact for 7 days.

## Safety and release-signing behavior

- Normal production release tasks continue to refuse to run without configured signing credentials. The only exception is the explicit `OTA_ALLOW_UNSIGNED_PROD_AAB=true` environment flag **together with** a Gradle invocation requesting only `bundleProdRelease`.
- The unsigned workflow checks that no local `android/key.properties` exists. It never loads a keystore or creates a temporary signing key.
- The artifact filename includes `UNSIGNED` to avoid mistaking it for a Play-ready release.
- No Firebase resources, Google Play Console settings, or public app distribution are changed.
- The existing `Build Signed Android App Bundle` workflow remains the preferred publication path: [signed build instructions](ANDROID_AAB_GITHUB_ACTIONS.md).
- If you later sign this unsigned AAB outside GitHub Actions, the signing operation needs the **existing upload keystore** and a JDK (for `jarsigner`), but still does not require installing the Android SDK. Keep your keystore private and backed up.

The AAB is not directly installable on an Android device. For device testing without Play, create a signed APK or use a supported Play testing distribution workflow.
