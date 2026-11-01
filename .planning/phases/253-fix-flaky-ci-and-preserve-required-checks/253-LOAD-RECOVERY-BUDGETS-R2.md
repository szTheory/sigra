# Phase253 load recovery budgets — revision 2 (PROPOSED, requires Jon's approval)

Status: planning proposal. Native/GitHub execution during this planning invocation: 0. This document grants NO capacity by itself. Capacity becomes usable only after plan 253-51 Task 1 (`checkpoint:decision`) records Jon's explicit approval in `253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, bound to this file's SHA-256. The original `253-LOAD-RECOVERY-BUDGETS.md`, the halted 253-40 evidence, its raw receipts and every preserved revision ref stay byte-for-byte unchanged as spent lineage.

## Why a revision is needed

Plan 253-40 halted honestly. Its first frozen 120000 ms window (CR-DESKTOP-MOBILE-FIRST) ran one real Playwright CLI while the macOS host entered Maintenance Sleep three times (pmset: 744 s, 923 s, 753 s). `runLoggedTree` relied on one relative timer that never fired during the run; the operator sent SIGTERM after about 29 minutes. Root cause and fix: `.planning/debug/resolved/253-native-deadline-not-enforced.md`, commits `cf578a567` (fix) and `a26642e55` (docs). The fix (dual-clock watchdog, caffeinate hold, suspension halt, bounded drop floor) is proven offline only (ci-registration-recovery.test.mjs 67/67, ci-playwright-load.test.mjs 14/14, Node 20.18.1). The old D-19 cap (1200000 ms) is exceeded, so no native command can run under the old freeze.

## Carried actuals (immutable, each identity counted once)

| Carried component | ms | Actual CLI processes |
|---|---:|---:|
| Ledger carried into 253-39 (eight components, see original BUDGETS) | 276453 | 5 |
| 253-40 preparation probes (mix --version, mix deps) | 655 | 0 |
| 253-40 CR-DESKTOP-MOBILE-FIRST, halted by host sleep (charged, non-retryable infrastructure halt) | 1765488 | 1 |
| **Total carried** | **2042596** | **6** |

Spent reservations (seven, never reopened): D19-DIAG-01, R-DIAG-DESKTOP, R-INFRA-RETRY-DESKTOP, R-DIAG-MOBILE, R-DIAG-CONTROL-DARK, CR-DARK-FIRST, CR-DESKTOP-MOBILE-FIRST. Original retry: used 1 / available 0. Preparation used 3743 + 655 = 4398 ms. The old preparation remainder (111834 ms) is retired, not carried.

## Proposed NEW allowance for the remaining native control work

| Component | ms | Max CLI | Justification |
|---|---:|---:|---|
| R2 preparation reservation (replaces the retired 111834 ms remainder) | 30000 | 0 | 253-40 preparation measured 655 ms; 30000 ms is a bounded ceiling, not a target. |
| CR2-DESKTOP-MOBILE-FIRST (new identity; maps from spent CR-DESKTOP-MOBILE-FIRST; same 16-row selection) | 120000 | 1 | Same frozen window as before; no growth. |
| CR-DESKTOP-SECOND (unused, unchanged) | 120000 | 1 | Unchanged. |
| CR-MOBILE-SECOND (unused, unchanged) | 120000 | 1 | Unchanged. |
| CR-DARK-SECOND (unused, unchanged) | 120000 | 1 | Unchanged. |
| CR2-INFRA-RETRY — exactly one re-granted infrastructure retry (recommended: yes) | 120000 | 1 | The 253-40 halt was a host-sleep infrastructure fault, not a test result. One retry covers one further independently diagnosed host fault; eligibility below. |
| Explicit headroom | 15000 | 0 | Covers one terminal overrun only: watchdog tick (<=250 ms) + owned drop floor (5000 ms) + absence-query floor (5000 ms) + 4750 ms margin. Any charge beyond the cap is still recorded truthfully and halts. |
| **New D-19 allowance** | **645000** | **5** | 10.75 minutes. |

**Proposed D19-R2 cumulative cap: 2042596 + 645000 = 2687596 ms (44.8 min); D-19 CLI launches max 6 + 5 = 11.** This exceeds D-19's 20-minute per-signature figure (entirely because of the sleep-inflated 253-40 charge) but stays inside D-19's sixty-minute total reproduction ceiling (3600000 ms).

Without the retry (decision option `approve-without-retry`): new allowance 525000 ms, D19-R2 cap 2567596 ms, D-19 launches max 10.

## Conditional acceptance and optional checks (unchanged sizes)

| Component | ms | Max CLI |
|---|---:|---:|
| Nine conditional D-20 acceptance windows at 240000 (only after accepted controls and source-bound cause/repair) | 2160000 | 9 |
| Three optional relevant ExUnit seed checks (101/202/303) at 60000 | 180000 | 0 |
| **Proposed shared R2 cap (D19-R2 cap + acceptance + optional checks)** | **5027596** | **20** |

Without the retry: shared R2 cap 4907596 ms, physical CLI max 19. No slack is added beyond the 15000 ms headroom row.

## Infrastructure retry eligibility (CR2-INFRA-RETRY)

Eligible only when ALL hold: the halted attempt's receipt records runner-detected suspension (`suspended: true`), loss of the caffeinate assertion holder, or a host-level failure before Playwright selected any test; a separate written diagnostic cites independent host evidence (`pmset -g log` excerpt or process table) for that attempt; and the retry has not been used. Not eligible: any assertion result, Playwright test timeout without suspension, missing or extra rows caused by test behavior, expected-failure mismatch, or an overrun without suspension. The retry re-runs the halted slot's exact frozen selection once under the new identity; the halted original is preserved and stays charged. A second infrastructure halt is terminal.

## Host-sleep safety (every native window)

Before any predebit: AC power (`pmset -g batt` reports AC Power, because `caffeinate -s` only applies on AC), the runner-owned `caffeinate -i -s -m -w <runner pid>` holder running, and `pmset -g assertions` listing that holder PID with PreventSystemSleep and PreventUserIdleSystemSleep. Any failed check stops before the predebit at zero charge. The attempt receipt retains the assertion snapshot hash. A suspension detected during the window halts the run and is charged at max(monotonic, wall).

## Decision options presented at 253-51 Task 1

- `approve` — caps above, with exactly one infrastructure retry.
- `approve-without-retry` — caps above minus the retry row.
- `reject` — no native launch; CIREL-01 stays open; phase halts honestly at 253-51.

Any other change to these numbers requires a new planning round, not an in-flight edit.

## Hosted and PR allocations (unchanged)

The canary allocation (117 new measured requests + 3 known historical command allocations, 45 jobs, 60 minutes) and the production PR allocation (exactly 120 requests, 60 minutes) keep their sizes from `253-LOAD-RECOVERY-BUDGETS.md`. Their reserved reruns (canary 13 requests/six jobs; PR 21 requests) are frozen as EXPIRED in 253-53, because no rerun route is implemented (253-42 summary); D-22/D-23 allow at most one, so zero is compliant, and a hosted infrastructure fault halts honestly instead. This shrinks, never grows, what can be spent. Each outward GitHub action is additionally gated by Jon's approval of an enumerated, pre-clock action manifest (plans 253-54 and 253-55), taken before the 60-minute clock starts so the wait cannot consume the window.

## Plan map for this round

| Plan | Wave | Depends on | Role |
|---|---:|---|---|
| 253-48 | 4 | 253-39 | R2 runner revision: carried ledger, new identities, approval record, host-sleep preflight, terminal-evidence verification; commit the R2 freeze |
| 253-49 | 1 | — | Fix pre-existing `ci-gate-canary-recovery.test.py` failures (BSD mktemp, refusal order) |
| 253-50 | 2 | 253-43 | R2 reconciliation contract: re-point 253-40/41/44-47 responsibilities to 51-56 |
| 253-51 | 5 | 253-48 | Jon budget decision, then 22-row native rerun under the R2 freeze (replaces 253-40) |
| 253-52 | 6 | 253-51 | Cause assessment and conditional acceptance (replaces 253-41) |
| 253-53 | 7 | 253-52, 253-49 | Canary adapter, live publication origin, final source freeze (replaces 253-44; zero GitHub requests) |
| 253-54 | 8 | 253-53 | Jon outward-action gate, then hosted canary (replaces 253-45) |
| 253-55 | 9 | 253-54 | Jon outward-action gate, then normal and docs-only draft PRs (replaces 253-46) |
| 253-56 | 10 | 253-55, 253-50 | Completion record and accepted-only R2 disposition bundle (replaces 253-47) |

No allocation is spent by writing this document.
