# Development Academy Access Testing

This guide applies only to the `ota-management-platform` development Firebase
project. It does not authorize public administrator registration and does not
apply to production accounts or data.

## Development academy location

The location document should contain its real name, IANA time zone,
`isActive: true`, timestamps, and the available address fields. The app safely
omits a blank `addressLine2`. During account setup, one active location is
selected automatically; multiple active locations display one account-level
selector; zero active locations block creation.

## Configure a development location administrator

1. Create or sign in to a normal account in the development app.
2. Copy its Firebase Authentication UID from the development Firebase Console.
3. Manually configure `users/{authUid}`. The document ID must exactly equal the
   Authentication UID.
4. Set `firstName`, `lastName`, the matching `email`, `role: admin`,
   `isActive: true`, `locationId: ota-cheshire`, an empty
   `linkedStudentProfileIds` list, and timestamp `createdAt`/`updatedAt` fields.
5. Sign out and back in so the session gate reloads the account.

A location Admin can read only users, profiles, and content assigned to that
active location. Super Admin remains a manually controlled cross-location
role. Neither role is available in public profile setup.

## One-time development data removal

`tool/remove_approval_data.mjs` is a narrowly scoped, idempotent utility. It is
hard-locked to `ota-management-platform`, defaults to dry-run, requires exactly
one active location, preserves document and Authentication IDs, and lists every
field update and document deletion. It never accesses Firebase Authentication.

After the emulator suite passes, run a dry run. The utility obtains a
short-lived token from the already authenticated Firebase CLI without printing
or storing it in the repository:

```powershell
node tool/remove_approval_data.mjs --project=ota-management-platform
```

Review the complete dry-run output. Apply only with the exact confirmation:

```powershell
node tool/remove_approval_data.mjs --project=ota-management-platform --apply '--confirm=REMOVE DEVELOPMENT APPROVAL DATA'
```

The utility updates only `users` and `studentProfiles` access/location fields,
removes legacy review fields, and deletes the retired application documents.
It does not delete users or profiles, change Authentication users, deploy code,
run seeds, or access a production project.

## Sample Admin View

The development-debug shortcut opens **Sample Admin View** with labeled mock
data. Real Firestore records are not loaded. Use a manually configured
development administrator for end-to-end Firestore verification.
