# Phase253 load recovery budgets — revision 3 (PROPOSED, requires Jon's approval)

Status: planning proposal. Native/GitHub execution during this planning invocation: 0. This document grants NO capacity by itself. Capacity becomes usable only after plan 253-63 Task 1 (`checkpoint:decision`) records Jon's explicit approval in `253-LOAD-RECOVERY-BUDGET-APPROVAL-R3.json`, bound to this file's SHA-256 AND to the SHA-256 of `253-LOAD-RECOVERY-NATIVE-FREEZE-R3.json` (created by 253-62). The R2 approval (`253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, sha256 d5c85aaa...) is bound to the R2 doc and R2 freeze and cannot be reused for the changed spec, runner and library bytes; it expires with its unused infrastructure retry. Every earlier budget document, freeze, approval, evidence file and raw receipt stays byte-for-byte unchanged as spent lineage.

## Why a revision is needed

Plan 253-51 ran the first R2 window (CR2-DESKTOP-MOBILE-FIRST) on a provably awake host and halted terminally (non-infrastructure): 0 of 16 rows accepted, the 105000 ms work deadline hit at row 9, CLI exit null, no report. Offline root cause (`.planning/debug/253-r2-native-controls-all-fail.md`, sha256 6a678230..., commit c3091520b) is an AND-gate:

1. Positive control design defect: the spec fills the form while the LiveView socket is held; the join re-render resets the unfocused required email field, the browser blocks submit, and the success assertion times out (16.7 s, desktop and mobile). Fixed by plan 253-58 (re-fill and value assertion after readiness, before submit). Inferred from code, never observed in a browser; the R3 window records the pre-refill email value as an in-window confirmation at no extra launch.
2. Collision control expects the enumeration-safe flash, but `unsafe_validate_unique` pre-empts the DB constraint and `Sigra.Auth.register/3` leaks `{:error, changeset}` ("has already been taken"). This is a library enumeration-leak security bug, fixed in the library by plan 253-57 toward the documented `{:error, :email_taken}` contract. Plan 253-57 also makes the registration LiveViews (example app, installer template, golden install fixture) actually render the info flash their `:email_taken` branch sets; today none renders `@flash`. The collision expectation itself is unchanged.
3. Budget defect: the 105000 ms work deadline also covered `mix ecto.setup` (24793 ms) and app boot (~1850 ms), leaving ~78.4 s for 16 rows. Plan 253-60 moves setup into a separately bounded, separately charged phase and sizes each window from measured per-test durations (below).
4. Evidence loss: list reporter + onEnd-only JSON + `rmSync(tempRoot)` discarded every per-test error. Plan 253-59 adds an fsync'd per-test JSONL reporter (onTestEnd) and preserves sanitized error-context files before cleanup; every future halt carries per-test error text.

## Carried actuals (immutable, each identity counted once)

| Carried component | ms | Actual CLI processes |
|---|---:|---:|
| R2 carried total (see `253-LOAD-RECOVERY-BUDGETS-R2.md`: 276453 + 655 + 1765488) | 2042596 | 6 |
| R2 preparation (253-51: `mix --version`, `mix deps`) | 743 | 0 |
| CR2-DESKTOP-MOBILE-FIRST, terminal non-infrastructure halt (charged = execution = wall) | 107343 | 1 |
| **Total carried** | **2150682** | **7** |

Spent reservations (eight, never reopened): D19-DIAG-01, R-DIAG-DESKTOP, R-INFRA-RETRY-DESKTOP, R-DIAG-MOBILE, R-DIAG-CONTROL-DARK, CR-DARK-FIRST, CR-DESKTOP-MOBILE-FIRST, CR2-DESKTOP-MOBILE-FIRST. Original retry: used 1 / available 0. R2 infrastructure retry (CR2-INFRA-RETRY): granted 1, used 0, not eligible (non-infrastructure halt) — EXPIRED, never charged. CR-DESKTOP-SECOND, CR-MOBILE-SECOND, CR-DARK-SECOND: never launched, RETIRED unused (their sizes change, so they get new identities below). The R2 preparation remainder (29257 ms) is retired, not carried.

## Measured per-test durations used for sizing

Sources: R2 raw `test-log.log` (CR2-DESKTOP-MOBILE-FIRST), 253-16 `R-DIAG-CONTROL-DARK` test log, 253-15 R-DIAG-MOBILE / R-INFRA-RETRY-DESKTOP test logs, R2 evidence `setup.duration_ms`.

| Row kind (x count in first window) | Observed | Pass-path budget per row | Failure-path budget per row |
|---|---|---:|---:|
| Positive readiness control (x3) | failed 16.7 s = 15000 ms timeout + ~1.7 s (desktop, mobile; dark 16.5 s) | 6000 | 16700 |
| Never-released negative (x3) | 2.0 / 2.6 / 2.3 s | 3000 | 3000 |
| Broken-readiness negative (x3) | 2.1 / 2.3 / 1.8 s | 3000 | 3000 |
| Same-account collision (x3) | failed 20.0 s = 15000 ms timeout + ~5 s | 8000 | 20000 |
| Forced-trace negative (x3) | 3.5 s | 4000 | 4000 |
| Original dark board (x1) | passing 5.5 s desktop / 4.5 s mobile; dark unobserved | 8000 | 8000 |
| CLI start + chromium/webkit launches | ~12.5 s residual in R2 (includes a partial row) | 12500 | 12500 |
| App boot to HTTP 200 | ~1850 ms | 2000 | 2000 |
| **First window work total** | | **94500** | **162600** |

Arithmetic: pass path 3x6000 + 3x3000 + 3x3000 + 3x8000 + 3x4000 + 8000 = 80000; + 12500 + 2000 = 94500. Failure path (all six positive/collision rows time out again) adds 3x10700 + 3x12000 = 68100 → 162600. A 165000 ms work deadline therefore completes the full 16-row report even if both controls fail again (2400 ms margin), so a repeat failure produces a complete report instead of a truncated one.

Second windows (2 rows each): app boot 2000 + bounded prior-collision absence query 2000 + CLI start and one engine 6000 + 2 rows x 8000 + created-account query 2000 = 28000 pass path; failure path +2 x 15000 = 58000 ≤ 60000 work.

Setup (`mix ecto.setup` on a cold build): observed 24793 ms under load average ~14 on 18 cores; separately bounded ceiling 60000 ms (2.4x the observation). Setup is predebited and charged inside its slot but no longer consumes the browser work deadline; a setup overrun halts before any CLI launch.

## Proposed NEW allowance for the remaining native control work

| Component | ms | Max CLI | Justification |
|---|---:|---:|---|
| R3 preparation reservation | 10000 | 0 | R2 preparation measured 743 ms. |
| CR3-DESKTOP-MOBILE-FIRST (maps from spent CR2-DESKTOP-MOBILE-FIRST; same 16-row selection and titles): setup 60000 + work 165000 + cleanup 15000 | 240000 | 1 | Sized above. |
| CR3-DESKTOP-SECOND (maps from retired CR-DESKTOP-SECOND): setup 60000 + work 60000 + cleanup 15000 | 135000 | 1 | Sized above. |
| CR3-MOBILE-SECOND (maps from retired CR-MOBILE-SECOND): same shape | 135000 | 1 | Sized above. |
| CR3-DARK-SECOND (maps from retired CR-DARK-SECOND): same shape | 135000 | 1 | Sized above. |
| CR3-INFRA-RETRY — exactly one infrastructure retry, sized to the largest slot (recommended: yes) | 240000 | 1 | Eligibility unchanged from R2 (below). |
| Explicit headroom | 15000 | 0 | One terminal overrun only (watchdog tick + owned drop floor + absence floor + margin). |
| **New D-19 allowance** | **910000** | **5** | 15.2 minutes. |

Sum: 10000 + 240000 + 3 x 135000 + 240000 + 15000 = 910000.

**Proposed D19-R3 cumulative cap: 2150682 + 910000 = 3060682 ms (51.0 min); D-19 CLI launches max 7 + 5 = 12.** This stays inside D-19's sixty-minute total reproduction ceiling (3600000 ms; 539318 ms would remain unallocated). It exceeds D-19's twenty-minute per-signature figure and ten-invocation figure, as R2 already did, because of the sleep-inflated 253-40 charge and the two lost control windows; that is why explicit approval is required.

Without the retry (`approve-without-retry`): new allowance 670000 ms, D19-R3 cap 2820682 ms, D-19 launches max 11.

## Conditional acceptance and optional checks (unchanged sizes)

| Component | ms | Max CLI |
|---|---:|---:|
| Nine conditional D-20 acceptance windows at 240000 (setup included, only after accepted R3 controls and a source-bound cause/repair) | 2160000 | 9 |
| Three optional relevant ExUnit seed checks (101/202/303) at 60000 | 180000 | 0 |
| **Proposed shared R3 cap (D19-R3 cap + acceptance + optional checks)** | **5400682** | **21** |

Without the retry: shared R3 cap 5160682 ms, physical CLI max 20. No slack is added beyond the 15000 ms headroom row.

## Infrastructure retry eligibility (CR3-INFRA-RETRY)

Unchanged from R2: eligible only when the halted attempt's receipt records runner-detected suspension (`suspended: true`), loss of the caffeinate assertion holder, or a host-level failure before Playwright selected any test; a separate written diagnostic cites independent host evidence (`pmset -g log` excerpt or process table); and the retry is unused. Not eligible: any assertion result, Playwright timeout without suspension, missing/extra rows caused by test behavior, expected-failure mismatch, or an overrun without suspension. The retry re-runs the halted slot's exact frozen selection once; the original stays preserved and charged. A second infrastructure halt is terminal.

## Halt diagnostics (new, every native window)

Every attempt that launches the CLI must leave, in its raw receipts, the sanitized per-test JSONL (one line per finished test: project, title, status, expected status, duration, error message/location) and every sanitized `error-context.md`, whether it passes, fails or is killed at the deadline. The R3 verifier rejects an attempt receipt without them. The positive control additionally annotates whether the email field was empty after readiness and before the re-fill, confirming or falsifying cause 1 in-window at no extra launch.

## Host-sleep safety (every native window)

Unchanged from R2: AC power, the runner-owned `caffeinate -i -s -m -w <runner pid>` holder running, and `pmset -g assertions` listing that holder with PreventSystemSleep and PreventUserIdleSystemSleep before any predebit; failure stops at zero charge; a suspension halts and is charged at max(monotonic, wall).

## Decision options presented at 253-63 Task 1

- `approve` — caps above, with exactly one infrastructure retry.
- `approve-without-retry` — caps above minus the retry row.
- `reject` — no native launch; CIREL-01 stays open; the phase halts honestly at 253-63.

Any other change to these numbers requires a new planning round, not an in-flight edit.

## Hosted and PR allocations (unchanged)

Unchanged from `253-LOAD-RECOVERY-BUDGETS.md` and R2: canary 117 new measured requests + 3 known historical command allocations, 45 jobs, 60 minutes; production PR allocation exactly 120 requests, 60 minutes; both reserved reruns frozen EXPIRED in 253-65. Each outward GitHub action stays gated by Jon's approval of the enumerated pre-clock action manifest in 253-66 (canary: scoped ref creations, six dispatches, one cancellation, one verifier dispatch) and 253-67 (docs object publication plus exactly two draft PRs, no merge, no push of main) — the same scope Jon already approved for 253-54/253-55, re-confirmed at those checkpoints.

## Plan map for this round

| Plan | Wave | Depends on | Role |
|---|---:|---|---|
| 253-57 | 1 | — | Jon D-04 checkpoint (library + generator output), then library enumeration fix (`unsafe_unique` → `{:error, :email_taken}`, TDD), registration LiveViews render flash (example, installer template, golden fixture), CHANGELOG security entry |
| 253-58 | 1 | — | Spec control repair: positive re-fill/assert after readiness; collision expectation unchanged; offline pins |
| 253-59 | 1 | — | Per-test failure JSONL reporter, error-context preservation helper, R3 diagnostics verifier |
| 253-61 | 1 | 253-50 | R3 reconciliation contract (`--revision r3`) covering PLANs 01-68 |
| 253-60 | 2 | 253-59 | R3 runner revision: carried 2150682/7/8, setup phase outside work deadline, R3 slot table/caps, approval binding, diagnostics mandatory |
| 253-62 | 3 | 253-57, 253-58, 253-60 | Offline gate on final product source, then create/check/commit the R3 native freeze |
| 253-63 | 4 | 253-62 | Jon budget decision, then 22-row native run under the R3 freeze (replaces halted 253-51) |
| 253-64 | 5 | 253-63 | Cause assessment and conditional acceptance (replaces never-run 253-52) |
| 253-65 | 6 | 253-64, 253-49 | Canary adapter, live publication origin, final source freeze (replaces never-run 253-53) |
| 253-66 | 7 | 253-65 | Jon outward-action gate, then hosted canary (replaces never-run 253-54) |
| 253-67 | 8 | 253-66 | Jon outward-action gate, then normal and docs-only draft PRs (replaces never-run 253-55) |
| 253-68 | 9 | 253-67, 253-61 | Completion record and accepted-only R3 disposition bundle (replaces never-run 253-56) |

No allocation is spent by writing this document.
