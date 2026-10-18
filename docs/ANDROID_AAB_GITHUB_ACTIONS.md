# Build a production Android App Bundle without installing an Android SDK

Use **GitHub Actions → Build Signed Android App Bundle**. The hosted Ubuntu runner installs the required Flutter/Android build tools. This workflow creates a production AAB for `com.otacheshire.app` with `lib/main_prod.dart` and **does not publish it to Google Play**.

## One-time signing setup

Reuse the **same existing upload keystore** used for previous OTA Google Play uploads. Creating a different keystore may cause Play Console to reject updates. Keep the original keystore backed up securely; never commit it or send it in an issue, PR, or chat.

From a Windows PowerShell console, replace the placeholder path with the actual keystore path:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\existing-upload-keystore.jks")) | Set-Clipboard
```

This copies the Base64 encoding to the clipboard. Base64 is **not encryption**; treat it as sensitive. Paste it directly into the repository secret input, not into source code or logs.

In GitHub, navigate to **Repository → Settings → Secrets and variables → Actions → New repository secret**, and create:

| Secret | Value |
| --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | Clipboard Base64 of your **existing** `.jks` or `.keystore` file |
| `ANDROID_UPLOAD_STORE_PASSWORD` | Existing keystore password |
| `ANDROID_UPLOAD_KEY_ALIAS` | Existing upload key alias |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Existing key password (may equal store password) |

Do not copy signing secrets from any public file. Only authorized academy maintainers should manage the upload key and these secrets.

## Build an AAB

1. Open **GitHub → Actions → Build Signed Android App Bundle**.
2. Select **Run workflow** and choose the **main** branch.
3. Enter a **version_code** greater than *every* version code already uploaded to Google Play. The suggested value `10` follows the repository's current `pubspec.yaml` version `1.0.0+9`, but verify the largest version code in Play Console first.
4. Select **Run workflow**.
5. After a successful run, open it and download the artifact named `ota-prod-aab-vc<code>-run<number>` under **Artifacts**. Extract its ZIP to obtain `app-prod-release.aab`.

The artifact expires after **7 days**. The AAB is ready for a **manual** upload to an appropriate Google Play testing track, subject to normal Play checks and signing compatibility. Don't upload the artifact ZIP itself.

The workflow intentionally fails when signing secrets are absent, does not fall back to a debug certificate, verifies the resulting AAB signature, and removes temporary signing files from the runner.

## Troubleshooting

- **Missing repository Actions secrets:** Add all four secrets. Never paste their values in a GitHub issue, Actions log, or chat.
- **Invalid Base64:** Re-encode the binary keystore file (not its filename or a text representation).
- **Wrong signing key/password:** Check the original keystore alias and passwords with the academy's authorized maintainer.
- **Google Play reports a version code conflict:** Run the workflow again with a larger `version_code`. You do not need to modify `pubspec.yaml` for this build.
- **Old app behavior:** Confirm the new workflow is running on `main` and not a stale feature branch. The production bundle must compile `lib/main_prod.dart`.

GitHub Actions requires **no local Android SDK** for this workflow.
