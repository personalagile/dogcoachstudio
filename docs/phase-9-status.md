# Phase 9 status — App Store preparation

Date: 2026-08-12

## DCS-090 — Metadata and policy package

- [x] English and German metadata drafts.
- [x] Technical privacy-policy draft and App Privacy inputs.
- [x] Review notes and deterministic no-account demo flow.
- [x] Age-rating and IAP confirmation checklist.
- [ ] Operator identity and hosted HTTPS Support/Privacy URLs are external release gates.
- [ ] Legal and professional review remains required before publication.

## DCS-091 — Localized screenshots

- [x] Six benefit-led DE/EN scenes approved through the product plan and phase authorization.
- [x] Deterministic XCUITest capture suite uses synthetic data only.
- [x] Manifest records copy, scenes, privacy rule, and current target sizes.
- [x] Apple specification pages checked on 2026-08-12: 1320×2868 iPhone 6.9-inch and 2064×2752 iPad 13-inch portrait targets.
- [x] Final opaque PNG sets rendered and validated: six scenes each for DE/EN, iPhone 6.9-inch and iPad 13-inch.
- [x] Visual review completed for copy fit, privacy, locale rendering, and representative app states.
- [ ] Product-owner approval of the final DE/EN upload sets remains an external release gate.

## DCS-092 — Release and monitoring

- [x] Manual/phased release decision, P0 stop conditions, support process, and 30-day review documented.
- [x] Production smoke scope includes launch, offline data, completion idempotency, export, StoreKit restore, and privacy shield.
- [ ] App Store submission, phased release, and production metrics require operator credentials and elapsed calendar time.

## Exit assessment

The repository release package and validated screenshot binaries are prepared without inventing legal approval, hosted URLs, submission status, or production evidence. Those operator-owned gates must be completed before declaring the public 1.0 launch.

## Verification evidence

- Marketing capture suites passed on iPhone 16 and iPad Pro 11-inch (M4), iOS 18.6.
- All four localized/device screenshot sets passed format, opacity, count, and exact-dimension validation.
- The complete iPhone suite produced one isolated Phase 6 privacy-lock UI timing failure; the same test passed immediately when rerun alone. No Phase 9 or domain test failed.
