# FAST-01 terminal p50 miss — measured 2026-08-02

**Status:** Open residual
**Owner:** CI maintainers
**Follow-up:** Diagnose and reduce the measured binding pole in a separately planned CI-topology change; do not reinterpret the terminal window or mask it with retries/timeouts.

## Measured evidence

The terminal ledger is `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json`. It retained 19 retained pull_request runs and measured a 772 seconds p50; FAST-01 remains unmet because 772 is not strictly less than 720 seconds.

The ledger's binding-pole receipts are reproducible from the recorded commands:

- Run [`30723615281`](https://github.com/szTheory/sigra/actions/runs/30723615281): `bash scripts/ci/ci-run-metrics.sh --jobs 30723615281 --format json` — `Library tests shard`, 682 seconds.
- Run [`30723593560`](https://github.com/szTheory/sigra/actions/runs/30723593560): `bash scripts/ci/ci-run-metrics.sh --jobs 30723593560 --format json` — `Example Playwright shard (admin_checkpoints)`, 1062 seconds.

This residual records a performance miss only. It does not reopen the completed audit, change timeout/retry behavior, or fold unrelated pending work into Phase 235.
