# Phase 17 — Data Safety and Production Bootstrap

Status: implemented

## Delivered

- Production installs no longer create a demo client or demo dog automatically.
- First launch offers an empty workspace or explicitly selected, clearly described sample data.
- JSON backups remain self-contained and now include dog photos and exercise media.
- Every media file has its own SHA-256 checksum; the manifest also covers the canonical asset list.
- Restore recreates all 23 persisted entity types, UUIDs, private fields, immutable history, ledger entries, and model relationships.
- Import validates the document, checksums, entity names, record IDs, required fields, relationships, and safe relative media paths before accepting data.
- Restore is deliberately limited to an empty workspace. It never merges with or overwrites existing business data.
- Restore failures roll back the SwiftData context and remove media written by the failed attempt.
- New onboarding and restore UI is localized in German, Spanish, and French and exposes stable control accessibility identifiers.

## Persistence baseline

DogCoach Schema V2 is the first production-release baseline. The file-backed restart test proves that a store written by this baseline reopens without data loss. No earlier App Store schema exists to migrate. Every future schema change must add the frozen previous `VersionedSchema`, an explicit migration stage, and a fixture-based upgrade test before release.

Existing development installations are not modified or cleaned automatically. Previously seeded records remain ordinary local records so that the app never guesses which data may be deleted.

## Verification gates

- A source contract test proves the live environment has no demo seeder call.
- A 23-entity roundtrip test checks IDs, private canaries, cross-entity relationships, dog photos, and exercise media.
- Negative tests cover non-empty destination stores, path traversal, checksum tampering, and unchanged destination data.
- A file-backed restart test protects the production schema baseline.
- iPhone onboarding UI tests cover both empty start and explicit sample-data selection.
- Full iPhone regression, adaptive iPad onboarding smoke, and a signed generic physical-device build must pass before push.

## Verification result (2026-08-15)

- Targeted restore/schema suite: 5 tests passed.
- Phase 17 onboarding UI: 2 tests passed on iPhone 16 and iPad Pro 11-inch (M4), iOS 18.6.
- Full regression: 103 Swift Testing tests and 12 UI tests passed; 0 failures.
- Generic physical iOS build: passed and signed for `com.personalagile.dogcoach` with Team `32ZWRSU45R` using automatic signing.
