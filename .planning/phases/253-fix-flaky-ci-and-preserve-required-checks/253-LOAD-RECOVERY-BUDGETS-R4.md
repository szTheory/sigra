# Phase253 load recovery budgets — revision 4 (PROPOSED, requires Jon's approval)

Status: planning proposal. No native or GitHub work ran while this document was written. The document grants NO capacity by itself.

Capacity becomes usable only after plan 253-73 Task 1 (`checkpoint:decision`) records Jon's explicit decision in `253-LOAD-RECOVERY-BUDGET-APPROVAL-R4.json`. That record is bound to this file's SHA-256 and to the SHA-256 of `253-LOAD-RECOVERY-NATIVE-FREEZE-R4.json` (created by 253-72).

The R3 approval (`253-LOAD-RECOVERY-BUDGET-APPROVAL-R3.json`, sha256 724e4472...) is bound to the R3 doc and R3 freeze. It cannot be reused for the changed runner bytes, and it expires with its unused infrastructure retry. Every earlier budget document, freeze, approval, evidence file and raw receipt stays byte-for-byte unchanged as spent lineage.

## Why a revision is needed

Plan 253-63 ran the first R3 window (CR3-DESKTOP-MOBILE-FIRST) on a provably awake host. All 16 frozen rows behaved as designed:

- the repaired positive control and the collision control passed in admin-eval, admin-eval-mobile and admin-eval-dark;
- the dark board passed;
- the deliberate negatives failed with their frozen markers;
- `email_value_after_ready_was_empty` was `true` in all three projects.

The runner still rejected the window (exit 3, stop reason "two selected rows reused the same browser-context identity").

Root cause, verified offline against the preserved report (`.raw/CR3-DESKTOP-MOBILE-FIRST/attempt-01/playwright-report.json`, sha256 ef736751...):

- Playwright 1.59's JSON report mirrors every annotation into both `test.annotations` and `results[].annotations`.
- `controlAnnotations` concatenates both lists, so every row's `sigra-registration-control-context` id appears twice.
- The cross-row uniqueness check in the shared `verifyNativeLoadAttempt` (used by the v1, R2 and R3 paths) then fails.
- The report holds 18 distinct context ids. The three collision rows legitimately carry two distinct contexts each.

This is a runner validator defect, not a test, product or host fault. Plan 253-69 fixes it in an R4-only verifier mode. Per-row context ids become the deduplicated union of both annotation levels, and any id shared by two different rows still fails. Plan 253-70 completes the R4 runner revision.

## Carried actuals (immutable, each identity counted once)

| Carried component | ms | Actual CLI processes |
|---|---:|---:|
| R3 carried total (see `253-LOAD-RECOVERY-BUDGETS-R3.md`: 2042596 + 743 + 107343) | 2150682 | 7 |
| R3 preparation (253-63: `mix --version`, `mix deps`) | 822 | 0 |
| CR3-DESKTOP-MOBILE-FIRST, terminal non-infrastructure halt (setup 22044 + command 48989 = 71033; execution = wall) | 71033 | 1 |
| **Total carried** | **2222537** | **8** |

Spent reservations (nine, never reopened): D19-DIAG-01, R-DIAG-DESKTOP, R-INFRA-RETRY-DESKTOP, R-DIAG-MOBILE, R-DIAG-CONTROL-DARK, CR-DARK-FIRST, CR-DESKTOP-MOBILE-FIRST, CR2-DESKTOP-MOBILE-FIRST, CR3-DESKTOP-MOBILE-FIRST.

Status of older reservations:

- Original retry: used 1, available 0.
- R2 infrastructure retry CR2-INFRA-RETRY: expired earlier.
- R3 infrastructure retry CR3-INFRA-RETRY: granted 1, used 0. The halt was not infrastructure, so the retry was never eligible. It is EXPIRED and was never charged.
- CR3-DESKTOP-SECOND, CR3-MOBILE-SECOND and CR3-DARK-SECOND never launched. They are RETIRED unused, because they are bound to the R3 freeze.
- The R3 preparation remainder (9178 ms) is retired, not carried.
- Cumulative preparation used is 5141 + 822 = 5963 ms.

## Remaining headroom under the approved R3 caps

| Cap (Jon-approved R3, with retry) | Approved | Charged / used | Remaining |
|---|---:|---:|---:|
| D19-R3 cumulative | 3060682 ms | 2222537 ms | 838145 ms |
| D-19 CLI launches | 12 | 8 | 4 |
| Shared R3 cumulative (D19-R3 + acceptance + optional seeds) | 5400682 ms | 2222537 ms | 3178145 ms |
| Physical CLI | 21 | 8 | 13 |

## Remaining native work and sizing

The work left is to re-run the first window (16 rows) and then the three second windows (2 rows each), for 22 accepted rows. Per-window allowances are carried unchanged from `253-LOAD-RECOVERY-BUDGETS-R3.md`. They are not shrunk to the R3 measurement, for two reasons:

- The 165000 ms first-window work deadline is sized to the failure path (162600 ms). It completes a full 16-row report even if both controls regress and time out.
- The second windows are still unobserved natively.

Measured in R3 for reference only (not used to lower the caps):

- CR3-DESKTOP-MOBILE-FIRST charged 71033 ms of its 240000 ms allowance (29.6%): setup 22044 of 60000, command 48989 of 180000.
- Preparation charged 822 of 10000.
- An estimated pass-path spend for the remaining work is about 228000 ms: preparation ~1000, first window ~71000, and three second windows at about 52000 each (setup ~22000 + app boot, absence query, CLI and two rows ~30000). This is an estimate, not a cap.

## Proposed NEW allowance for the remaining native control work

| Component | ms | Max CLI | Justification |
|---|---:|---:|---|
| R4 preparation reservation | 10000 | 0 | R3 measured 822 ms; R3 row unchanged. |
| CR4-DESKTOP-MOBILE-FIRST (maps from spent CR3-DESKTOP-MOBILE-FIRST; identical 16-row selection, titles, projects, argv, ports and expected CLI exit 1): setup 60000 + work 165000 + cleanup 15000 | 240000 | 1 | R3 row unchanged (failure-path sized). |
| CR4-DESKTOP-SECOND (maps from retired CR3-DESKTOP-SECOND): setup 60000 + work 60000 + cleanup 15000 | 135000 | 1 | R3 row unchanged. |
| CR4-MOBILE-SECOND (maps from retired CR3-MOBILE-SECOND): same shape | 135000 | 1 | R3 row unchanged. |
| CR4-DARK-SECOND (maps from retired CR3-DARK-SECOND): same shape | 135000 | 1 | R3 row unchanged. |
| CR4-INFRA-RETRY: exactly one infrastructure retry, sized to the largest slot. It inherits the halted slot's own window sizes when used. | 240000 | 1 | Eligibility unchanged (below). |
| Explicit headroom | 15000 | 0 | One terminal overrun only. |
| **New D-19 allowance (with retry)** | **910000** | **5** | 15.2 minutes. |

Sum with retry: 10000 + 240000 + 3 x 135000 + 240000 + 15000 = 910000. Sum without retry: 910000 - 240000 = 670000, max CLI 4.

## Proposed caps: with and without the retry

| | With retry (`approve`) | Without retry (`approve-without-retry`) |
|---|---:|---:|
| New D-19 allowance | 910000 ms | 670000 ms |
| D19-R4 cumulative cap (2222537 + allowance) | **3132537 ms** (52.2 min) | **2892537 ms** (48.2 min) |
| D-19 CLI launches max (8 + new) | **13** | **12** |
| Unallocated inside D-19's 3600000 ms total ceiling | 467463 ms | 707463 ms |
| Conditional acceptance (9 x 240000) | 2160000 ms / 9 CLI | 2160000 ms / 9 CLI |
| Optional ExUnit seeds (101/202/303 at 60000) | 180000 ms / 0 CLI | 180000 ms / 0 CLI |
| **Shared R4 cap** (D19-R4 + acceptance + seeds) | **5472537 ms** | **5232537 ms** |
| **Physical CLI max** | **22** | **21** |

## Does the remaining work fit inside the approved R3 headroom?

- **With the retry: NO. It needs an increase.** The new allowance (910000 ms, 5 launches) exceeds the remaining D19-R3 headroom (838145 ms, 4 launches) by **71855 ms and 1 launch**. The shared cap rises from 5400682 to 5472537 ms (+71855) and the physical CLI max from 21 to 22 (+1). D19-R4 3132537 ms remains inside D-19's sixty-minute total.
- **Without the retry: YES. No increase is needed.** The new allowance (670000 ms, 4 launches) fits the remaining D19-R3 headroom with 168145 ms and 0 launches to spare. The shared cap 5232537 ms and CLI max 21 are at or below the approved R3 shared figures (5400682 ms / 21).
- Both options exceed D-19's twenty-minute per-signature and ten-invocation figures, as R2 and R3 already did. The causes are the sleep-inflated 253-40 charge, the earlier control rounds, and the lost 253-51 and 253-63 first windows. That is why explicit approval is required.

Considered and not offered: a retry sized only for a second window (135000 ms) would fit the R3 headroom (805000 ms). It would leave a first-window host fault, the largest and likeliest exposure, unretryable, so it is not offered.

## Infrastructure retry eligibility (CR4-INFRA-RETRY)

Eligibility is unchanged from R2 and R3. The retry is eligible only when all of these hold:

- the halted attempt's receipt records runner-detected suspension (`suspended: true`), loss of the caffeinate assertion holder, or a host-level failure before Playwright selected any test;
- a separate written diagnostic (`253-LOAD-RECOVERY-NATIVE-R4-INFRA-DIAGNOSTIC.json`) cites independent host evidence, such as a `pmset -g log` excerpt or a process table;
- the retry is unused.

The retry is not eligible for:

- any assertion result or Playwright timeout without suspension;
- missing or extra rows caused by test behavior, or an expected-failure mismatch;
- a validator rejection (the 253-63 class) or an overrun without suspension.

When used, the retry re-runs the halted slot's exact frozen selection once. The original attempt stays preserved and charged. A second infrastructure halt is terminal.

## Halt diagnostics and host-sleep safety (every native window)

Unchanged from R3:

- Every attempt that launches the CLI must leave, in its raw receipts, the sanitized per-test JSONL and every sanitized `error-context.md`, on pass, fail or deadline kill.
- Every halt stop record lists per-test rows (project, title, status, duration, first error line).
- The positive control keeps annotating `email_value_after_ready_was_empty`.
- Before any predebit the host must be on AC power, the runner-owned `caffeinate -i -s -m -w <runner pid>` holder must be running, and `pmset -g assertions` must list that holder. A failure stops at zero charge.
- A suspension halts and is charged at max(monotonic, wall).

## Decision options presented at 253-73 Task 1

- `approve` (recommended): the caps in the "With retry" column, with exactly one infrastructure retry. This is an increase of 71855 ms and 1 launch over the approved R3 caps.
- `approve-without-retry`: the caps in the "Without retry" column. These fit inside the approved R3 caps with no increase. Any further halt ends the native round.
- `reject`: no native launch; CIREL-01 stays open; the phase halts honestly at 253-73.

Any other change to these numbers requires a new planning round, not an in-flight edit.

## Hosted and PR allocations (unchanged)

These are unchanged from `253-LOAD-RECOVERY-BUDGETS.md`, R2 and R3:

- Canary: 117 new measured requests + 3 known historical command allocations, 45 jobs, 60 minutes.
- Production PR allocation: exactly 120 requests, 60 minutes.
- Both reserved reruns are frozen EXPIRED in 253-75.

Each outward GitHub action stays gated by Jon's re-confirmation of the enumerated pre-clock action manifest:

- 253-76 (canary): scoped ref creations, six dispatches, one cancellation, one verifier dispatch.
- 253-77 (PRs): docs object publication plus exactly two draft PRs; no merge and no push to main.

This is the same scope Jon approved for 253-54/253-55 and that the never-run 253-66/253-67 carried.

## Plan map for this round

| Plan | Wave | Depends on | Role (supersedes) |
|---|---:|---|---|
| 253-69 | 1 | — | Context-identity validator fix (R4-only per-row union mode, TDD with the preserved-report regression fixture), plus the R4 ledger, R3-lineage history reader and freeze create/check/init |
| 253-71 | 1 | 253-61 | R4 reconciliation contract (`--revision r4`) covering PLANs 01-78: 33 never-executed, 9 halted |
| 253-70 | 2 | 253-69 | R4 prepare/run/verify path with the fixed verifier, R4 approval binding, retry gates, and completion-verifier load links bound to R4 artifacts |
| 253-72 | 3 | 253-69, 253-70 | Offline gate on the final committed source, then create/check/commit the R4 native freeze |
| 253-73 | 4 | 253-72 | Jon's budget decision, then the 22-row native run under the R4 freeze (supersedes halted 253-63) |
| 253-74 | 5 | 253-73 | Cause assessment and conditional acceptance (supersedes never-run 253-64) |
| 253-75 | 6 | 253-74, 253-49 | Canary adapter, live publication origin, final source freeze (supersedes never-run 253-65) |
| 253-76 | 7 | 253-75 | Jon's outward-action re-confirmation, then the hosted canary (supersedes never-run 253-66) |
| 253-77 | 8 | 253-76 | Jon's outward-action re-confirmation, then normal and docs-only draft PRs (supersedes never-run 253-67) |
| 253-78 | 9 | 253-77, 253-71 | Completion record and accepted-only R4 disposition bundle (supersedes never-run 253-68) |

Execution is sequential on one branch. No allocation is spent by writing this document.
