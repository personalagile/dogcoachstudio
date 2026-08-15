# ADR 0006: Customer-data migration and recovery strategy

- Status: Accepted
- Date: 2026-08-15
- Phase: 18

## Context

DogCoach Studio stores client records, private notes, dogs, training history, packages, ledger entries, reports, photos, and exercise media locally. A schema change that opens an installed store incorrectly can make customer data unavailable or silently alter business history. A current-schema restart test and a JSON backup roundtrip are necessary but do not prove that a store created by an older public build migrates correctly.

The repository currently identifies DogCoach Schema V2 as the first production-release baseline. Schema V1 was a development schema whose model types were later reused by V2; it is not a safe historical migration source and must not be presented as a tested V1-to-V2 production upgrade.

## Decision

### Two independent protection paths

1. **In-place SwiftData migration:** Every public schema is an immutable `VersionedSchema`. `DogCoachMigrationPlan.schemas` lists all public versions in order and contains one explicit adjacent lightweight or custom `MigrationStage` per hop.
2. **Portable recovery:** The canonical JSON backup and its media assets remain independent of SwiftData internals. Backup-format versions have explicit decoders and upgrade rules. Restore continues to fail closed and only targets an empty workspace.

Neither path substitutes for the other. In-place migration provides a normal update experience; the portable backup provides user-owned recovery and portability.

### Production baseline

V2 is the first public baseline until App Store release evidence says otherwise. Before the first public release, archive:

- the exact release Git tag and build number;
- a sanitized, file-backed V2 store created by that build;
- a complete V1 backup-format package with representative media;
- an inventory of entity counts, stable UUIDs, relationships, immutable history, ledger sums, private canaries, and media hashes.

After release, the baseline is immutable. A future V3 change starts by copying the fixture with the released V2 app, before any `@Model` declaration is edited. The V2 model definitions must then be frozen as distinct historical types while application code moves to V3 types.

### Change classification

- **Lightweight:** additive optional/defaulted attributes and framework-supported renames using the persisted original name, only after fixture proof.
- **Custom:** required-value backfills, type/semantic conversions, relationship changes, split or merged fields, invariant changes, and any transformation of existing values.
- **Expand-migrate-contract:** destructive or risky transitions use compatible old and new representations across releases; removal happens only after adoption evidence and a later migration.

Changing delete rules, uniqueness, required relationships, numeric precision, ledger semantics, completion identity, or immutable session history is considered destructive until a custom plan proves otherwise.

### Migration implementation rules

- Never edit a released schema in place.
- Never skip an intermediate public schema.
- Preserve stable UUIDs, completion tokens, snapshots, reports, package ledger history, privacy classifications, and asset references.
- Do not seed defaults that look like real customer facts. Unknown values remain explicitly unknown.
- Do not fall back to deleting or recreating a store when container creation fails.
- Before opening a store with a new schema in production, preserve a recoverable pre-migration copy of the store and sidecars when the storage implementation permits a consistent copy. Retain it until the migrated store has reopened and passed invariant checks.
- Migration and recovery remain offline and local; no customer data is uploaded for this process.

### Required test matrix

For every public version hop, tests must use a native store produced by the previous released binary, not a store synthesized by the new model code. They verify:

- successful old-to-new open and a second clean restart;
- entity counts, stable ID sets, required relationships, archive state, completion/result/report counts, immutable snapshots, and private-field canaries;
- package balance equals the sum of ledger entries and no redemption is duplicated;
- post-migration backup export and empty-store restore preserve semantic values and media hashes;
- corrupted input, insufficient storage, interruption, and migration failure never expose an empty replacement store;
- representative small and large stores on the oldest supported OS and a current OS.

The full unit/UI regression, iPhone and iPad smoke tests, and signed device build remain release gates.

### Rollout and recovery

Migrations move through internal builds, external TestFlight, and phased App Store release. Privacy-safe diagnostics identify only closed migration event codes and build/schema versions. Any unexplained count, relationship, ledger, history, or media mismatch pauses rollout.

Downgrade is not supported because an older binary cannot understand a newer store. Recovery uses the preserved pre-migration copy or a user-owned portable backup with a compatible build; support must never begin with deleting the app.

## Compatibility matrix

| Public app line | SwiftData schema | Backup format | In-place source | Evidence |
|---|---:|---:|---|---|
| First production release | V2 | V1 | None; baseline | Current-schema restart and full backup/restore are green; released-build fixture must be archived at release |
| Next schema release | V3 | V1 or V2, decided by backup semantics | V2 | Blocked until a V2 store from the released binary passes the full migration matrix |

## Consequences

- Persisted model changes require more preparation than ordinary Swift refactors.
- Release fixtures and compatibility evidence become versioned product artifacts.
- Customer data is protected by both automatic upgrade and independent recovery paths.
- A migration ticket is blocked when the previous public build or representative native-store fixture is unavailable.

## References

- [Apple: SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Apple: VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [Apple: MigrationStage](https://developer.apple.com/documentation/swiftdata/migrationstage)
