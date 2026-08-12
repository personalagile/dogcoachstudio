# ADR 0004: Versioned backup and guarded data lifecycle

- Status: Accepted
- Date: 2026-08-12
- Phase: 6

## Context

DogCoach Studio stores private and business-relevant data locally. Users need a portable export that does not depend on SwiftData's internal SQLite representation, and destructive actions must not silently remove history.

## Decision

The app exports a canonical JSON package with a schema version, normalized records for every schema-v1 entity, per-entity CSV files, a record count, and a SHA-256 checksum of the backup document. Import/migration code must reject unknown versions and checksum mismatches before changing the store.

Private fields belong in the user-owned backup so it is complete. They remain structurally excluded from client reports and diagnostic exports. Diagnostics contain only timestamps, categories, and closed event codes.

Deletion first produces a dependency preview and recommends an export. Objects with package, booking, or report history default to archive. Permanent deletion requires explicit export confirmation and a separate confirmation for business history, then deletes dependents before the parent and clears optional references.

Export files use `NSFileProtectionCompleteUnlessOpen`. The optional app lock uses device-owner authentication, allowing the device passcode as a biometric fallback, and overlays content whenever the app leaves the foreground.

## Consequences

- Backup compatibility is explicit and testable across future schema migrations.
- Full backups are sensitive documents and must be handled as carefully as the local store.
- CSV files are intended for user inspection and migration, while JSON is the lossless canonical format.
- SwiftData schema v1 remains unchanged in Phase 6.
