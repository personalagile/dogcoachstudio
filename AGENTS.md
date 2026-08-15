# DogCoach Studio agent instructions

## Persisted customer data

For every change to SwiftData models or schemas, persistent fields or enums, relationships, delete or uniqueness rules, backup formats, restore mappings, or media manifests, use the repository skill at `.agents/skills/dogcoach-data-migrations/SKILL.md` before editing implementation files.

Do not modify a released schema in place, silently reset an unreadable store, or ship a migration without a store fixture produced by the previous public app version and the gates defined by that skill.
