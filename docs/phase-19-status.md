# Phase 19 — Rich Debug demo data

Status: implemented

## Delivered

- Debug and preview environments receive a coherent sample workspace with three clients, four dogs, intakes, goals, exercises, a training template, sessions, package templates, sold packages, ledger history, reports, and completed training history.
- Finance demo data spans multiple dates and package types so revenue KPIs, charts, package breakdowns, transaction tables, and CSV export have representative content.
- The fixture includes evaluated and unevaluated past sessions plus current and future sessions for day, week, and month views.
- Stable fixture IDs and a marker make seeding idempotent. A non-demo workspace is never augmented by the seeder.
- Automatic seeding in `AppEnvironment.live()` is enclosed in `#if DEBUG`. Release builds do not execute or expose the sample-data onboarding choice.

## Persistence impact

No schema, model property, relationship definition, migration plan, backup format, or restore mapping changed. The fixture only creates records supported by the existing V2 schema.

## Verification gates

- Assert expected entity counts and cross-feature content.
- Assert finance month/all totals and package breakdowns.
- Assert both evaluated and open past sessions exist.
- Assert a repeated seed produces no additional records.
- Assert a non-demo workspace remains unchanged.
- Assert the automatic live seed call is enclosed by the Debug compilation condition.

## Verification result (2026-08-15)

- Phase 19 targeted suite: 3 tests passed.
- Full iPhone 16 / iOS 18.6 regression: 118 test definitions, 124 runs, 0 failures.
- Finance UI smoke on iPad Pro 11-inch (M4) / iOS 18.6: passed.
- Release simulator build: passed.
- Signed generic physical-device Release build: passed with the existing automatic-signing settings.
