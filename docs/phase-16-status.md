# Phase 16 — Finance

Status: implemented

## Delivered

- Finance tab based exclusively on append-only package purchase ledger entries and purchase reversals.
- Month, quarter, year, and all-time filters plus separate currency views.
- Revenue, package-sale count, and average-sale KPIs.
- Accessible revenue timeline and package breakdown charts with matching tabular values.
- Sales ledger table and CSV export through the system share sheet.
- Refund reversals now carry the opposite money delta and the original currency.
- German, Spanish, and French localizations for the Finance UI.

## Verification gates

- Pure analytics tests cover period boundaries, currencies, refunds, totals, and grouping.
- SwiftData tests prove adjustments, redemptions, and coupons are excluded from revenue.
- CSV tests cover stable headers and escaping.
- iPhone and iPad UI smoke tests cover the dashboard, charts, table, and export action.
- Full regression suite and signed physical-device build must be green before the phase is pushed.

## Verification result (2026-08-13)

- Targeted Phase 16 unit and UI suites: passed on iPhone 16 / iOS 18.6.
- Adaptive Finance UI smoke test: passed on iPad Pro 11-inch (M4) / iOS 18.6.
- Full regression: 108 tests passed, 0 failed, 0 skipped.
- Generic physical iOS build: passed and signed for `com.personalagile.dogcoach` with Team `32ZWRSU45R`.

Finance values are operational sales analytics, not tax or accounting advice. Each currency remains separate; no exchange-rate conversion is inferred.
