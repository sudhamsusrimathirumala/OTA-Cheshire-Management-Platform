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
the actual `linkUrl`. An event may designate one
`primaryRegistrationResourceId`, which is synchronized into
`linkedResourceIds`. Published event forms only accept a published,
non-archived General Resource from the event's location.

Student event details open and display the primary resource. There is no direct
event registration URL fallback, and events do not control whether resources
appear on the Resources screen.

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
  local sections per belt and is never stored as a General Resource.
- Full data fallback when Firebase is unavailable during service construction.

The admin student directory is Firestore-backed, but it is read-only and shows
guardian IDs rather than resolved user names.

## Development-Only Tools

Database utilities are isolated from `lib/main.dart` and normal navigation.
They have different read/write and safety properties. See
[Firestore operations](FIRESTORE_OPERATIONS.md) before using any of them.
