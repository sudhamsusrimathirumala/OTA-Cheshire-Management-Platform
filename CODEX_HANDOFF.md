# OTA Cheshire integrated release handoff

## Purpose

This file supersedes the branch-specific Android compliance and Flutter Web
handoffs after their deliberate integration into `main`. The source histories
remain available on `android-production-compliance` and `flutter-web`.

## Integrated checkpoints

- Android compliance: `3553c63931a75f5a46aa8d297e8404750f95387b`
  (including curriculum/account-audience checkpoint `88aa1ba`).
- Flutter Web: `d9dbcde0f42ae1ad0c07ee402cfc141fff23b0b0`
  (including `da4de7f`, `c87e542`, and `9991df0`).
- Common integration base: `8c6760a5e6c198138d3980a0feb58d128a373e95`.

## Behavior preserved by the integration

- Independent Student accounts require age 16+; Parent/Guardian accounts
  require age 18+. Younger students remain valid as parent- or staff-managed
  profiles and are not treated as authenticated app users.
- Provider login rejects newly provisioned identities and directs applicants
  through the age-gated registration flow. Native Google and Apple behavior is
  retained, including Apple authorization revocation before cleanup.
- Web Google authentication uses Firebase popup flows with account selection.
  The same new-identity registration safeguard applies on Web. Apple Web login
  remains unavailable pending external Apple Web configuration.
- Account deletion preserves password, native Google, native Apple, and Web
  Google reauthentication, plus safe profile/subcollection deletion ordering.
- Curriculum YouTube access is based on the authenticated role: Student,
  Parent, Admin, and Super Admin may opt in to load video; Guest Reviewer may
  not. A younger linked profile does not remove a Parent's access.
- Web-safe startup, compile-time `OTA_FIREBASE_WEB_*` configuration, native-only
  Crashlytics/push setup, Hosting configuration, branding, and narrow-layout
  fixes remain present. No production Web values are invented or checked in.
- Firestore Rules enforce trusted-time age boundaries while preserving managed
  younger profiles, role/location authorization, Guest isolation, Super Admin
  behavior, deletion protections, and deny-all fallback behavior.

## External work intentionally not performed

- No Firebase deployment or production data mutation.
- No Google Play upload or release submission.
- No production Firebase Web app registration, OAuth/domain change, Hosting
  preview, or live Hosting deployment.
- Physical iPhone Safari/Home Screen validation and Web Apple configuration
  remain future Web-release work.

## Release evidence

The integration commit, final version, validation counts, production Rules
comparison, signed AAB path, and remaining release actions are recorded in the
completion report for the integration task that created this handoff.
