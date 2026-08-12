# ADR 0005: Keep V1 local-only after the CloudKit architecture spike

- Status: Accepted
- Date: 2026-08-12
- Phase: 8

## Context

Phase 8 requires a controlled decision between SwiftData automatic CloudKit integration and a more explicit Core Data/CKSyncEngine bridge. The product's strongest invariants are multi-record and exactly-once: a completion token must map to one immutable payload, and a package may contain at most one redemption for an attendance/package pair.

The current schema deliberately enforces these through repositories and atomic local transactions rather than persistent unique attributes. Automatic SwiftData sync cannot prove an atomic merge across completed session, attendance, results, reports, and ledger entries. A custom CKSyncEngine mapping would require production mappings and migrations for all 22 entities plus device/account testing; implementing that safely is larger than a spike and has no completed two-device evidence in this repository.

## Decision

V1 remains local-only with the complete JSON/CSV export and protected backup from Phase 6. No CloudKit entitlement or production container is added. iCloud is optional future work, never required for the app or access to local data.

The spike codifies conflict gates: same token with different fingerprints and multiple ledger IDs for one attendance/package key are hard conflicts and must never be silently merged. These gates must pass before this ADR can be superseded.

## Reconsideration requirements

- Dedicated development and production CloudKit containers.
- Explicit record mapping and schema promotion for every synced entity.
- Two-device tests for offline edits, account change, deletion, and conflict recovery.
- Proven completion-token and redemption idempotency under concurrent device writes.
- Migration and rollback plan that never strands the local store.

## Consequences

- V1 has a reliable offline/local fallback and user-controlled migration path.
- Account status UI is unnecessary because sync is not offered.
- CI and release hardening do not require CloudKit credentials.
- Personal multi-device sync remains a documented post-V1 candidate.
