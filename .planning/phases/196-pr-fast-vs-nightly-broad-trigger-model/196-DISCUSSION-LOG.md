# Phase 196: PR-Fast vs Nightly-Broad Trigger Model - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-20
**Phase:** 196-pr-fast-vs-nightly-broad-trigger-model
**Mode:** assumptions
**Areas analyzed:** Trigger topology, Job-move inventory, Never-strand guarantee, ci-gate
aggregation under skips, Required-check stability + doc reconciliation, Forced-failure probe,
Phase51 ci-contract todo fold

## Assumptions Presented

### Trigger topology
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One `ci.yml` + new `schedule:` cron; gate broad jobs with job-level `if: github.event_name != 'pull_request'` | Confident | `playwright-github-pages.yml:16-18` cron precedent; ruleset 14941512 (broad jobs non-required); avoiding 2nd check namespace per CRIT-03 |
| Gate on `!= 'pull_request'` (run schedule+main+dispatch), not `== 'schedule'` | Confident | CRIT-02 "schedule:/main"; release-evidence dispatch path `ci.yml:28-42` |
| Job-level `if:` for whole-job removal, not step-level gating | Confident | step-level idiom `ci.yml:60-83,120-134` is for keep-reporting required jobs |

### Job-move inventory
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Move install_matrix, upgrade_smoke, passkeys_manual_fallback_smoke, passkeys_opt_out_smoke, generated_admin_playwright_smoke | Likely | `ci.yml:604,502,554,733,1156` — all exhaustive/low-probability or release-boundary |
| Keep install_golden_contract + library_tests_dep_off on PR | Likely | `ci.yml:102,298` — byte-exact golden + compile-without-Threadline correctness guards |

### Never-strand guarantee
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Each moved job proxied on PR; generated_admin parity is the residual gap | Likely | install_smoke proxies matrix default leg (`install-smoke.sh:61`); passkey happy-path in `ci.yml:1047-1053`; generated-host parity backstopped by DIST-06 acceptance-smoke |

### ci-gate aggregation under skips
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Treat `skipped` as pass in `ci-gate` loop (fail only on failure/cancelled) | Confident | GitHub: skipped `needs` → result `skipped`; `ci-gate` already `if: always()` (`ci.yml:1289`); current loop `ci.yml:1317` would red on skip |
| Only upgrade_smoke + generated_admin are both moved & in ci-gate.needs | Confident | `ci.yml:1279-1288,1284,1287` |

### Required-check stability + reconciliation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 5 ruleset lane names stay byte-identical & unconditional on PR; re-read ruleset at execution | Confident | 194-CONTEXT D-01/D-03; ruleset 14941512 |
| Reconcile stale "ci-gate is the required check" premise in docs | Confident | 194-CONTEXT D-15 |

### Forced-failure probe
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `workflow_dispatch` input `force_fail_probe` → `exit 1` in a nightly-gated job; documented one-liner | Likely | reuses `workflow_dispatch` `ci.yml:6`; tests nightly failure-propagation without cron wait |

### Phase51 ci-contract todo
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| FOLD: re-anchor phase_51 test from `installer_milestone_audit:` job to `fast_checks` step; re-verify phase_58 slicer | Confident | todo `2026-06-20-phase51-...md`; test red on main; phase_58 slices on `library_tests:` boundary (`phase_58_..._test.exs:28-30`) |

## Corrections Made

No blanket corrections. One user decision on the single genuine fork:

### Never-strand guarantee — generated_admin_playwright_smoke gating
- **Assumption presented:** Full move to nightly with documented residual gap (vs. thin PR slice
  vs. keep fully on PR).
- **User decision:** **Full move + documented residual** — move entirely to nightly/main;
  generated-host template parity is nightly-caught, backstopped by DIST-06 acceptance-smoke;
  residual recorded in CONTEXT + MAINTAINING. (Largest single PR wall-clock win.)
- **Reason:** Accepted the residual given the DIST-06 backstop and the example_playwright_smoke
  admin-spec proxy on PR.

All other assumptions (①, ②–⑦) confirmed: "Proceed — lock all as-is."

## External Research

None performed — GitHub Actions skip/`needs`/`event_name` semantics confident from in-repo
precedent (`playwright-github-pages.yml`, existing `event_name` gating in `ci.yml`) and documented
behavior. Only execution-time confirmation required is re-reading ruleset 14941512 (standing
194-D03 mandate), which is verification, not research.
