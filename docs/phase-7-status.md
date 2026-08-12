# Phase 7 status — Editorial catalog and StoreKit

Date: 2026-08-12

## DCS-070 — Foundation catalog v1

- [x] The user-approved, bundled Foundation pack remains the canonical source; no training doctrine was generated in this phase.
- [x] Author, license, semantic version, pack review status, and per-locale review status are mandatory.
- [x] Every exercise must contain exactly reviewed German and English localizations.
- [x] Phase-7 import rejects risk levels beyond the approved `standard` level.
- [x] Checksum, references, duration totals, locale coverage, and approval metadata have automated tests.

The repository records technical validation of the user's approval. Legal ownership and professional-language review remain the responsibility of the named author/reviewer.

## DCS-071 — StoreKit configuration

- [x] Local StoreKit configuration contains monthly Pro, annual Pro, and the non-consumable Foundation pack.
- [x] The run scheme references the checked-in StoreKit configuration.
- [x] The central `@MainActor` store listens for transaction updates at initialization.
- [x] Entitlements are granted only for verified transactions and each verified transaction is finished.
- [x] Pending, cancellation, restore, current entitlements, and revocation/refund paths are represented.
- [x] Core entitlement evaluation is local and requires no DogCoach server.
- [ ] App Store Connect products and physical-device Sandbox tests require distribution credentials and external configuration.

## DCS-072 — Fair paywall

- [x] Prices and durations come from StoreKit rather than hardcoded UI prices.
- [x] Restore Purchases is visible.
- [x] Existing data remains readable and exportable without an active entitlement.
- [x] Semantic controls and an explicit accessible purchase label are present.
- [x] English and German product metadata exist in the StoreKit configuration.
- [x] Deterministic paywall launch contract exists for App Review and UI testing.

## Verification

- Phase-7 Swift Testing suite passed on iPhone 16 / iOS 18.6.
- Phase-7 paywall UI smoke passed on iPhone 16 / iOS 18.6.
- Full StoreKit Test Session purchase/renewal/refund and Sandbox evidence remains an external release gate because it requires StoreKit runtime/account state.

## Exit assessment

The approved catalog and local purchase implementation are testable. Phase 7 can be committed, while App Store Connect/Sandbox evidence remains explicitly open for release operations.
