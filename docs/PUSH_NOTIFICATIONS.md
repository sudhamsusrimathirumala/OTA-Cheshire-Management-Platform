# Push notifications

## Architecture

When an administrator first publishes an announcement, event, or general
resource, a second-generation Firestore Cloud Function claims a deterministic
`pushDispatches/{contentType}_{contentId}` record. It resolves active family
accounts at the content location, loads enabled registrations from
`users/{uid}/pushDevices`, deduplicates tokens, and sends Firebase Cloud
Messaging batches of no more than 500 devices. Flutter never sends server-side
messages and the existing Firestore content remains the authoritative in-app
record.

The Functions region is currently `us-east1`. Verify that it matches the
Firestore database region before deployment; the repository does not query the
live project to determine that setting.

## Device registrations

Each installed app instance persists a random installation ID and writes one
owner-only document at `users/{uid}/pushDevices/{installationId}` containing:
`fcmToken`, `platform`, `appEnvironment`, `enabled`, `createdAt`, `updatedAt`,
and `lastSeenAt`. Tokens are refreshed in place and removed best-effort on
sign-out or after a permanent FCM token error. Tokens are not stored on user
documents, dispatch records, logs, or screens.

Registration and permission prompting begin only after an authenticated,
active parent or student member session with a linked profile is established.
Permission denial does not prevent use of the app. Firestore Rules permit only
the active owner to manage the registration and deny all client access to
`pushDispatches`.

## Publication and audiences

- Announcement: sends once when `status` first changes to `published` and the
  record has a location, title, and summary. Existing everyone, belt, class
  group, selected-profile, and direct-user targeting is preserved.
- Event: sends once when `isPublished` first becomes true while not archived,
  to active parent/student accounts at the same location.
- General resource: uses the same location broadcast only when
  `resourceSection` is `general`.

Draft saves, edits to already-published content, archival, deletion, and
timestamp-only edits do not send. Archive/republish does not resend because the
completed deterministic dispatch is retained. A new content document is
required for a new push. Failed or expired leases may retry without concurrent
duplicate processing. Dispatch records contain only identifiers, status,
counts, timestamps, attempt count, lease, and a short error code.

On tap, the client waits for an authorized member session and matching location,
then resolves the destination from current app data by ID. Missing, archived,
unpublished, deleted, or inaccessible content displays a safe unavailable
state. Foreground Android messages use the high-importance `OTA Updates`
channel; iOS uses FCM/APNs foreground presentation after Apple setup.

## Cost controls

Family listeners are bounded to the newest 30 published announcements, about
50 published non-archived events beginning with the first day of the previous
month, and 50 published non-archived general resources. Notification-read
listeners cover only currently visible announcement IDs. Functions use at most
two instances, no minimum warm instances, and multicast batching. The Firebase
Blaze billing plan is required to deploy Functions. These repository changes do
not enable billing, and this task does not deploy anything.

## Android manual test

After an authorized development deployment:

1. Install the dev debug APK on an Android 13+ physical device.
2. Sign in as an active parent/student member and allow notifications when
   prompted.
3. Confirm `users/{uid}/pushDevices/{installationId}` appears without copying or
   displaying its token.
4. Publish one new announcement, event, and general resource from an admin
   account; do not reuse previously published documents.
5. Verify background and terminated notifications, foreground OTA channel
   notifications, tap routing, location isolation, and the unavailable state
   after content is archived or removed.
6. Sign out and confirm the installation registration is removed.

## Remaining iOS setup

Apple/APNs connection remains pending:

1. Use the academy Apple Developer organization account.
2. Enable Push Notifications on the App ID.
3. Create an APNs authentication key.
4. Upload the `.p8` key, Key ID, and Team ID to Firebase Console.
5. Regenerate the provisioning profile after enabling the capability.
6. Connect App Store Connect API credentials to Codemagic.
7. Build and upload a TestFlight build through Codemagic.
8. Test notifications on a physical iPhone.
9. Never commit APNs or App Store Connect secrets.

The repository includes the remote-notification background mode and a
configuration-driven `aps-environment` entitlement, but no Team ID, APNs key,
certificate, signing profile, or App Store Connect credential.

## Deployment and rollback commands

Review Rules, indexes, the Functions region, project selection, and billing
authorization first. Android can be tested after an authorized development
deployment. Do not use these commands against production:

```powershell
firebase use dev
firebase deploy --only firestore:rules,firestore:indexes --project ota-management-platform
firebase deploy --only functions --project ota-management-platform
```

Inspect aggregate status without exposing tokens in Firebase Console at
`pushDispatches/{contentType}_{contentId}`. To stop sends, delete only these
development functions:

```powershell
firebase functions:delete pushPublishedAnnouncement pushPublishedEvent pushPublishedResource --region us-east1 --project ota-management-platform
```

For a code/config rollback, revert the repository commit, review the resulting
Rules and indexes, then redeploy the reviewed reverted files with the same
development-only commands. Removing a deployed composite index may require a
separate reviewed Firebase Console action; do not delete indexes as an incident
response unless the query rollback is already active.
