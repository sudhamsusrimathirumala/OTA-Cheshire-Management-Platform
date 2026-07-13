# Canonical Firestore Schema

This document describes the schema used by the current models, Firestore
parsers, admin write helpers, audit/export utilities, and sample-data writers.
Legacy fields are noted only where the reader still supports them.

## `locations/{locationId}`

Locations provide the scope and IANA time zone used by other records.

Required fields:

- `name`: String
- `timeZoneId`: String
- `isActive`: bool

The configured location is `ota-cheshire`, named `OTA Cheshire`, with
`America/New_York` as its time zone. Other collections reference a location by
`locationId`.

## `users/{userId}`

Required fields:

- `displayName`: String
- `email`: String
- `role`: `parent`, `student`, `instructor`, or `admin`
- `locationId`: String referencing `locations`
- `approvalStatus`: `pending`, `approved`, or `rejected`
- `linkedStudentProfileIds`: List<String> referencing `studentProfiles`
- `selectedStudentProfileId`: String or null; when set, it must appear in
  `linkedStudentProfileIds`
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

The account/profile model exists, but the normal application still obtains the
current account and selected profile from fallback data rather than loading an
authenticated user document.

## `studentProfiles/{studentProfileId}`

Required fields:

- `fullName`: String
- `beltRank`: String
- `dateOfBirth`: Timestamp
- `locationId`: String referencing `locations`
- `guardianUserIds`: List<String> referencing `users`
- `preferredClassGroupIds`: List<String>
- `stickerProgress`: Map containing `current`, `required`, and `nextRank`
- `promotionHistory`: List
- `testingNotes`: List
- `isActive`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional field:

- `selfUserId`: String referencing `users`

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

Registration is resource-based. A primary registration resource must also be
present in `linkedResourceIds`, must belong to the same location, and must be a
published, non-archived General Resource before the event is published. The
actual URL is stored in the resource's `linkUrl`. `registrationUrl` is not
canonical, and `showInResources` has been removed. The reader intentionally
ignores either legacy event field.

## `resources/{resourceId}`

This collection stores General Resources.

Required fields:

- `title`: String
- `description`: String
- `resourceSection`: the literal `general`
- `resourceType`: non-empty String
- `category`: String
- `locationId`: String referencing `locations`
- `isPublished`: bool
- `isArchived`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional field:

- `linkUrl`: String

Canonical categories written by the helper include `testing`, `registration`,
`events`, `forms`, `academy-information`, and `general`. Known legacy category
spellings are normalized. Readers temporarily fall back from `linkUrl` to the
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

- `users.linkedStudentProfileIds` and student `guardianUserIds`/`selfUserId`
  form bidirectional account/profile relationships.
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
