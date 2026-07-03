# Phase 211: Terminal Ratification - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-01
**Phase:** 211-terminal-ratification
**Mode:** assumptions
**Areas analyzed:** Scope (zero flips), Canary/snapshot reconciliation, Terminal idempotency,
Generated-host parity, mix test cleanliness, Adversarial milestone audit, Milestone-close
housekeeping, Branch/integration model

## Assumptions Presented

### Scope — zero flips
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 210 flipped every ledger cell to bare `2`; 211 verifies + locks, no flips | Confident | `admin-quality-ledger.md` all-`2` (live grep); `quality-ledger-monotonic.sh --base origin/main` exits 0 (36 cells, live run); 204 D-11 |

### Generated-host parity (GATE-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-run existing `admin-acceptance-smoke.sh` + install-golden byte-diff (phx_new 1.8.7 pin); no new harness | Confident | `scripts/ci/admin-acceptance-smoke.sh` (PORT=4017, admin-generated.spec.ts); 204 D-12; CLAUDE.md SEED-004 |

### mix test cleanliness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 3 UpgradeIntegrationTest env-DB failures + NoopTest shard flake accepted as known (not fixed); confirm no new regression | Likely | `test/upgrade_test.exs:212`; `noop_test.exs` async log-capture; 204 D-09; todo addendum; memory reference_v139_known_pretest_failures |

### Adversarial milestone audit (GATE-02 SC-4)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Produce `v1.42-MILESTONE-AUDIT.md` via gsd-audit-milestone; cite committed persona verdicts, don't re-run | Confident | `v1.41-/v1.40-MILESTONE-AUDIT.md` templates; `v1.42-PERSONA-JTBD-PANEL.md` + 8 per-surface docs; 204 D-10 |
| Panel `Status: PRE-FIX` header (line 6) is stale — remediations landed after; update to POST-FIX | Confident | git: panel `99e61a45` predates 209-03..209-05 remediations |

### Milestone-close housekeeping
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mark Phase 208 complete (208-03 folded into 210-02); flip GATE-01/02; fix STATE milestone_name; flip ROADMAP status | Confident | ROADMAP:205/230; REQUIREMENTS:44-45/86-87; STATE stale name vs PROJECT/ROADMAP/REQUIREMENTS ADMIN-DS-ELEVATION; 204 D-13 |

### Branch/integration model + canary reconciliation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| v1.42 on local `main` (366 ahead of origin/main), integrates via PR #63; canary FAIL vs origin/main is the terminal reconciliation | Likely | `snapshot-canary-guard --base origin/main` FAIL (live run); ci.yml:70-74 base calc; todo 2026-06-30; guard line 104 |

## Corrections Made

### Canary / snapshot reconciliation (the one high-impact open decision)
- **Original assumption (Likely):** Canary reconciliation is an integration-merge concern; the
  mechanism was ambiguous between 204's fully-automated `snapshot-recapture-gate.sh` (no human
  review) and ci.yml:1852's human-visual-PNG-review recapture PR.
- **User decision:** **Automated re-baseline into `main` (no human review)** — drive the canary
  re-baseline (preserving the 204-03 WCAG fix) + the 4 checkpoint recaptures through the automated
  `snapshot-recapture-gate.sh` (all-green == approval). Reject the human-visual-review path; reject
  reverting the canary. → CONTEXT D-02.
- **Reason:** Matches the zero-human-UAT default and Phase 204's D-01/D-02 mechanism. The exact
  green-vs-origin/main plumbing (direct recapture PR vs idempotency-vs-HEAD + publish-time
  reconciliation) is left as an open research question (D-02a); only the policy is ratified.

All other assumptions confirmed as-is (locked by the Phase 204 precedent + live ground-truth runs).

## External Research

None performed — every question was answerable from in-repo artifacts (scripts, ci.yml, ledger,
panel docs, todos, ROADMAP/REQUIREMENTS/STATE/PROJECT). Pure internal verification +
policy-adjudication phase.
