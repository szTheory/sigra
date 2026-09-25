# Phase 233: Library Suite Economics - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-31
**Phase:** 233-library-suite-economics
**Mode:** assumptions
**Areas analyzed:** Parallelism and Slow-Test Evidence, Shard Balance, Subprocess Test Placement,
PR Coverage and Gate Contracts

## Assumptions Presented

### Parallelism and Slow-Test Evidence

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Restore within-shard ExUnit parallelism by removing `--slowest`, while preserving slow-test reporting through a non-serial timing artifact. | Confident | `.github/workflows/ci.yml`; `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` |

### Shard Balance

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Retain two shards and rebalance by measured test cost, not file-count round-robin, after heavy-test extraction. | Likely | `.github/workflows/ci.yml`; `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`; canonical SEED-005 audit |

### Subprocess Test Placement

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use a unified `:scaffold` class and route it to a dedicated, unconditionally PR-triggered receiving lane; do not rely on path-gated `install_golden_contract` alone. | Confident | Canonical SEED-005 audit; `test/support/install_fixture.ex`; golden/idempotency tests; `.github/workflows/ci.yml` |

### PR Coverage and Gate Contracts

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Observe `upgrade_test` and golden/idempotency execution on a real PR while preserving the required `Library tests` context and honest-skip accounting. | Confident | `.planning/ROADMAP.md`; Phase 230/231 context; `.github/workflows/ci.yml`; `MAINTAINING.md` |

## Corrections Made

No corrections — all assumptions confirmed.

## Todo Review

The automated matcher returned 29 predominantly keyword-only candidates. The user selected
“Fold none”; no todo expanded the fixed TEST-01/02/03 phase boundary.

## Methodology Applied

- **Decisive Defaulting:** selected repo-consistent implementation defaults rather than reopening
  internal topology choices.
- **Escalation Threshold:** no assumption changed a security, public, semver, or generated-host
  contract; the proof-truth boundary was preserved and made explicit.
- **Research Depth Calibration:** grounded assumptions in ROADMAP, REQUIREMENTS, prior contexts,
  the canonical audit, CI topology, test fixtures, and observed duration evidence.
- **Phase Context Expectation:** locked the chosen defaults and hard-fail boundaries while leaving
  formatter and deterministic balancing mechanics to research/planning.
