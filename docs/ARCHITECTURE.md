# Architecture

## Application Layers

- **UI and screens:** Flutter screens under `lib/screens/` and shared widgets
  under `lib/widgets/` implement the student/parent-facing and administrator
  experiences.
- **Models:** `lib/models/` defines accounts, student profiles, recurring class
  sessions, announcements, events, General Resources, curriculum, and
  locations.
- **Data services:** `AppDataService` is the interface consumed by screens.
  `app_data_service_provider.dart` selects its implementation.
- **Firebase services:** `FirebaseAppDataService` owns Firestore snapshot
  listeners and parsing. `FirebaseAdminWriteService` owns implemented admin
  writes and canonical payload construction.
- **Mock fallback:** `MockAppDataService` and `lib/data/` provide local data for
  unavailable Firebase and for features that have not moved to Firebase.
- **Development utilities:** Separate `*_main.dart` entrypoints provide audit,
  export, cleanup, migration, seed, and one-time schema-update workflows. They
  are not normal application routes.

## Data Flow

Firestore-backed reads follow this path:

```text
Firestore snapshots
  -> FirebaseAppDataService parsing and location/audience filtering
  -> AppDataService getters and ChangeNotifier updates
  -> screens and widgets
```

The active snapshot listeners cover `classSessions`, `announcements`, `events`,
`resources`, and `studentProfiles`. Listener errors are exposed to the relevant
screens; an unavailable Firebase instance at service construction falls back to
`MockAppDataService`.

Implemented admin writes follow this path:

```text
admin form
  -> write data object
  -> FirebaseAdminWriteService
  -> Firestore merge/update
  -> snapshot listener refresh
```

This applies to individual class sessions, announcements, events, and General
Resources. Admin student profile editing and schedule bulk writes are not
implemented.

## Provider Selection

`lib/services/app_data_service_provider.dart` contains the compile-time
`useFirebase` switch. It is currently `true`, so the normal application creates
`FirebaseAppDataService`. Setting it to `false` selects `MockAppDataService`.

Even with Firebase selected, `FirebaseAppDataService` delegates the current
user account, linked student profiles, selected profile, belt labels, and
curriculum to its mock fallback. This boundary is intentional until
authentication, ownership, and curriculum persistence are implemented.

## Time Handling

- OTA Cheshire uses the `America/New_York` IANA time zone.
- Class recurrence is canonical as `weekday`, `startMinutes`, and
  `endMinutes`.
- Events, announcements, date of birth, and audit/operation timestamps use
  Firestore timestamps.
- `LocationTimeService` converts schedule/event instants and computes student
  age against the academy-local date where location context is available.

## Event and Resource Design

Events contain relationships to General Resources; General Resources contain
the actual `linkUrl`. New and edited events designate zero or one
`primaryRegistrationResourceId`, synchronized with the sole value in
`linkedResourceIds`. Resources are optional for drafts and published events. If
selected, the resource must be a published, non-archived General Resource from
the event's location. Legacy documents with multiple linked IDs remain
read-compatible; no schema migration was performed for this rule.

The student Events screen is a seven-column month calendar. Events are assigned
to every academy-local date spanned by their start and end instants, including
past published events. It can be pushed from Dashboard or Resources and has no
bottom navigation, so Back returns through the natural route stack. Student
event details retain the existing bottom sheet and primary-resource flow.
The open bottom sheet listens to the shared data service so event and resource
changes from Firestore snapshots are reflected without reopening it. If the
event is removed or no longer student-visible, the sheet stays open with an
unavailable state rather than retaining a stale snapshot. Resource removal or
invalidation removes only the resource actions while the event remains visible.

Admin Events is reached from the combined **Events & Resources** landing and
remains a list-management interface. There is no standalone admin Events tab.
Admins can explicitly remove the optional linked resource; subsequent writes
contain zero or one synchronized resource ID. Nested Events, General Resources,
and Curriculum pages pop back to the existing combined landing, with a route
replacement used only when a nested page was opened directly.

## Student Identity Model

`UserAccount` and `StudentProfile` are separate concepts:

- User accounts hold role, approval, location, linked profile IDs, and the
  selected profile ID.
- Student profiles hold student identity, date of birth, belt/sticker progress,
  guardian user IDs, an optional self user ID, and class preferences.
- UI personalization is driven by the selected student profile.

The models and Firestore integrity checks exist. Production authentication,
account loading, guardian resolution, profile ownership, profile switching,
approval enforcement, and role-gated navigation remain pending.

## Mock and Fallback Data

The following areas still use local/fallback data:

- Current user account.
- Linked and selected student profiles used by student-facing screens.
- Read-only curriculum content and belt order. Curriculum uses five canonical
  local sections per belt and is never stored as a General Resource. Form
  entries contain a title and independent optional YouTube URL or video ID, so
  a belt may render zero or multiple form cells without sharing a channel URL.
  Embedded players are keyed by parsed video ID to prevent a previous belt's
  player from being retained when curriculum content changes.
- Full data fallback when Firebase is unavailable during service construction.

The admin student directory is Firestore-backed, but it is read-only and shows
guardian IDs rather than resolved user names.

## Development-Only Tools

Database utilities are isolated from `lib/main.dart` and normal navigation.
They have different read/write and safety properties. See
[Firestore operations](FIRESTORE_OPERATIONS.md) before using any of them.
