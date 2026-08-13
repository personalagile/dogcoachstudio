# Phase 12 – Client packages, pricing, and session metadata

Status: implemented.

## Delivered

- Training packages are owned by clients. Existing dog-owned packages are assigned to the dog's primary contact when the repository opens them.
- Trainers can create, edit, archive, and reuse priced package templates. Template lists show their number of sales.
- Packages can be sold directly from a client record or the Packages tab. Client records show package count, individual prices, and total revenue.
- Sold packages can be edited or deleted while they only contain their purchase entry. Once consumption or another ledger event exists, deletion is rejected so financial and training history cannot be corrupted.
- Sessions support normalized searchable labels and a configurable package consumption per attendee. A value of zero creates a trial session without a redemption.
- Session completion previews and ledger redemptions use the configured unit amount exactly once.
- Backup exports include package ownership, template references, prices, package templates, session labels, and configured consumption.
- New UI text is localized in German, Spanish, and French.
- Package sale and template forms use persistent field labels, examples, explanatory help text, explicit currency and payment status, validation, and a preview before saving. The client-detail sale flow explains what a template contributes.

## Persistence

`DogCoachSchemaV2` adds `PackageTemplateRecord` and additive fields for client package ownership, session labels, and package consumption. The container uses automatic lightweight migration to the current V2 schema. A frozen V1-to-V2 custom stage is intentionally not declared because the original V1 schema references the same mutable model types and therefore produces duplicate SwiftData checksums. Legacy owner backfill is deterministic and covered by tests.

## Verification

- Package template pricing and sales count
- Client ownership and legacy owner backfill
- Package create, update, guarded delete, and ledger history protection
- Label normalization and zero-unit trial behavior
- Schema V2 registration
- Existing package, session, persistence, export, and UI regression suites

Final verification on 2026-08-12:

- Full iPhone 16 / iOS 18.6 suite: 100 tests (106 parameterized invocations), 0 failures.
- Package UI smoke on iPad Pro 11-inch (M4) / iOS 18.6: passed.
- Generic iOS device build: passed and signed as `com.personalagile.dogcoach` by team `32ZWRSU45R` using automatic signing.
