# Firestore deterministic cleanup

Phase 2A adds a development-only cleanup planner for deterministic schema
maintenance. It is separate from normal application startup and from the older
Firestore migration. It never creates or deletes documents.

## Running the planner

```powershell
flutter run -t lib/firestore_cleanup_main.dart
```

`Generate Cleanup Plan` reads the seven audited collections and creates a dry-run
plan. It does not write to Firestore. Plan JSON separates automatic field updates
and deletions from unresolved content or relationship decisions.

The `enableFirestoreCleanupApply` constant controls whether live apply is
available. The developer must also review the plan and type
`APPLY OTA FIRESTORE CLEANUP` exactly. `Apply Cleanup` remains disabled until
those conditions are met and the current plan has operations with no failed
preconditions.

## Deterministic scope

The planner can:

- remove `startTime`, `endTime`, and explicitly-null optional class fields after
  validating the canonical recurring schedule fields;
- set `resourceSection` to `general`, normalize known category variants, backfill
  the two approved missing resource types, move a non-empty legacy `url` into an
  empty `linkUrl`, and remove deterministic legacy/null URL fields;
- remove an explicitly-null student profile `selfUserId`.

It preserves timestamps, schedule minutes, publication/archive state, student
ages, guardian relationships, content, event relationships, and compatibility
event fields. Ambiguous relationships and placeholder-looking content remain in
the plan's unresolved section.

## Apply and failure behavior

Immediately before writing, every affected document is re-read. A stable
full-document fingerprint and every planned field precondition must still match.
All affected documents are validated before the first write begins. Apply uses
targeted `update` calls and `FieldValue.delete()` inside one-document batches,
which keeps every batch safely below Firestore's limit and allows an exact failed
collection/document ID to be reported. Processing stops after the first failed
batch.

After a successful apply, the Phase 1 read-only audit runs again. The result JSON
records before/after issue totals and remaining warning/error findings.
