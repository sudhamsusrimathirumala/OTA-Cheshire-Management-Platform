# Project Backlog

This backlog reflects gaps visible in the current codebase. Completed database
cleanup and schema-update work is not listed as active work.

## Must Complete Before Deployment

### Identity and Authorization

- [x] Connect the login, signup, Google sign-in, and password-reset UI to
  Firebase Authentication.
- [x] Load the current `users` document and enforce active account/location
  access.
- [x] Route and guard student, parent, and administrator areas by authenticated
  role.
- [x] Implement atomic account/profile onboarding and the no-profile state.
- [x] Load linked/selected student profiles from Firestore and enforce
  account/profile ownership.

### Firestore Security and Data

- [x] Add emulator-tested Firestore security rules for ownership, roles,
  locations, and publication state.
- [ ] Verify authorization for every admin write and explicit document-delete
  path.
- [ ] Resolve guardian user IDs to user display names and validate guardian/self
  relationships against authenticated accounts.
- [ ] Run a fresh read-only audit of production data and resolve remaining
  errors, warnings, placeholder URLs, or placeholder content before launch.
- [ ] Keep historical migration, cleanup, seed, and schema-update tools disabled
  or out of production builds.

### Release Readiness

- [ ] Provision and verify the academy-owned production Firebase project
  without reusing development configuration.
- [ ] Obtain explicit Blaze approval and deploy the reviewed push Functions to
  the authorized project.
- [ ] Configure production Android signing; the current release build uses the
  debug signing configuration.
- [ ] Configure production iOS signing and connect APNs without committing
  signing or authentication secrets.
- [ ] Validate a release-mode Android build on supported devices.
- [ ] Complete end-to-end tests for authentication, role access, Firestore
  permissions, student/parent reads, and admin writes.
- [ ] Review production academy content and links with stakeholders.
- [ ] Deploy the reviewed account-deletion Rules explicitly and validate
  password and Google deletion on real Android and iOS devices.

## Important Product Work

### Student, Parent, and Account Experience

- [x] Add account-holder Dashboard context and linked-profile switching.
- [x] Add profile switching for parent, student, and parent-who-trains cases.
- [x] Add handling for accounts with no linked student profile.
- [x] Use authenticated live current-user and selected-profile state outside
  clearly labeled development-debug sample views.
- [x] Implement direct permanent member account deletion with recent
  reauthentication, explicit private-subcollection removal, all-linked-profile
  deletion, privileged-account restriction, and safe partial-failure recovery.

### Student Management

- [x] Add role-neutral active same-location linked-profile editing.
- [x] Add parent child-profile creation and retained-history removal.
- [ ] Define a fuller belt progression and promotion-history workflow.

### Schedule

- [ ] Implement the currently preview-only bulk schedule actions.
- [ ] Separate age/audience eligibility policy from simple belt eligibility as
  personalization rules grow.
- [ ] Refactor the large schedule screen only when needed, without changing its
  behavior.

### Announcements and Notifications

- [ ] Add attachments, links, and deep-link destinations to announcements.
- [x] Add Android push permission, installation registration, token refresh,
  foreground/background handling, and safe tap routing.
- [x] Implement automated push-delivery Functions with bounded audiences,
  retries, deduplication, and dispatch records.
- [ ] Deploy the Functions after Blaze approval and validate real delivery in
  the authorized development and production environments.
- [ ] Connect APNs and validate iOS foreground, background, and terminated
  delivery on a physical device.
- [x] Persist read/unread state per authenticated user.

### Curriculum

- [ ] Obtain the complete official curriculum from the academy and replace
  placeholder/sample bundled content with approved bundled production content.
- [ ] Validate canonical belt ordering, exact academy wording, and optional
  per-form video links while preserving hardcoded local delivery. Placeholder
  forms intentionally keep unavailable video values null.

### Events

- [ ] Validate the resource-based event registration flow end to end with
  production content.
- [x] Add the academy-local student month calendar with browseable past events.
- [x] Consolidate Admin Events into the Events & Resources navigation landing.

### Multi-Location Administration

- [ ] Replace OTA Cheshire assumptions with authenticated location context.
- [ ] Add location selection/administration and verify cross-location isolation.

## Post-Launch

- [x] Sign in with Apple.
- [x] Add Apple authorization revocation to account deletion.
- [ ] Analytics and operational monitoring with an approved privacy plan.
- [ ] Advanced reporting for attendance, promotions, communications, and
  engagement.
- [ ] Richer curriculum media and progress tracking.
- [ ] Automated production release checks and signed artifact publishing.
- [ ] Optional messaging, class reminders, and event reminders.

## Completed Foundation

- [x] Flutter application shell, branded navigation, and student/admin screen
  foundations.
- [x] `AppDataService` abstraction with Firebase and mock implementations.
- [x] Firestore snapshot reads for class sessions, announcements, events,
  General Resources, and the admin student directory.
- [x] Admin writes for individual class sessions, announcements, events, and
  General Resources, including canonical optional-field clearing.
- [x] Student-facing Firestore events and General Resources.
- [x] General Resource create, edit, publish, archive, delete, canonical write
  validation, and external link actions.
- [x] Local read-only section-based curriculum with No Belt and five canonical
  categories, zero or multiple forms per belt, and independent optional video
  data per form.
- [x] Resource-based event registration.
- [x] Optional zero-or-one General Resource validation and synchronized
  compatible event resource fields for new and edited event writes.
- [x] Canonical recurring schedule fields and separate Teen/Adult Sparring type.
- [x] Student `dateOfBirth` with computed age and temporary legacy-age read
  compatibility.
- [x] Read-only Firestore audit and export utilities.
- [x] Approved one-time Firestore schema update and targeted cleanup tooling.
- [x] Unit/helper and widget coverage for core navigation, data mapping, write
  payloads, audit/cleanup safeguards, and primary student/admin flows.
- [x] Firebase Authentication, role routing, profile management, linked-profile
  switching, and notification-read persistence.
- [x] Android push client registration and handling plus automated
  push-delivery code.
- [x] iOS Firebase environment, remote-notification mode, and entitlement
  groundwork.
- [ ] Real TestFlight and Play internal testing.
- [ ] Final production curriculum/content approval and store submission.
