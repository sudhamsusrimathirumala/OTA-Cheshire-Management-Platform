# OTA Cheshire Management Platform

## Overview

The OTA Cheshire Management Platform is a Flutter and Firebase management and
communication application for Olympic Taekwondo Academy. It is intended to
serve students, parents, instructors, and administrators from one shared data
model. Multi-location support is an architectural goal; the current code and
sample data are centered on the `ota-cheshire` location.

The application is under active development and is not production-ready.

## Permanent Cost and Service Constraint

This project must remain on Firebase's no-cost Spark plan with no billing
account or payment method. It uses no deployed Cloud Functions or paid Google
Cloud services and includes no advertisements, subscriptions, in-app
purchases, paid memberships, donations, fees, or other monetization. If a
Spark quota is exceeded, service is limited until the quota resets; there is no
paid overage because billing is not linked. This is a permanent architectural
constraint.

## Current Capabilities

### Student and Parent Experience

- Dashboard with the selected student's next eligible class, belt progress,
  and academy updates.
- Day and week schedule views with recurrence, overlap, eligibility, and class
  detail presentation.
- Firestore-backed announcements, notification filters, and notification
  details.
- Firestore-backed published events in a seven-column month calendar, using
  academy-local dates and retaining published past events for browsing. Events
  open from Dashboard or Resources, and the Events page intentionally has no
  bottom navigation bar.
- Firestore-backed published General Resources with validated copy/open-link
  actions and detail pages.
- Local, read-only curriculum organized by belt, including No Belt and five
  canonical sections. Each form item independently supports an optional
  embedded YouTube video; unavailable videos show a coming-soon fallback.
- Firebase email/password and Google authentication, password reset, profile
  creation without mandatory email verification, independent membership applications, and
  persisted profile switching.
- Student profile, linked account, membership status, and leave-location
  management backed by the authenticated Firebase UID.

### Administrator Experience

- Admin dashboard and navigation, with event management reached through the
  combined **Events & Resources** destination rather than a standalone Events
  tab.
- Firestore-backed schedule listing plus create, edit, and single-session
  delete operations. Bulk actions are preview-only.
- Firestore-backed announcement create, edit, publish, archive, and delete
  operations with audience targeting.
- Firestore-backed event create, edit, publish, archive, and delete operations
  in the existing list-management interface.
- Firestore-backed General Resource create, edit, publish, archive, and delete
  operations.
- Firestore-backed student directory, batch membership applications, atomic
  approval/rejection, legacy pending-profile review, and details. Generic
  student profile editing is not implemented.
- Read-only curriculum view backed by local sample curriculum.

Normal startup routes approved Admin and Super Admin accounts through the
Firebase session gate; no public role-escalation route exists.

### Data Layer

`AppDataService` defines the data consumed by screens. The provider switch in
`lib/services/app_data_service_provider.dart` currently selects
`FirebaseAppDataService`. It maintains Firestore snapshot listeners for
`classSessions`, `announcements`, `events`, `resources`, `studentProfiles`, and
`membershipApplications`. `MockAppDataService` is limited to isolated tests and
the clearly labeled development-debug sample views. An authenticated Firebase
session never falls back to sample data when a listener fails; the affected UI
keeps its loading, empty, and error states distinct.

`FirebaseAdminWriteService` performs the implemented admin writes. Existing
documents are written with merge semantics, and cleared canonical optional
fields are explicitly deleted so stale values do not remain.

### Firestore Collections

The application uses these top-level collections:

- `locations`
- `users`
- `studentProfiles`
- `membershipApplications`
- `classSessions`
- `announcements`
- `events`
- `resources`

See [Firestore schema](docs/firestore_schema.md) for field and relationship
details.

## Current Architecture

The repository separates Flutter screens and widgets, application models, the
`AppDataService` abstraction, Firebase read/write services, mock data, and
development-only Firestore utilities. See [Architecture](docs/ARCHITECTURE.md)
for the current data flow and fallback boundaries.

## Development Status

### Implemented

- Student dashboard, schedule, announcements, events, resources, curriculum,
  and profile screens.
- Admin schedule, announcement, event, resource, student directory, and
  profile screens.
- Live Firestore reads for schedules, announcements, events, resources, and
  the admin student directory.
- Admin writes for individual class sessions, announcements, events, and
  General Resources.
- Resource-based event registration and academy-location time handling.
- Events may have no General Resource or one valid General Resource. When one is
  selected, the compatible `linkedResourceIds` and
  `primaryRegistrationResourceId` fields are retained and synchronized; legacy
  documents with multiple linked IDs remain readable. Admins can remove the
  optional link while editing.
- Open student event details reflect live event and resource changes. Events
  that become unavailable show an in-sheet unavailable state instead of stale
  details.
- Read-only Firestore audit/export utilities and guarded write utilities.

### Partially Implemented

- Firebase authentication, verified profile creation, profile-specific academy
  applications, admin review, membership-aware routing, and security rules are
  implemented. Provider linking and production release validation remain out
  of scope.
- Firestore data is location-aware, but administration is currently centered
  on OTA Cheshire rather than a complete multi-location workflow.
- Announcements are live Firestore data, but device push notifications are not
  implemented.
- Curriculum is functional, section-based UI backed by bundled data rather
  than Firestore. The local data supports zero or multiple forms per belt and
  an independent optional video URL per form; approved curriculum text and
  video URLs remain content work.
- Admin schedule bulk actions show an impact preview but do not write.

### Planned or Remaining

- Production deployment and broader authorization testing for Firestore rules.
- Guardian display-name resolution and generic student profile editing.
- Admin student profile editing and production curriculum data.
- End-to-end release validation, production signing, and content review.

See [Project backlog](docs/Project_Backlog.md) for prioritized remaining work.

## Project Structure

```text
lib/
  data/       Local sample and fallback data
  models/     Application data models
  screens/    Student, parent-facing, and administrator screens
  services/   Data abstraction, Firebase services, and Firestore utilities
  theme/      OTA color system
  utils/      Presentation helpers
  widgets/    Shared UI components
  main_dev.dart / main_prod.dart   Environment-specific entrypoints
  *_main.dart Development-only Firestore entrypoints
docs/         Schema, architecture, operations, and backlog documentation
test/         Unit, service-helper, and widget tests
.github/workflows/  Manual debug APK release workflow
android/      Android application and Gradle configuration
assets/       OTA image assets
```

## Running the App

```powershell
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

Android development is supported through Android Studio and an Android
emulator. Web development does not require Visual Studio. Windows desktop
builds require the Visual Studio C++ desktop workload.

See [Development guide](docs/DEVELOPMENT.md) for run targets and build commands.

## Firebase Setup

Firebase initialization is explicit by environment. Development uses
`lib/main_dev.dart` and `lib/firebase_options_dev.dart` for the
`ota-management-platform` project. Production uses `lib/main_prod.dart` and a
deliberately unconfigured `lib/firebase_options_prod.dart`; it cannot fall back
to development. Native flavors and schemes pin their matching target, while
`lib/main.dart` fails rather than selecting a default. See
[Firebase environments](docs/FIREBASE_ENVIRONMENTS.md).

`firestore.rules` protects atomic pending applications and admin review writes.
Firebase deployments are limited to explicit Firestore Rules releases; no
database data or server code is deployed.

## Testing and Validation

```powershell
dart format lib test tool
flutter analyze
flutter test
git diff --check
```

## Development Utilities

The repository includes development-only entrypoints for Firestore audit,
export, cleanup, migration, seeding, and the completed approved schema update.
Some are write-capable and are not part of normal application startup or
navigation. See [Firestore operations](docs/FIRESTORE_OPERATIONS.md) before
running any utility.

## Build and Release

The GitHub Actions workflow is manually triggered with `workflow_dispatch`. It
installs Flutter, runs `flutter pub get`, builds a debug APK, renames it to
`OTA-Cheshire-debug.apk`, and creates a GitHub Release tagged
`apk-<run_number>` with that APK attached. It does not build a signed production
release APK.

The Android release build currently uses the debug signing configuration, so
production signing remains outstanding.

## Author

Sudhamsu Srimathirumala

Independent software development project focused on applying software
engineering, UI/UX design, database design, and system architecture concepts to
solve organizational and communication challenges within a community
organization.
