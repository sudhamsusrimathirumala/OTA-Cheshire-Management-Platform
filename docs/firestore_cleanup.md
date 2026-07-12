# Firestore Deterministic Cleanup

The repository contains a development-only cleanup planner and guarded apply
flow. This document summarizes its implementation. Operational cautions and all
database tools are documented in [Firestore operations](FIRESTORE_OPERATIONS.md).

## Entry Point

```powershell
flutter run -t lib/firestore_cleanup_main.dart
```

`Generate Cleanup Plan` reads the seven application collections and produces a
deterministic JSON plan without writing. The plan separates approved field
updates/deletions from unresolved content and relationship decisions.

The source currently has `enableFirestoreCleanupApply = true`. Live apply also
requires:

- the exact text `APPLY OTA FIRESTORE CLEANUP`;
- a non-empty plan for `ota-management-platform`;
- no failed operation preconditions; and
- a final confirmation dialog.

## Scope and Safety

The planner performs deterministic canonicalization such as removing validated
legacy schedule fields, normalizing General Resource fields/categories, moving
legacy resource `url` to `linkUrl` where safe, and removing an explicitly null
student `selfUserId`.

It does not create or delete documents. It does not invent guardian, event, or
resource relationships, and it does not rewrite ambiguous or placeholder
content.

Immediately before writing, the service rereads every affected document and
verifies full-document fingerprints and planned preconditions. All documents
are validated before the first write. Apply uses targeted updates and
`FieldValue.delete()`, stops on the exact failed document, and runs the read-only
audit again after a successful apply.

No filesystem backup is required by this tool. Apply is intended only for an
explicitly reviewed plan and should not be exposed in production navigation.
