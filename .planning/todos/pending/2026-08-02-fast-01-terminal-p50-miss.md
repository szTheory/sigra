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

## Independent protected remeasurement — 2026-08-03

Protected run [`30849907303`](https://github.com/szTheory/sigra/actions/runs/30849907303) independently measured 13 terminal pull_request runs through `2026-08-03T20:22:31Z`. The attested receipt `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-REMEASUREMENT.json` records queue-inclusive wall p50 **724 seconds**. Because FAST-01 requires p50 strictly below 720 seconds, this is a second durable miss; it preserves, rather than replaces, the historical 19-run/772-second miss above.
