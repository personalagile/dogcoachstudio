# Phase 6 status — Datenschutz, Export und MVP-Hardening

Date: 2026-08-12

## DCS-060 — Full data export

- [x] Versioned canonical JSON package for all 22 schema-v1 entities.
- [x] Per-entity CSV exports.
- [x] Manifest, record count, and SHA-256 checksum validation.
- [x] Roundtrip, corruption, unknown-version, and 10,200-record tests.
- [x] Private fields retained in the owner backup; no silent omission in covered schema fields.

## DCS-061 — Delete and archive

- [x] Dependency preview for dogs.
- [x] Export confirmation required before dependent records are deleted.
- [x] Business-history deletion blocked by default; archive path provided.
- [x] Explicit cascade removes results, ledger entries, attendance, bookings, packages, reports, intake, goals, roles, and dog without package orphans.

## DCS-062 — App lock and file protection

- [x] Optional device-owner authentication with biometric/passcode policy.
- [x] Lockout and unavailable-authentication guidance without exposing content.
- [x] Export files use complete-unless-open file protection.
- [x] Foreground lock and inactive/background privacy shield.

## DCS-063 — Performance and accessibility

- [x] Automated 200-dog/10,000-result export baseline with a generous non-flaky 10-second safety gate.
- [x] Data/privacy flow uses semantic controls and accessibility identifiers.
- [x] XXXL Dynamic Type UI smoke.
- [x] Status and errors use text and symbols rather than color alone.
- [ ] Manual VoiceOver and Instruments passes remain release checklist work on physical devices.

## DCS-064 — MVP TestFlight

- [x] Existing demo data is fictional and deterministic.
- [x] Privacy-safe diagnostic export is available in the Data tab.
- [x] Two-week cohort, test matrix, blocker triage, and Go/No-Go plan documented.
- [ ] TestFlight upload and 30–50-person pilot require distribution credentials and real participants.
- [ ] Product Go remains contingent on collected pilot evidence; it cannot be declared from implementation alone.

## Exit assessment

The code-level TestFlight MVP scope for Phase 6 is implemented. Distribution and product-decision evidence remain external execution gates, not implementation defects.

## Verification evidence

- Generic iOS Simulator `build-for-testing`: succeeded.
- Full Swift Testing regression: 69 tests in 15 suites passed on iPhone 16 / iOS 18.6.
- Phase 0 UI regression: passed after deterministic app-lock test isolation.
- Phase 6 iPhone UI: JSON/CSV export at XXXL Dynamic Type and locked-content protection passed.
- Phase 6 iPad UI: adaptive export/XXXL and locked-content protection passed on iPad Pro 11-inch (M4) / iOS 18.6.
- Large fixture export: 200 dogs plus 10,000 results completed in about 1.5 seconds on the simulator (regression baseline, not a device performance claim).
