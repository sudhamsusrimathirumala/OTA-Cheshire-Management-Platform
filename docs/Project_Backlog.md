# Project Backlog

This backlog reflects gaps visible in the current codebase. Completed database
cleanup and schema-update work is not listed as active work.

## Must Complete Before Deployment

### Identity and Authorization

- [ ] Connect the login, signup, Google sign-in, and password-reset UI to
  Firebase Authentication.
- [ ] Load the current `users` document and enforce approval status.
- [ ] Route and guard student, parent, instructor, and administrator areas by
  authenticated role.
- [ ] Implement account onboarding and the no-linked-profile state.
- [ ] Load linked/selected student profiles from Firestore and enforce
  account/profile ownership.

### Firestore Security and Data

- [ ] Add and test production Firestore security rules. No rules file is
  present in the repository.
- [ ] Verify authorization for every admin write and explicit document-delete
  path.
- [ ] Resolve guardian user IDs to user display names and validate guardian/self
  relationships against authenticated accounts.
- [ ] Run a fresh read-only audit of production data and resolve remaining
  errors, warnings, placeholder URLs, or placeholder content before launch.
- [ ] Keep historical migration, cleanup, seed, and schema-update tools disabled
  or out of production builds.

### Release Readiness

- [ ] Configure production Android signing; the current release build uses the
  debug signing configuration.
- [ ] Validate a release-mode Android build on supported devices.
- [ ] Complete end-to-end tests for authentication, role access, Firestore
  permissions, student/parent reads, and admin writes.
- [ ] Review production academy content and links with stakeholders.

## Important Product Work

### Student, Parent, and Account Experience

- [ ] Implement a parent/family dashboard for multiple linked students.
- [ ] Add profile switching for parent, student, and parent-who-trains cases.
- [ ] Add production handling for accounts with no linked student profile.
- [ ] Replace hardcoded/fallback current-user and selected-profile state.

### Student Management

- [ ] Add approved admin student-profile editing and validation.
- [ ] Add parent/user management rather than displaying guardian IDs.
- [ ] Define a fuller belt progression and promotion-history workflow.

### Schedule

- [ ] Implement the currently preview-only bulk schedule actions.
- [ ] Separate age/audience eligibility policy from simple belt eligibility as
  personalization rules grow.
- [ ] Refactor the large schedule screen only when needed, without changing its
  behavior.

### Announcements and Notifications

- [ ] Add attachments, links, and deep-link destinations to announcements.
- [ ] Add device push delivery. The current notification center is an in-app
  presentation of Firestore announcements.
- [ ] Define persistent read/unread state per authenticated user.

### Curriculum

- [ ] Replace local sample curriculum and placeholder items with approved
  production curriculum content.
- [ ] Select and implement a production curriculum data source and media model.
- [ ] Keep curriculum separate from General Resource documents unless the
  canonical schema is deliberately changed.

### Events and Resources

- [ ] Validate the resource-based event registration flow end to end with
  production content.
- [ ] Add calendar-oriented event UX only after core release blockers are
  complete.
- [ ] Continue resource UX polish based on real family/admin usage.

### Multi-Location Administration

- [ ] Replace OTA Cheshire assumptions with authenticated location context.
- [ ] Add location selection/administration and verify cross-location isolation.

## Post-Launch

- [ ] iOS signing and distribution.
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
- [x] Resource-based event registration.
- [x] Canonical recurring schedule fields and separate Teen/Adult Sparring type.
- [x] Student `dateOfBirth` with computed age and temporary legacy-age read
  compatibility.
- [x] Read-only Firestore audit and export utilities.
- [x] Approved one-time Firestore schema update and targeted cleanup tooling.
- [x] Unit/helper and widget coverage for core navigation, data mapping, write
  payloads, audit/cleanup safeguards, and primary student/admin flows.
