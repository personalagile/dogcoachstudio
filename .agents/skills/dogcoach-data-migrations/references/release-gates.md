# Migration release gates

## Evidence package

- Previous public version, build number, Git tag, schema version, and backup version
- Sanitized native store produced by that exact build
- Portable backup and media tree produced by that exact build
- Fixture inventory with entity counts, stable IDs, relationships, ledger sums, private canaries, and media hashes
- Written classification for every schema delta

## Automated gates

- Previous store opens and migrates with the new app
- Migration is idempotent across subsequent launches
- Migrated store survives a fresh-container restart
- All fixture IDs and required relationships are preserved
- Completed sessions, snapshots, reports, and ledger history are unchanged unless the ticket explicitly transforms them
- Package balances still equal the sum of ledger entries
- Private fields remain out of diagnostics and client-facing reports
- Old and new supported backup formats decode as documented
- Post-migration backup restores into an empty store with identical semantic data and media hashes
- Corrupt, truncated, unsupported, and path-traversing input fails closed without modifying the destination
- Full unit, UI, iPhone, iPad, and signed-device checks pass

## Manual gates

- Upgrade a copy of real-world-sized sanitized data on the oldest supported OS and a current OS
- Measure migration duration and temporary disk use
- Exercise low-storage and forced-termination recovery on disposable fixtures
- Verify the app never presents an empty workspace after migration failure
- Verify the support recovery procedure from the preserved pre-migration copy

## Release controls

- Roll out through internal testing, external TestFlight, then phased App Store release
- Monitor launch failures and migration-specific privacy-safe diagnostic codes by build
- Pause rollout on any unexplained data-count, relationship, ledger, or media mismatch
- Never solve a migration incident by instructing customers to delete and reinstall before a recoverable export exists
