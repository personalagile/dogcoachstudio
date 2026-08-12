# Phase 13 – Live data and system sharing

Status: implemented.

## Delivered

- Removed the production `Completion demo` tab, its launch mode, PoC implementation, and obsolete Phase 0 UI/unit tests. Persistent session completion remains the only completion flow.
- Added a shared observable data revision across People, Sessions, and Packages. Every committed mutation emits a revision; screens reload on revision changes and whenever they appear, so renamed dogs, clients, sessions, packages, and templates never wait for incidental redraws.
- Sold packages now explicitly display the purchased package template in both the Packages tab and the client record.
- Added Apple Contacts integration:
  - Import through the system contact picker without broad contact-library access.
  - Save a client to Apple Contacts after the system permission request.
  - Added the required Contacts usage description while preserving the existing automatic signing configuration.
- Added an allowlist-based Intake PDF. It includes only client-facing intake fields, never trainer-private notes, and uses the native share sheet for Mail, Messages, AirDrop, WhatsApp when installed, and other share extensions.
- Added German, Spanish, and French translations for the new surfaces.

## Verification

- Swift Testing contracts cover immediate cross-feature invalidation, purchased-template identity, Contacts mapping, and Intake PDF privacy.
- PDF text extraction proves the private canary is absent.
- The final A4 PDF was rendered to PNG and visually checked for hierarchy, spacing, clipping, and Dark Mode-safe print colors.
- UI smoke opens Sessions first, renames a dog in People, returns to Sessions, and immediately finds only the new name. It also verifies the Completion demo is absent.

Final verification on 2026-08-12:

- Full iPhone 16 / iOS 18.6 suite: 97 tests (103 parameterized invocations), 0 failures.
- Phase 13 live-refresh UI smoke on iPad Pro 11-inch (M4) / iOS 18.6: passed.
- Generic iOS device build: passed and signed as `com.personalagile.dogcoach` by team `32ZWRSU45R` using automatic signing.
