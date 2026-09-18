# Guest reviewer operations

The OTA reviewer account is an explicitly provisioned Firebase Authentication
identity. It is never created through public signup. Its password must be kept
in the academy password manager and entered in Google Play's App Access
instructions only.

## Provisioning prerequisites

1. Merge the approved code and rerun Flutter, Functions, and Firestore emulator
   validation. Do not provision against Rules that predate guest isolation.
2. Use an operator workstation authenticated with a service identity authorized
   for Firebase Authentication administration and the single guest user record.
3. Choose an academy-controlled mailbox. Do not mark it verified unless the
   mailbox owner completes a legitimate verification flow.
4. Generate a unique password of at least 16 characters outside this repository.

## Dry run

From `functions/`, set `OTA_GUEST_EMAIL` and `OTA_GUEST_PASSWORD` only in the
current process environment, then run:

```text
node scripts/provision_guest_account.cjs --project=PROJECT_ID --confirm-project=PROJECT_ID
```

The dry run validates inputs and performs no Firebase connection or mutation.

## Approved provisioning

Only after explicit production approval, deploy the Rules explicitly:

```text
firebase deploy --only firestore:rules --project ota-management-platform-e4847
```

No Functions or indexes changed for this feature. Confirm the Firebase CLI
reports `ota-management-platform-e4847`, then use the same provisioning command
with `--apply`.
The tool creates a new Auth identity disabled, applies the `otaGuest` claim,
creates the matching `users/{uid}` guest record, and enables the identity last.
It is idempotent and refuses to overwrite a non-guest account. It never logs
the email or password and never sets `emailVerified` to true.

If a previous attempt created a disabled Auth identity but failed before adding
the claim or Firestore record, inspect that identity in Firebase Authentication.
Only when its email, disabled state, and creation time prove it is the intended
reviewer identity may the operator rerun with `--adopt-disabled-auth`.

If provisioning fails, the identity remains disabled. Correct the reported
configuration issue and rerun the same command. Do not manually assign an
Admin or Super Admin role.

## Rotation and disablement

- Rotate the password in Firebase Authentication and update the protected Play
  Console instructions together.
- To suspend reviewer access, disable the Auth identity. The Firestore guest
  document may remain for later reuse.
- Never reuse the reviewer mailbox or UID for a real academy member.

## Release and Play Console handoff

1. In a separate release change, increment the Android version code from
   `1.0.0+1`; this implementation deliberately leaves it unchanged.
2. Build and sign the production AAB using the existing external signing setup.
3. Install the Play-delivered build and sign in with the reviewer account.
4. Confirm Admin, Student, and Parent switching, a local simulated edit, reset
   after sign-out, and absence of notification permission/device registration.
5. Put the email and password only in Google Play Console App Access. Explain
   that the yellow reviewer banner identifies fictional, session-local data.
6. Retain the mailbox and password in the academy password manager so password
   recovery and rotation remain controlled.
