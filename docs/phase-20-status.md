# Phase 20 — TestFlight feedback iteration

## Implemented

- Dog creation and editing now expose a direct owner picker. The previous generic contact-role creation flow is no longer part of the dog UI. Existing persisted legacy role values remain readable so TestFlight customer data is not rewritten or discarded.
- Safety markers are presented as private, factual safety-and-handling reminders with concrete examples and an explicit non-diagnostic boundary.
- Catalog exercises can be filtered by All, Standard, or Personal and searched. Standard content is derived from the existing editorial content-pack relationship; no persisted field was added.
- Package templates appear before sold packages, use expandable rows with name and price in the collapsed state, and the complete area is searchable by template, package, or client.
- Finance analytics derive and display the top ten clients by revenue and sale count.
- Pilot diagnostics now produce an immediately shareable privacy-safe artifact.
- StoreKit product loading has a bounded wait. An empty or unavailable TestFlight response becomes an actionable retry state instead of an endless price spinner.
- New interface copy is localized in German, Spanish, and French.

## Persistence and migration decision

No SwiftData model, schema, relationship, enum storage, backup field, restore mapping, or media manifest changed in this phase. `DogCoachSchemaV2` remains the released TestFlight baseline.

A veterinarian or emergency contact that is not a client requires a new persistent entity and relationship. That work is intentionally deferred to Schema V3 until a sanitized native V2 store fixture from the released TestFlight build is available and passes the migration gates in ADR 0006 and the repository migration skill. Handler, emergency-contact, and other legacy raw role values remain decodable but are no longer offered by the dog UI.

## Verification

- Generic iOS Simulator build: passed.
- Swift Testing: 108 tests in 24 suites passed.
- iPhone People UI regression: passed after adapting the owner section.
- Directly affected iPhone UI flows for Catalog, Packages, Data Control, Paywall, and Finance: passed.
- Strengthened UI assertions verify the catalog filter, expandable package-template row, diagnostic share result, and top-client finance section.
- String Catalog JSON validation and `git diff --check`: passed.
