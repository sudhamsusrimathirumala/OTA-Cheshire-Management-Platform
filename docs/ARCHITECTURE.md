# Architecture

## Permanent Spark-Only Constraint

The app must remain on Firebase's no-cost Spark plan without a billing account
or payment method. It uses Firebase Authentication and Firestore client SDKs,
but no deployed Cloud Functions or paid Google Cloud services. The product has
no advertising, subscriptions, purchases, paid memberships, donations, fees,
or revenue features. Spark quota exhaustion causes temporary service limitation,
not paid overage.

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
  `FirebaseAuthenticationService`, `FirebaseSessionController`, and
  `FirestoreProfileService` own authentication, reactive routing, and atomic
  account/profile creation at one academy location.
- **Mock data:** `MockAppDataService` and `lib/data/` provide local data only for
  isolated tests and clearly labeled development-debug sample views. They are
  not a fallback for an authenticated Firebase session.
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

The active content listeners cover `classSessions`, `announcements`, `events`,
and `resources` for the active selected profile's active location. Session
listeners observe Auth, the UID user document, linked profiles, selection, and
the selected location. Listener failures remain visible as real error states. Isolated tests
without an initialized Firebase app use `MockAppDataService`.

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
`FirebaseAppDataService`. The mock implementation is reserved for controlled
tests and development-debug sample views; real authenticated flows do not
switch to it after a Firebase error.

With Firebase initialized, `FirebaseAppDataService` uses the authenticated UID,
linked profiles, and persisted selection from `FirebaseSessionController`.
Only bundled curriculum and isolated-test fallback data remain local.

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

- User accounts hold role, `isActive`, one location, linked profile IDs, and the
  selected profile ID.
- Student profiles hold student identity, date of birth, belt/sticker progress,
  guardian user IDs, an optional self user ID, class preferences, the same
  account location, and `isActive`.
- UI personalization is driven by the selected student profile.

Firebase Auth is canonical. A single atomic batch creates the UID account and
all permanent profiles with one active `locationId`. If exactly one active
location exists it is selected automatically; a future multi-location setup
uses one account-level selector. Selection is persisted on the UID user
document, and academy data loads only when the account, selected profile, and
matching location are active. Guardian display-name resolution remains future
work.

## Mock and Fallback Data

The following areas still use local/fallback data:

- Read-only curriculum content and belt order. Curriculum uses five canonical
  local sections per belt and is never stored as a General Resource. Form
  entries contain a title and independent optional YouTube URL or video ID, so
  a belt may render zero or multiple form cells without sharing a channel URL.
  Embedded players are keyed by parsed video ID to prevent a previous belt's
  player from being retained when curriculum content changes.
- Full data fallback only for isolated tests without an initialized Firebase
  app.

The admin student directory is Firestore-backed and read-only. It resolves the
same-location account holder when a linked user or guardian relationship is
available.

## Historical Design Decision: Membership Approval (Inactive)

The original architecture intentionally separated permanent profiles from
academy membership. Profiles applied to a location and an academy
administrator reviewed them before content access. This was designed for
controlled enrollment and possible independently managed locations.

After evaluating the actual academy workflow, the release architecture was
simplified. There is currently one active location; per-family review adds
unnecessary family and staff friction; linked accounts and profiles already
represent households; young siblings are unlikely to attend unrelated OTA
locations; and older independent students can create their own accounts. The
workflow also required substantial UI, routing, Rules, backend, and test
complexity. Immediate access through authenticated active records is a better
fit for the current release while preserving privacy and role protections.

The concept may be reconsidered if real multi-location growth or identity
verification needs emerge. This workflow is retained here as project design
history. It is not part of the current runtime, Firestore schema, security
rules, or user experience.

### Linked-profile authorization simplification

The removal of approval review established a broader design direction: avoid
authorization barriers that duplicate an already explicit access boundary
without adding meaningful protection. Basic student-profile editing and
preferred-class updates now follow that direction.

Previously, a linked profile could still be blocked by parent/student role,
`guardianUserIds`, `linkedUserId`, or selected-profile checks. Those fields
describe household relationships and current UI context, but they are not the
basic edit-access boundary. Legacy or incomplete relationship metadata could
therefore deny a legitimate same-account edit.

Now, access is role-neutral. Firebase Authentication must identify an existing
active account; the active profile ID must appear in
`linkedStudentProfileIds`; and the account and profile must have the same
`locationId`. Profiles not linked to the account remain inaccessible. Normal
edits still restrict the exact fields that may change, and preferred-class
writes remain limited to the preference list and server timestamp. Class
existence, active state, location, and recurring group are still validated.

This removes redundant barriers in the same way the approval process was
removed: it simplifies the application and Rules while retaining the concrete
account-to-profile link, activation, location isolation, and protected-field
boundaries.

## Development-Only Tools

Database utilities are isolated from `lib/main.dart` and normal navigation.
They have different read/write and safety properties. See
[Firestore operations](FIRESTORE_OPERATIONS.md) before using any of them.
