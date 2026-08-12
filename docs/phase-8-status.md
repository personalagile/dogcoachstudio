# Phase 8 status — Sync decision, CI, and release hardening

Date: 2026-08-12

## DCS-080 / DCS-081 — Personal sync

- [x] SwiftData automatic sync and an explicit CKSyncEngine bridge were evaluated against the schema and invariants.
- [x] Completion-token and ledger-redemption conflict gates have automated tests.
- [x] ADR 0005 records a No-Go for CloudKit in V1.
- [x] Local operation and protected JSON/CSV export remain the functional fallback.
- [x] No iCloud account is required and no incomplete CloudKit capability is shipped.
- [ ] Two-device/account/offline tests are intentionally not claimed; they are prerequisites for superseding the No-Go ADR.

## DCS-082 — CI/CD

- [x] GitHub Actions regenerates the project, rejects project drift, and runs build/tests on changes.
- [x] Deterministic in-memory fixtures are used.
- [x] No signing certificate, provisioning profile, API key, or secret is committed.
- [x] Xcode Cloud post-clone project generation is provided.
- [ ] Signed TestFlight upload remains optional and requires externally configured App Store Connect credentials.

## DCS-083 — Release hardening

- [x] Schema-v1 file-backed restart and collection roundtrip tests cover migration baseline.
- [x] Offline-first architecture has no backend dependency.
- [x] 200-dog/10,000-result baseline exists.
- [x] StoreKit, complete export, diagnostic privacy, app lock, and deletion safeguards are covered.
- [x] Phase 6 privacy review and ADR 0004 remain canonical.
- [ ] Low-storage behavior must still be exercised on a constrained physical device before submission.

## Exit assessment

The release-candidate architecture is local-only by explicit No-Go decision, with CI and deterministic quality gates. External CI execution, physical-device hardening, signing, and TestFlight distribution remain release-operation evidence.
