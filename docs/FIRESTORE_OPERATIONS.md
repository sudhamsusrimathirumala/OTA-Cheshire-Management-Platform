# Firestore Operations

These utilities are excluded from normal app startup and must not be exposed
through production navigation. Confirm the configured project and inspect the
current source before running any write-capable target.

| Tool | Entry point | Read or write | Current enabled state | Purpose | Safe to run repeatedly | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Audit | `lib/firestore_audit_main.dart` | Read-only | No write flag; refuses release mode | Reads the seven application collections, validates schema and relationships, and copies a JSON report | Yes | Does not modify Firestore |
| Export | `lib/firestore_export_main.dart` | Read-only | No write flag; refuses release mode | Exports the seven top-level application collections as formatted JSON for review | Yes | Copy or save the generated JSON; this is not a restore/backup system |
| Cleanup planner/apply | `lib/firestore_cleanup_main.dart` | Read, then optional targeted writes | `enableFirestoreCleanupApply` is currently `true` | Generates a deterministic plan, validates preconditions, applies targeted field updates/deletions, and reruns the audit | Planning: yes. Apply: designed to be idempotent, but run only with explicit approval | Requires exact confirmation and project ID match; supports no document deletion; no backup is required |
| MVP readiness migration | `lib/seed_firestore_main.dart` | Read/write | `_enableFirestoreMigration` is `false` | Runs the merge-only readiness migration and may create missing starter resources | Yes, designed to be idempotent | The only manual migration entrypoint; do not run against production/shared data without a fresh backup and review |
| Approved schema update | `lib/firestore_schema_update_main.dart` | Targeted writes | `enableApprovedSchemaUpdate` is `false` | Historical one-time update for sparring IDs, event legacy-field removal, and five student birth dates | Technically repeatable if all target documents exist, but intended once | Already applied; keep disabled |
| Full development seed | `tool/seed_firestore.dart` | Writes complete sample documents | No entrypoint guard; internal service flag does not protect this script | Writes sample users, profiles, sessions, announcements, events, and resources using fixed IDs | No | May overwrite documents with matching IDs; do not use on the shared database |

## Exact Commands

Read-only audit:

```powershell
flutter run -t lib/firestore_audit_main.dart
```

Read-only export:

```powershell
flutter run -t lib/firestore_export_main.dart
```

Cleanup planning and guarded apply:

```powershell
flutter run -t lib/firestore_cleanup_main.dart
```

The plan is read-only. Apply requires `enableFirestoreCleanupApply`, the exact
text `APPLY OTA FIRESTORE CLEANUP`, a non-empty plan for
`ota-management-platform`, successful preconditions, and a final dialog. The
service rereads all affected documents before the first write, stops on the
exact failed document, performs no document deletion, and runs a post-cleanup
audit.

MVP readiness migration:

```powershell
flutter run -t lib/seed_firestore_main.dart
```

This entrypoint calls `FirestoreMigrationService.runMvpReadinessMigration()`,
not `FirestoreSeedService.seedAll()`. To run it deliberately, review the code
and target project, take a backup, temporarily set
`_enableFirestoreMigration = true`, run once, capture the displayed counts,
then restore the flag to `false`. It never deletes user, profile, location, or
resource documents. It normalizes safe user fields, derives only unambiguous
guardian emails, reports missing email/address data, maps legacy resource
categories to `general`, and explicitly deletes legacy `resourceType` fields.

Historical approved schema update:

```powershell
flutter run -t lib/firestore_schema_update_main.dart
```

This completed one-time tool is disabled. Do not re-enable it without reviewing
every fixed document ID and operation.

Full sample seed:

```powershell
flutter run -t tool/seed_firestore.dart
```

This is the highest-risk utility because the script directly invokes the full
seeder without checking `_enableDevelopmentFirestoreSeed`. It writes complete
sample documents and may overwrite matching IDs.

## Historical Reports

`docs/firestore_audit_report.json` is a read-only snapshot generated at
`2026-07-11T23:26:06.212471Z`. It is retained as historical evidence and must
not be interpreted as the current state of Firestore. Legacy field findings in
that JSON describe the database at that time, not the current canonical schema.
