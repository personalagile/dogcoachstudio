# ADR 0001: Phase-0-PoC boundaries

- Status: Accepted for the proof of concept
- Date: 2026-08-10

## Context

Phase 0 must validate whether a trainer can finish a representative group session quickly and understand every resulting change. It must not prematurely validate the production persistence architecture.

## Decision

The PoC is a native SwiftUI iPhone/iPad application targeting iOS 18 with an in-memory, deterministic demo scenario. A small domain service materializes attendance-dependent exercise results, simulated package redemptions, and client-facing report drafts. Completion is guarded by both a completion token and a session identifier.

Published exercise values are copied into result snapshots. Report composition accepts only explicitly client-facing data. No private note is part of its input type.

The UI uses one linear completion flow optimized for the 8-booking, 6-attendee, 5-exercise scenario. It is not the final application navigation.

## Explicit exclusions

- SwiftData, migrations, repositories, and production transactions
- CloudKit, StoreKit, EventKit, PDF export, accounts, or a backend
- Production catalog and localization pipelines
- Professional dog-training content; all content is visibly marked as demo placeholder text
- Claims that an in-memory test proves persistence or crash-recovery safety

## Consequences

The PoC can validate workflow comprehension, timing, idempotent request semantics, and privacy boundaries cheaply. Phase 1 still requires a separate persistence design and migration strategy. Phase 0 cannot pass until the real interview and moderated usability gates in `PLAN.md` have been completed.

