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

The checked-in value of `enableFirestoreCleanupApply` is `false`. To prepare for
a separately approved live run, a developer would have to review the plan, change
that constant intentionally, type `APPLY OTA FIRESTORE CLEANUP` exactly, and
prepare a validated local backup. `Apply Cleanup` remains disabled until those
conditions are met.

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

## Backup location and format

Backups are written under the ignored `firestore_backups/` directory using this
filename pattern:

```text
firestore_cleanup_backup_YYYYMMDD_HHMMSS.json
```

Only documents affected by the approved plan are included. Each backup contains:

- `formatVersion`
- Firebase `projectId`
- UTC `generatedAt`
- `documents`, each with `collection`, `documentId`, and the complete
  `originalFields` map

Firestore values use explicit tagged JSON objects:

```json
{"__type":"Timestamp","seconds":0,"nanoseconds":0}
{"__type":"GeoPoint","latitude":41.0,"longitude":-72.0}
{"__type":"DocumentReference","path":"users/example"}
```

Date values encountered in local tests use the related `DateTime` tag. Lists and
nested maps are serialized recursively. No Firebase credentials are written.

The cleanup refuses to continue if it cannot create, read back, parse, and
validate the backup for `ota-management-platform`.

## Future controlled restore

Phase 2A deliberately has no Restore button. A future restore tool can use
`FirestoreCleanupBackup.parseAndValidate` to verify the project ID, identifiers,
field maps, and tagged Firestore values. After separate approval, that tool could
deserialize each original field map and restore it with targeted Firestore
updates. Restore behavior, conflict policy, and live execution must be reviewed
and implemented in a later phase; Phase 2A does not perform restoration.

## Apply and failure behavior

Immediately before preparing the backup, every affected document is re-read and
checked against its plan preconditions. Preconditions are checked again before
writing. Apply uses targeted `update` calls and `FieldValue.delete()` inside
one-document batches, which keeps every batch safely below Firestore's limit and
allows an exact failed collection/document ID to be reported. Processing stops
after the first failed batch and retains the backup.

After a successful apply, the Phase 1 read-only audit runs again. The result JSON
records before/after issue totals and remaining warning/error findings.
