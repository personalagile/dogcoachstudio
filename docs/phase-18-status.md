# Phase 18 — Customer-data migration readiness

Status: strategy and agent guardrails implemented; first public-release fixture pending the actual release build

## Delivered

- ADR 0006 defines immutable public SwiftData schemas, adjacent migration stages, backup-format compatibility, fixture-based verification, rollout, and recovery.
- The repository-owned `dogcoach-data-migrations` skill provides a mandatory implementation and review workflow for every persisted-data change.
- Root `AGENTS.md` routes future agents to that skill whenever models, schemas, backup mappings, restore behavior, or media manifests change.
- Release gates cover stable IDs, relationships, immutable training history, private fields, ledger sums, media hashes, restart behavior, failure safety, and old/new backup compatibility.

## Current truth

- DogCoach Schema V2 remains the first intended production baseline.
- The existing current-schema restart and complete backup/restore tests are green, but they are not evidence of a historical V1-to-V2 production migration.
- No public predecessor store exists yet. The exact V2 store fixture and portable backup must be generated and archived from the final App Store build before release.
- The next persisted schema change is blocked until that released-build fixture exists. V2 must then be frozen rather than edited in place.

## Next release gate

Archive the final build number, Git tag, sanitized all-entity V2 native store, V1-format portable backup, media tree, and invariant inventory. Exercise restore once on a clean device before submitting the first production build.
