# Canonical Firestore schema

This document defines the approved application schema for Phase 1 of the OTA
Firestore cleanup. The Phase 1 audit is read-only. Legacy fields remain readable
where noted, but new application writes use canonical fields.

## `locations/{locationId}`

Required fields:

- `name`: String
- `timeZoneId`: String containing an IANA timezone ID
- `isActive`: bool

The `ota-cheshire` document is `name: "OTA Cheshire"`,
`timeZoneId: "America/New_York"`, and `isActive: true`.

## `users/{userId}`

Required fields:

- `displayName`: String
- `email`: String
- `role`: String
- `locationId`: String referencing `locations`
- `dateOfBirth`: Timestamp
- `approvalStatus`: String (`pending`, `approved`, or `rejected`)
- `linkedStudentProfileIds`: List<String> referencing `studentProfiles`
- `selectedStudentProfileId`: String or null; when set, it must reference a
  profile in `linkedStudentProfileIds`
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

All linked profile IDs must resolve. User/profile relationships must be
bidirectional.

## `studentProfiles/{studentProfileId}`

Required fields:

- `fullName`: String
- `beltRank`: String
- `locationId`: String referencing `locations`
- `guardianUserIds`: List<String> referencing `users`
- `preferredClassGroupIds`: List<String>
- `promotionHistory`: List
- `testingNotes`: List
- `stickerProgress`: Map containing the current count, required count, and next
  rank
- `isActive`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

`selfUserId`, when present, must resolve to `users`. Readers temporarily accept
legacy `age` only when `dateOfBirth` is missing; new writes never write `age`.

## `classSessions/{sessionId}`

Required fields:

- `className`: String
- `classTypeId`: String
- `bulkGroupId`: String
- `locationId`: String referencing `locations`
- `weekday`: int from 1 through 7
- `startMinutes`: int from 0 through 1439
- `endMinutes`: int from 0 through 1439 and greater than `startMinutes`
- `eligibleBelts`: List<String>
- `description`: String
- `isActive`: bool
- `isPreferred`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Optional fields are `eligibilityNote` (String) and `resumesOn` (Timestamp).
Canonical recurring schedule fields are `weekday`, `startMinutes`, and
`endMinutes`. `startTime` and `endTime` are legacy compatibility fields; readers
may use them temporarily, but new writes do not write them.

## `announcements/{announcementId}`

Required fields:

- `title`, `summary`, `body`, and `announcementType`: String
- `priority`: `normal` or `important`; `critical` is legacy
- `requiresAction`: bool
- `status`: `draft`, `published`, or `archived`
- `audienceType`: supported audience identifier
- `locationId`: String referencing `locations`
- `targetBelts`, `targetClassTypeIds`, `targetStudentProfileIds`, and
  `targetUserIds`: List<String>
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

Drafts omit `publishedAt` or keep it null. First publication sets it. Later
edits and archival preserve the original publication timestamp.

## `events/{eventId}`

Required fields:

- `title`, `description`, and `eventType`: String
- `locationId`: String referencing `locations`
- `startDateTime` and `endDateTime`: Timestamp
- `linkedResourceIds`: List<String> referencing General Resources
- `primaryRegistrationResourceId`: String or null; when set, it must also be in
  `linkedResourceIds`
- `isPublished`: bool
- `isArchived`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

The canonical relationship is from an event to General Resource IDs.
`registrationDeadline` is optional. Registration links live only on the primary
General Resource; event readers ignore legacy `registrationUrl` and
`showInResources` fields.

## `resources/{resourceId}`

This collection contains General Resources only.

Required fields:

- `title` and `description`: String
- `resourceSection`: the literal `general`
- `resourceType`: non-empty String
- `category`: canonical String ID
- `locationId`: String referencing `locations`
- `isPublished`: bool
- `isArchived`: bool
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

`linkUrl` is an optional String. `url` is a legacy compatibility field; readers
may fall back to it, but new writes do not write it. Canonical categories are
`testing`, `registration`, `events`, `forms`, `academy-information`, and
`general`. Values such as `beltTesting`, `belt-testing`, `event`, `form`, and
`academyInformation` are normalized before writing. Curriculum data must not be
stored as `AcademyResource` documents.
