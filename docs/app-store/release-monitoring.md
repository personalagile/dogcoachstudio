# Version 1 release and monitoring plan

## Release

- Prefer a manual release after review; consider Apple's seven-day phased release once the first production smoke passes.
- Stop rollout for data loss, private-data exposure, duplicate redemption, broken export, or launch failure.
- Keep the previous build metadata, schema-v1 migration evidence, and support response ready.

## Support process

- Publish one support URL and monitored email before submission.
- Request the privacy-safe diagnostics file first; never request a full backup over ordinary email.
- Triage P0/P1 with the definitions in the Phase-6 pilot plan.
- Document reproducibility, device/OS, data impact, workaround, owner, and resolution.

## 30-day review

Review crash-free sessions, activation, three-session repetition, completion time, report sharing, purchase conversion, renewal/refund signals, support volume, and every privacy/ledger incident. Compare against the success and kill criteria in `PLAN.md`; distinguish App Store Connect evidence, opt-in survey evidence, and interview evidence.

No production result is pre-filled. The operator records actual values on days 7, 14, and 30 and writes a Go/Pivot/Stop decision memo.
