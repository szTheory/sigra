# Phase 204: Terminal Ratification - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-26
**Phase:** 204-terminal-ratification
**Mode:** assumptions
**Areas analyzed:** Baseline Recapture Scope & Sequencing; `.vt-status-pill` Contrast Fix + Canary Rebase; WR-01/WR-02 Test Hardening; Clean `mix test`; Adversarial Review + Tier-2 Lock + Housekeeping

## Assumptions Presented

### Baseline Recapture Scope & Sequencing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Only audit-mobile checkpoints (+ incidental canary) need recapture; all else proven via compare-mode zero-drift, not force-recapture; fix-contrast → recapture-mobile → restore incidental → zero-drift → monotonic guard | Confident | `snapshot-recapture-gate.sh:64-95`; allowlists confirmed empty; Phase 192 terminal block in `guides/reference/admin-quality-ledger.md`; audit-mobile-recapture todo steps 1-3 |

### `.vt-status-pill` Contrast Fix + Canary Rebase
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Raise `--vt-color-ink` proportion in base `.vt-status-pill` AND `--ok` variant to ≥4.5:1 light+dark, verified by axe gate; precise edit (corruption hazard); fix + canary PNG + audit PNGs in same commit | Likely | `app.css:1089-1112`; `org_switcher.ex:34,45`; `admin-checkpoints.spec.ts:289-296`; `snapshot-canary-guard.sh:104` (canary non-allowlistable); corruption-cleanup todo |

### WR-01 / WR-02 Test Hardening
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fold both into 204: deterministic per-user audit pagination boundary ExUnit test (WR-02) + structural default-collapsed `<details>` assertion (WR-01); lock existing intent, no product change | Confident | `2026-06-26-per-user-audit-pagination-test-coverage.md` (re-tagged to 204); `admin_audit_user_live_test.exs` has zero pagination coverage; `admin-quality-ledger.md:91` already cites the test as Tier-2 evidence |

### Clean `mix test` for the Terminal Gate
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Fix the two stale known-failure contract tests (Phase192 quarantine marker gone; Phase148 Vaultr→Tasklane); accept 3 UpgradeIntegrationTest env-DB failures (exclude, don't fix) | Confident | `2026-06-26-stale-known-failure-contract-tests.md` (proven pre-existing); MEMORY `reference_v139_known_pretest_failures`; demo rename established |

### Adversarial Review, Tier-2 Lock & Housekeeping
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Adversarial review via `gsd-audit-milestone` → `v1.41-MILESTONE-AUDIT.md` against 4 RATIFY-02 criteria; "Tier-2 locked" = verify monotonic-guard lock, no new ratchets; tick Phase 201, flip RATIFY-01/02, prove parity (phx_new 1.8.7 golden + acceptance smoke RUN_PARITY=1) | Likely | `gsd-audit-milestone` skill + `v1.40-MILESTONE-AUDIT.md`; `admin-quality-ledger.md:85-92,115`; `201-VERIFICATION.md` passed but `ROADMAP.md:26` unticked; CLAUDE.md SEED-004 phx 1.8.7 pin; `snapshot-recapture-gate.sh:100-105` RUN_PARITY |

## Corrections Made

No corrections — all five assumptions confirmed via "Yes, proceed".

## External Research

None performed — ratification mechanics fully prescribed by gate scripts, the Phase 192
precedent, the three pending phase-204 todos, and the existing `gsd-audit-milestone` skill.
All open decisions resolved against in-repo evidence.
