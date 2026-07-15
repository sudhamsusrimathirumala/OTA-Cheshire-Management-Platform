# Development Membership Testing

This guide is for manual testing against the development Firebase project. It
does not authorize application code to grant administrator access, and it does
not apply to production accounts or data.

## Add the development academy address

The location selector reads optional address fields from the location document
and formats them when present. In the Firebase console, manually add these
fields to the existing `locations/ota-cheshire` development document:

| Field | Type | Value |
| --- | --- | --- |
| `addressLine1` | string | `136 Elm St` |
| `city` | string | `Cheshire` |
| `state` | string | `CT` |
| `postalCode` | string | `06410` |
| `country` | string | `US` |

`addressLine2` is optional and should be omitted when it has no value. The app
shows only the academy name when no address fields exist.

## Account status and profile membership status

`users/{uid}.approvalStatus` describes the account. It is especially important
for whether an administrator account is available. It is not the academy
membership status for a student or parent.

Each `studentProfiles/{profileId}.approvalStatus` is authoritative for that
profile's academy membership. Applying, approving, rejecting, or leaving
changes only the selected or reviewed student profile. Sibling profiles remain
independent. For the account holder's own student profile,
`users/{uid}.locationId` may mirror the profile location for routing, but the
profile approval status is never copied into the user document.

## Configure a development location administrator

1. Create or sign in to a normal account in the development app.
2. Copy its Firebase Authentication UID from the development Firebase console.
3. In the development Firestore console, manually configure `users/{authUid}`.
   The document ID must exactly equal the Firebase Authentication UID.
4. Set the following fields, using timestamps for `createdAt` and `updatedAt`:

   ```text
   firstName: <test administrator first name>
   lastName: <test administrator last name>
   email: <the Firebase Authentication email>
   role: admin
   approvalStatus: approved
   locationId: ota-cheshire
   linkedStudentProfileIds: []
   createdAt: <timestamp>
   updatedAt: <timestamp>
   ```

5. Sign out of the app and sign back in so the session gate reloads the account.
6. Open **Students** and review the pending application.

A genuine location administrator receives Firestore profiles only for the
assigned location. A Super Admin can review pending profiles across active
locations. Applications at inactive locations cannot be approved.

## Sample Admin View

The development-debug shortcut opens **Sample Admin View**, which uses mock
students only. Real Firestore applications are intentionally not loaded and
review buttons are disabled. Use a manually configured development
administrator account for end-to-end Firestore review testing.
