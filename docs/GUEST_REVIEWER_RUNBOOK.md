# Guest reviewer operations

The OTA reviewer account is an explicitly provisioned Firebase Authentication
identity. It is never created through public signup. The academy owner's normal
email identity remains the real Admin account and must never be converted or
reused as the reviewer. Create the reviewer with a separate email alias that
delivers to the owner's existing inbox. No particular address is assumed by the
application or provisioning tool. Its password must be kept in the academy
password manager and entered in Google Play's App Access instructions only.

## Provisioning prerequisites

1. Merge the approved code and rerun Flutter, Functions, and Firestore emulator
   validation. Do not provision against Rules that predate guest isolation.
2. Use an operator workstation authenticated with a service identity authorized
   for Firebase Authentication administration and the single guest user record.
3. Choose a separate academy-controlled email alias that delivers to the
   existing owner inbox. Do not use the owner's Admin email and do not mark the
   alias verified unless its owner completes a legitimate verification flow.
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
For a new identity, the tool creates the Auth identity disabled, applies the
`otaGuest` claim, creates the matching canonical `users/{uid}` guest record,
and enables the identity last. It refuses to overwrite a non-guest account,
never logs the email or password, and never sets `emailVerified` to true.

For an existing guest identity, an apply run stops unless the operator adds
`--rotate-password`. This flag explicitly replaces the existing password with
the value currently supplied through `OTA_GUEST_PASSWORD` before the account is
re-enabled, so a rerun cannot silently enable an account whose password is
unknown. Use it for intentional reruns and password rotation only:

```text
node scripts/provision_guest_account.cjs --project=PROJECT_ID --confirm-project=PROJECT_ID --apply --rotate-password
```

If a previous attempt created a disabled Auth identity but failed before adding
the claim or Firestore record, inspect that identity in Firebase Authentication.
Only when its email alias, disabled state, and creation time prove it is the
intended reviewer identity may the operator rerun with both
`--adopt-disabled-auth` and `--rotate-password`. The tool refuses to adopt an
identity that is enabled or does not already use email/password authentication.

If provisioning fails, the identity remains disabled. Correct the reported
configuration issue and rerun the same command. Do not manually assign an
Admin or Super Admin role.

## Rotation and disablement

- Rotate the password in Firebase Authentication and update the protected Play
  Console instructions together.
- To suspend reviewer access, disable the Auth identity. The Firestore guest
  document may remain for later reuse.
- Never reuse the reviewer mailbox or UID for a real academy member.

## Development-project verification

Use `ota-management-platform` only. Confirm the project ID before every command;
do not substitute the production project ID.

1. Deploy only the reviewed Rules to development:

   ```text
   firebase deploy --only firestore:rules --project ota-management-platform
   ```

2. Set the separate alias and password only in the current process environment.
   Run the dry run, then use `--apply` only after the output and project ID are
   confirmed. Add `--rotate-password` only if the reviewer identity already
   exists.
3. Launch the development flavor with
   `flutter run --flavor dev -t lib/main_dev.dart` and confirm view switching,
   shared local edits, sign-out reset, and absence of notification registration.
4. Remove the credential environment variables immediately after the test and
   disable the development reviewer identity when testing is complete.

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
