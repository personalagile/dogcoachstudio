---
name: dogcoach-data-migrations
description: Safely plan, implement, review, and verify DogCoach Studio SwiftData schema and backup-format changes. Use whenever work changes an @Model, VersionedSchema, SchemaMigrationPlan, persistent property or enum, relationship, delete rule, uniqueness rule, media manifest, backup field, or restore behavior, and for release-readiness checks involving existing customer data.
---

# DogCoach Data Migrations

Protect installed customer data while evolving DogCoach Studio. Treat a persisted-data change as a release migration, not as a local model refactor.

## Start with the release baseline

1. Read `docs/adr/0006-customer-data-migration-strategy.md` completely.
2. Inspect `DogCoachStudio/Persistence`, `DataBackupService`, `DataBackupRestoreService`, the latest phase status, and the current Git status.
3. Identify the latest shipped App Store build and schema version. Do not infer this from the branch alone.
4. Obtain or create a sanitized store fixture with the latest shipped build before changing model code. Include every entity, relationship, private field, immutable history record, ledger entry, and media reference affected by the change.
5. If the shipped build/tag or representative fixture is unavailable, stop the schema implementation and report the release blocker. Documentation and nonpersisted UI work may continue.

## Classify the change

- Use a lightweight stage only for a change SwiftData can infer without losing meaning, and prove it with the old-store fixture.
- Use a custom stage for backfills, semantic transformations, relationship changes, new required values, split/merged fields, or changed invariants.
- Use expand-migrate-contract across releases when old and new representations must coexist safely.
- Treat deletion, type narrowing, uniqueness, changed delete rules, and ledger/history rewrites as destructive until proven otherwise.
- Version the portable backup format independently from the SwiftData schema. Keep import support for every publicly released backup version or provide an explicit, tested upgrade chain.

## Implement in this order

1. Create a user-readable backup with the old release and archive the sanitized old-store fixture.
2. Freeze the released schema definition. Never edit or reuse a released `VersionedSchema` as the new schema.
3. Add `DogCoachSchemaVNext` and append it to `DogCoachMigrationPlan.schemas` in order.
4. Add exactly one adjacent `MigrationStage` for each version hop. Do not skip versions.
5. Preserve identifiers, ledger sums, completion tokens, immutable snapshots, privacy boundaries, and media paths during transformation.
6. Update backup export and restore mappings for every changed persisted field. Increment the backup format only when decoding semantics change.
7. Add release notes and update the compatibility matrix in the ADR.

## Required verification

- Open a copied old-store fixture with the new container and assert the expected schema version.
- Compare before/after entity counts, stable UUID sets, required relationships, archive flags, package balances, completion/result/report counts, and private-field canaries.
- Reopen the migrated store in a fresh container and repeat critical assertions.
- Export a post-migration backup and restore it into an empty store; compare semantic content and media checksums.
- Test migration failure and insufficient-storage handling. Never delete, reset, or silently recreate an unreadable customer store.
- Run the full Swift Testing and UI regression on iPhone and iPad, plus a signed device build.

Use the detailed release gates in `references/release-gates.md` when creating or reviewing a migration ticket.

## Prohibited shortcuts

- Do not modify a released schema in place.
- Do not make migration success depend on demo seeding or network access.
- Do not use `try?`, store deletion, or a fresh-container fallback when opening the production store fails.
- Do not claim migration coverage from a current-schema restart test.
- Do not use JSON backup/restore as a substitute for automatic in-place migration; it is the independent recovery path.
- Do not ship without a fixture created by the previous released app version.

## Handoff

Report the source and destination schema versions, migration classification, fixture origin, transformed fields, invariant results, backup compatibility, tested OS/device matrix, rollback/recovery path, and remaining risks.
