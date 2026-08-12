# Phase 11 – Lifecycle, history, and export

Status: implemented.

## Delivered

- Backup creation now exposes the generated, integrity-checked JSON/CSV package through the native share sheet.
- Exercises and training templates can be opened for editing. Published content creates a new immutable draft version; items can be archived from the list.
- Unevaluated sessions can be deleted while completed business history remains immutable.
- Dog files show completed training sessions with date and recorded default outcome.
- Existing client, dog, contact-role, intake, goal, package, report, and session lifecycle behavior was audited. Destructive business-history operations remain archive- or correction-based by design.

Training labels require a persisted schema change and are included with the package/client migration in Phase 12 so an installed store is never changed without an explicit migration version.
