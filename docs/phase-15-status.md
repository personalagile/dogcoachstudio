# Phase 15 status — Exercise guidance and media

Status: implemented and verified on 2026-08-13.

## Delivered

- Exercise editing covers setup, ordered training steps, explicit success criteria, paired problems and corrective measures, regression, progression, homework, and safety notes.
- Photos and videos can be selected from the system photo picker, viewed, and deleted from an existing exercise.
- Exercise media is stored as protected local files in Application Support with a small JSON manifest. Images are downsampled to a maximum edge of 2,048 pixels and normalized as JPEG; videos are copied rather than loaded permanently into memory.
- Media remains linked to the stable exercise ID when a published exercise creates a new draft version.
- Problem/measure pairs are backward compatible with existing SwiftData records and are exported as separate allowlisted backup fields.
- The approved Foundation content pack is upgraded to 1.1.0 / exercise and template version 2. Every listed problem now has a concrete corrective measure in German and English; existing success criteria remain intact.
- All new interface copy is translated in German, Spanish, and French.

## Privacy and storage boundary

- The photo picker provides user-selected access and does not request broad Photo Library access for exercise media.
- Media stays on the device and is not included in reports or client-facing text automatically.
- SwiftData stores no large image/video blobs, avoiding database bloat and a schema migration for binary media.

## Verification

- Phase 15 Swift Testing coverage: content roundtrip, legacy compatibility, media persistence/deletion, and Foundation pack completeness.
- Full iPhone simulator suite and signed device build are required before the phase commit is pushed.
