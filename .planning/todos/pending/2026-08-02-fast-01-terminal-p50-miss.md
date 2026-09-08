# FAST-01 terminal p50 miss — measured 2026-08-02

**Status:** Closed 2026-09-08 by fresh protected evidence
**Owner:** CI maintainers
**Follow-up:** None for FAST-01. Preserve all historical misses and the measured remediation record.

## Measured evidence

The terminal ledger is `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json`. It retained 19 retained pull_request runs and measured a 772 seconds p50; FAST-01 remains unmet because 772 is not strictly less than 720 seconds.

The ledger's binding-pole receipts are reproducible from the recorded commands:

- Run [`30723615281`](https://github.com/szTheory/sigra/actions/runs/30723615281): `bash scripts/ci/ci-run-metrics.sh --jobs 30723615281 --format json` — `Library tests shard`, 682 seconds.
- Run [`30723593560`](https://github.com/szTheory/sigra/actions/runs/30723593560): `bash scripts/ci/ci-run-metrics.sh --jobs 30723593560 --format json` — `Example Playwright shard (admin_checkpoints)`, 1062 seconds.

This residual records a performance miss only. It does not reopen the completed audit, change timeout/retry behavior, or fold unrelated pending work into Phase 235.

## Closure — 2026-09-08

The first follow-up population remained an honest miss: 13 protected PR runs had
a p50 of 724 seconds. That receipt remains immutable at
`235-FAST-01-REMEASUREMENT.json`.

The subsequent measured remediation targeted the actual Library pole. Protected
run `30854850199` reduced the Library tests shard from the protected median of
692 seconds to 148 seconds and reduced total run wall time from 724 seconds to
470 seconds. This was an input to a new measurement, not verdict authority.

FAST-01 is now Closed from one fresh, independently authenticated protected-main
population:

- Remediation cutoff: `54c33e904155a454255952666711c882afdd06e4`
- Cutoff time: `2026-08-03T21:37:08Z`
- Protected endpoint: `2026-09-08T20:05:35Z`
- Population: n=43 unique terminal PR runs, disjoint from both earlier populations
- Independently recomputed result: p50=466 seconds, a strict pass below 720
- Producer: [`34272746647`](https://github.com/szTheory/sigra/actions/runs/34272746647)
- Subject: `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json`
- Attestation: `235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl`

The offline verifier binds the exact subject digest, protected-main signer and
ref, workflow SHA, cutoff, and endpoint under network denial. This closure does
not erase the 19-run/772-second terminal miss or the 13-run/724-second follow-up
miss, and it does not alter the independently completed GATE-05 proof.
