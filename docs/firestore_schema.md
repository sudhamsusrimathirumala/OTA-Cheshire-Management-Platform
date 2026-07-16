# Canonical Firestore Schema

This document describes the schema used by the current models, Firestore
parsers, admin write helpers, audit/export utilities, and sample-data writers.
Legacy fields are noted only where the reader still supports them.

## `locations/{locationId}`

Locations provide the scope and IANA time zone used by other records.

Required fields:

- `name`: String
- `addressLine1`: String
- `city`: String
- `state`: String
- `postalCode`: String
- `country`: String
- `timeZoneId`: String
- `isActive`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional field: `addressLine2`. The model's formatted address omits a blank
second line safely. The migration never invents a real street address; it
reports locations missing required address fields for manual completion.

The configured location is `ota-cheshire`, named `OTA Cheshire`, with
`America/New_York` as its time zone. Other collections reference a location by
`locationId`.

## `users/{firebaseUid}`

The document ID is always the Firebase Authentication UID. Email is mutable
contact information and is never the identity key. Linking password and Google
providers to one Firebase user must continue using the same document.
The UID user and all permanent student profiles are created together by an
authenticated client `WriteBatch`. Firestore Rules require canonical
relationships and verify every linked profile in the atomic post-write state.

Required fields:

- `firstName`: String
- `lastName`: String
- `email`: normalized lowercase String
- `role`: `student`, `parent`, `admin`, or `superAdmin`
- `isActive`: bool controlling account availability
- `locationId`: String referencing `locations` (except a cross-location Super Admin)
- `linkedStudentProfileIds`: List<String> referencing `studentProfiles`
- `selectedStudentProfileId`: linked profile ID for student/parent accounts
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional fields are `phoneNumber` and `googleAccountId`. Blank phone numbers are omitted
or deleted. `googleAccountId` comes only from the `google.com` entry in Firebase
`User.providerData`; it is never derived from email.

During public initial creation, `role` is only `student` or `parent`,
`isActive` is true, `selectedStudentProfileId` is required and linked, and
`locationId` references an active academy. Admin roles are configured manually.

## `studentProfiles/{studentProfileId}`

Required fields:

- `firstName`: String
- `lastName`: String
- `beltRank`: String
- `dateOfBirth`: Timestamp
- `guardianUserIds`: List<String> referencing `users`
- `locationId`: String matching the owning account location
- `isActive`: bool controlling profile availability
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional fields are `linkedUserId`, `guardianEmail`, and
`preferredClassGroupIds`. `guardianEmail` is required for a parent-managed
child and optional for a self-managed student. It is a contact address;
it does not create a user or replace `guardianUserIds`. Existing profiles may
temporarily omit it. Migration derives it only from one unambiguous existing
parent relationship and otherwise reports it missing.

Initial profiles are permanent, active, and use the account's `locationId`.
Independent students and parents who are also students receive `linkedUserId`;
child profiles receive the parent UID in `guardianUserIds`. Account and profile
creation is atomic, and all profiles under one parent account share one academy
location.

`preferredClassGroupIds` retains list compatibility but contains zero or one
`ClassSession.bulkGroupId` for the current release. Parents and self-managed
students may update only profiles they manage. Parents may atomically add a
child at their account location or unlink and deactivate a child while academy
history remains stored.

## `users/{uid}/notificationReads/{announcementId}`

Persistent notification read state is scoped to the authenticated account.
The document ID is the announcement ID and the only field is `readAt`, a server
timestamp. No administrator may read another user's notification state.

Age is computed from `dateOfBirth`, using the academy-location date where the
UI has location context. The parser temporarily reads legacy `age` only when
`dateOfBirth` is missing. New writes never store `age`.

## `classSessions/{sessionId}`

Required fields:

- `className`: String
- `classTypeId`: String
- `bulkGroupId`: String
- `locationId`: String referencing `locations`
- `weekday`: integer from 1 through 7
- `startMinutes`: integer from 0 through 1439
- `endMinutes`: integer from 0 through 1439 and greater than `startMinutes`
- `eligibleBelts`: List<String>
- `description`: String
- `isActive`: bool
- `isPreferred`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional fields:

- `eligibilityNote`: String
- `resumesOn`: Timestamp

Recurring schedules use `weekday`, `startMinutes`, and `endMinutes`.
`startTime` and `endTime` are legacy compatibility fields that readers may use
temporarily; current admin writes do not write them.

Canonical class type IDs are:

- `little-tiger`
- `level-1`
- `level-2`
- `level-3`
- `level-4`
- `teen-adult`
- `level-1-2-sparring`
- `teen-adult-sparring`

The default bulk group is `<classTypeId>-standard`.

## `announcements/{announcementId}`

Required fields:

- `title`: String
- `summary`: String
- `body`: String
- `announcementType`: String
- `priority`: `general` or `important`
- `requiresAction`: bool
- `status`: `draft`, `published`, or `archived`
- `audienceType`: `everyone`, `belt`, `classType`, `students`, `parents`,
  `specificUsers`, or `mixed`
- `locationId`: String referencing `locations`
- `targetBelts`: List<String>
- `targetClassTypeIds`: List<String>
- `targetStudentProfileIds`: List<String> referencing `studentProfiles`
- `targetUserIds`: List<String> referencing `users`
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional field:

- `publishedAt`: Timestamp

The admin form writes `general` or `important`. The write helper normalizes the
legacy `critical` value to `important`. Readers also display legacy `critical`
as Important and treat `normal` or other non-important values as General.

A first publication assigns `publishedAt`. Edits to previously published or
archived announcements preserve it. A never-published draft has no
`publishedAt`.

## `events/{eventId}`

Required fields:

- `title`: String
- `description`: String
- `eventType`: String
- `locationId`: String referencing `locations`
- `startDateTime`: Timestamp
- `endDateTime`: Timestamp
- `linkedResourceIds`: List<String> referencing General Resources
- `isPublished`: bool
- `isArchived`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional fields:

- `primaryRegistrationResourceId`: String referencing a General Resource
- `registrationDeadline`: Timestamp

Registration is resource-based but optional. For new and edited events,
`linkedResourceIds` contains zero or one ID. When present,
`primaryRegistrationResourceId` contains that same ID, and the resource must
belong to the same location and be a published, non-archived General Resource
before a published event is saved. Existing documents with multiple linked IDs
remain readable; no migration or live-data cleanup was performed for this rule.
The actual URL is stored in the resource's `linkUrl`.
`registrationUrl` is not canonical, and `showInResources` has been removed. The
reader intentionally ignores either legacy event field.

The admin form may clear the optional relationship. A cleared existing event
writes an empty `linkedResourceIds` list and deletes
`primaryRegistrationResourceId`; blank and placeholder IDs are not written.

## `resources/{resourceId}`

This collection stores General Resources.

Required fields:

- `title`: String
- `description`: String
- `resourceSection`: the literal `general`
- `category`: `testing`, `registration`, `academy-information`, or `general`
- `locationId`: String referencing `locations`
- `isPublished`: bool
- `isArchived`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional field:

- `linkUrl`: String

Legacy `forms` and `events` categories remain readable as `general` and are
normalized to `general` by the migration. `resourceType` is not canonical: new
writes omit it, readers ignore it, and the migration deletes it with
`FieldValue.delete()`. Readers temporarily fall back from `linkUrl` to the
legacy `url` field, but new writes never write `url`.

Curriculum is currently local `CurriculumRequirement` data. It is not stored as
`AcademyResource` documents. Bundled form entries map their title and optional
individual YouTube URL or video ID into `CurriculumItem`; no shared channel URL
is assigned automatically.

## Optional Field Clearing

Admin saves use `SetOptions(merge: true)`. On existing-document edits, clearing
these optional values writes `FieldValue.delete()` so stale values are not
retained:

- `resources.linkUrl`
- `classSessions.eligibilityNote`
- `classSessions.resumesOn`
- `events.registrationDeadline`
- `events.primaryRegistrationResourceId`
- `announcements.publishedAt` for a never-published draft

Creation writes omit empty optional fields. Existing `createdAt` values and
publication history are preserved on edits.

## Relationships and Integrity

- `users.linkedStudentProfileIds` is the authorization boundary for basic
  student-profile edits and preferred-class changes. The account and profile
  must also be active and share one `locationId`.
- Student `guardianUserIds` and `linkedUserId` retain household relationship
  meaning but do not independently grant or deny basic linked-profile edit
  access. This role-neutral rule avoids reintroducing approval-style barriers
  through legacy relationship metadata or selected-profile state.
- An account and every profile it may edit use one matching `locationId`.
- Event resource IDs must resolve to same-location General Resources. The
  primary registration resource must be included in `linkedResourceIds`.
- Every `locationId` must resolve to `locations`.
- Announcement target student/user IDs must resolve to their target
  collections.
- The cleanup planner supports targeted field updates and field deletion only;
  it does not support document deletion. Normal admin screens do expose
  explicit, separately confirmed document deletion for supported content.

The repository's historical `docs/firestore_audit_report.json` is a dated
snapshot, not a description of current live data.

The removed approval-based membership design is documented only as inactive
project history in [Architecture](ARCHITECTURE.md#historical-design-decision-membership-approval-inactive).
