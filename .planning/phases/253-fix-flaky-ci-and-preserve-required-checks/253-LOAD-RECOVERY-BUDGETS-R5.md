# Phase253 load recovery budgets — revision 5 (PROPOSED, requires Jon's approval)

Status: planning proposal. No native or GitHub work ran while this document was written. The document grants NO capacity by itself.

Capacity becomes usable only after plan 253-83 Task 1 (`checkpoint:decision`) records Jon's explicit decision in `253-LOAD-RECOVERY-BUDGET-APPROVAL-R5.json` through `--record-budget-approval`. That record is bound to this file's SHA-256 and to the SHA-256 of `253-LOAD-RECOVERY-NATIVE-FREEZE-R5.json` (created by 253-82).

The R4 approval (`253-LOAD-RECOVERY-BUDGET-APPROVAL-R4.json`, sha256 6f866bb3...) is bound to the R4 doc and the R4 freeze. It cannot be reused for the changed runner bytes, and it expires with its unused infrastructure retry. Every earlier budget document, freeze, approval, evidence file and raw receipt stays byte-for-byte unchanged as spent lineage.

## Why a revision is needed

Plan 253-73 recorded Jon's R4 approval (approve, retry granted) and ran on a provably awake host:

- **CR4-DESKTOP-MOBILE-FIRST was ACCEPTED, 16/16 rows.** It charged 92810 ms (setup 22673 + command 70137) and was launch 9. `--verify-load-recovery --stage first` exited 0 on the committed `first_complete` revision (commit 0596dd97a, evidence sha256 08437732...b24193).
- **CR4-DESKTOP-SECOND halted terminally before Playwright launched.** It used no launch, produced 0 rows and charged 43535 ms (setup 39782 + command 3753). The pre-registration `prior_collision_absence` step exited 3 with empty stdout.

Root cause, verified offline by the orchestrator (not a hypothesis):

- `ACCOUNT_COUNT_QUERY` in `scripts/ci/ci-registration-recovery.mjs` is `SELECT count(*) FROM users WHERE email = :'target';`.
- The example app creates its tables in the `auth` schema (`@auth_prefix "auth"` in `test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs`; `@schema_prefix "auth"` in `test/example/lib/example/accounts/user.ex`) and sets no `search_path`.
- Run read-only against the local migrated `example_test` database, the unqualified query gives `ERROR: relation "users" does not exist` and psql exit 3 (ON_ERROR_STOP). `auth.users` gives exit 0.
- The same constant backs the `created_account` receipt (expected count 1), so it would also have failed there.
- Only second-window attempts call it. That is why the accepted first window is unaffected, and why R2/R3 (which never reached a second window) never exposed it. Unit tests stub `psql`, so nothing exercised the real SQL.
- Diagnostic gap: `captureOwnedAccountCount` writes only stdout to the log and drops psql stderr, so the receipt never named the error.

This is a runner defect, not a test, product or host fault. Plan 253-79 fixes it in an R5-only code path (schema-qualified count, stderr capture, a real-Postgres integration test). Plan 253-80 completes the R5 runner revision. No product source changes (D-04).

## Carried actuals (immutable, each identity counted once)

| Carried component | ms | Actual CLI processes |
|---|---:|---:|
| R4 carried total (see `253-LOAD-RECOVERY-BUDGETS-R4.md`) | 2222537 | 8 |
| R4 preparation (253-73: `mix --version`, `mix deps`) | 821 | 0 |
| CR4-DESKTOP-MOBILE-FIRST, ACCEPTED (16 rows; setup 22673 + command 70137) | 92810 | 1 |
| CR4-DESKTOP-SECOND, terminal non-infrastructure halt before any CLI (setup 39782 + command 3753) | 43535 | 0 |
| **Total carried** | **2359703** | **9** |

Spent reservations (eleven, never reopened): D19-DIAG-01, R-DIAG-DESKTOP, R-INFRA-RETRY-DESKTOP, R-DIAG-MOBILE, R-DIAG-CONTROL-DARK, CR-DARK-FIRST, CR-DESKTOP-MOBILE-FIRST, CR2-DESKTOP-MOBILE-FIRST, CR3-DESKTOP-MOBILE-FIRST, CR4-DESKTOP-MOBILE-FIRST, CR4-DESKTOP-SECOND.

Status of older reservations:

- Original retry: used 1, available 0.
- CR2-INFRA-RETRY and CR3-INFRA-RETRY: expired earlier.
- R4 infrastructure retry CR4-INFRA-RETRY: granted 1, used 0. The halt was not infrastructure (host awake, `max_tick_gap_ms` 3, holder alive), so the retry was never eligible. It is EXPIRED and was never charged.
- CR4-MOBILE-SECOND and CR4-DARK-SECOND never launched. They are RETIRED unused, because they are bound to the R4 freeze.
- The R4 preparation remainder (9179 ms) is retired, not carried.
- Cumulative preparation used is 5963 + 821 = 6784 ms.

## The accepted first window is carried forward, not re-run

R5 runs only the three second windows (CR5-DESKTOP-SECOND, CR5-MOBILE-SECOND, CR5-DARK-SECOND; 6 rows). The R5 acceptance verifier counts the 16 R4 first-window rows as already accepted, bound by their committed evidence hashes. This is sound for these reasons:

1. **The verdict reproduces from committed bytes.** The committed `first_complete` R4 revision (commit 0596dd97a, sha256 084377320bce81ac6c84ca1adca847805861cc8815572453b407132eb3b24193; also preserved as a scoped ref in the R4 evidence's `preserved_revisions`) re-verifies `--stage first` with the current runner. The R4 verifier reads the frozen blobs through git at the R4 frozen commit 4fdbc82b4. The halted R4 evidence's `attempts[0]` is byte-identical (canonical JSON) to that revision's `attempts[0]`. Both facts were checked offline, read-only, during planning.
2. **The system under test is identical.** The R5 freeze must prove that every blob it pins, other than the runner and its tests, equals the R4 frozen blob. The newly pinned migration file must equal its blob at the R4 frozen commit. Product, spec, helper, reporter, config and lockfile bytes are unchanged (D-04).
3. **The judging code is unchanged.** The R5 fix is additive, like 253-69's `per_row_union` opt-in. The R4 functions that judged the first window (`verifyNativeLoadAttemptR4`, `verifyAttemptAccountingR3`, `verifyHostAwakeR3`, the per-row union helpers) stay byte-identical. The defective code (`captureOwnedAccountCount`) runs only when `slot.stage === 'second'`, so the first window never executed it.
4. **The cross-window invariants are re-checked over all 22 rows.** Second windows must prove the project's frozen collision account absent on a fresh database, with a digest equal to the carried first attempt's `collision_receipts[project]`. Database names must differ from the carried attempt and from each other. Context ids must be unique across the union of the 16 carried rows (parsed from the hash-pinned R4 raw report) and the 6 new rows. This union check is stricter than R4's per-attempt check.
5. **Re-running would spend capacity without new information, and would need a cap increase.** It would need 10000 + 240000 + 3 x 135000 + 240000 + 15000 = 910000 ms and 5 launches, which exceeds the remaining R4 headroom (772834 ms, 4 launches) by 137166 ms and 1 launch.

The carried rows stay R4 evidence. R5 never rewrites them. It records a `carried_first_window` binding (R4 evidence path and sha256, the first_complete commit and sha256, the attempt's canonical sha256, the R4 freeze sha256 and checkout head, and the raw-file hashes) and re-verifies that binding on every R5 verification.

## Remaining headroom under the approved R4 caps

| Cap (Jon-approved R4, with retry) | Approved | Charged / used | Remaining |
|---|---:|---:|---:|
| D19-R4 cumulative | 3132537 ms | 2359703 ms | 772834 ms |
| D-19 CLI launches | 13 | 9 | 4 |
| Shared R4 cumulative (D19-R4 + acceptance + optional seeds) | 5472537 ms | 2359703 ms | 3112834 ms |
| Physical CLI | 22 | 9 | 13 |

## Remaining native work and sizing

The work left is the three second windows (2 rows each, 6 rows), which complete the 22 accepted rows together with the carried 16. Per-window allowances are carried unchanged from R4. They are not shrunk to measurement, because no second window has produced a row yet natively.

Measured, for reference only (not used to lower the caps):

- The halted CR4-DESKTOP-SECOND spent 39782 ms of its 60000 ms setup bound (66%). That leaves 20218 ms of margin. The R3 first-window setup was 22044 ms and the R4 first-window setup 22673 ms.
- Preparation charged 821 of 10000.
- Estimated pass-path spend: about 225000 ms (three windows at about 75000 each: setup about 40000, plus app boot, the two count queries, the CLI and two rows at about 30000), plus about 1000 ms of preparation. This is an estimate, not a cap.

## Proposed NEW allowance for the remaining native control work

| Component | ms | Max CLI | Justification |
|---|---:|---:|---|
| R5 preparation reservation | 10000 | 0 | R4 measured 821 ms; row unchanged. |
| CR5-DESKTOP-SECOND (maps from spent CR4-DESKTOP-SECOND; identical 2-row selection, titles, project, argv, port and expected CLI exit 0): setup 60000 + work 60000 + cleanup 15000 | 135000 | 1 | R4 row unchanged. |
| CR5-MOBILE-SECOND (maps from retired CR4-MOBILE-SECOND): same shape | 135000 | 1 | R4 row unchanged. |
| CR5-DARK-SECOND (maps from retired CR4-DARK-SECOND): same shape | 135000 | 1 | R4 row unchanged. |
| CR5-INFRA-RETRY: exactly one infrastructure retry, sized to the largest R5 slot. It inherits the halted slot's own window sizes when used. | 135000 | 1 | Every R5 slot is a 135000 ms second window. The runner gives the retry the halted slot's sizes, so R4's 240000 ms (first-window) sizing could never be spent here. |
| Explicit headroom | 15000 | 0 | One terminal overrun only. |
| **New D-19 allowance (with retry)** | **565000** | **4** | 9.4 minutes. |

Sum with retry: 10000 + 3 x 135000 + 135000 + 15000 = 565000. Sum without retry: 565000 - 135000 = 430000, max CLI 3.

## Proposed caps: with and without the retry

| | With retry (`approve`) | Without retry (`approve-without-retry`) |
|---|---:|---:|
| New D-19 allowance | 565000 ms | 430000 ms |
| D19-R5 cumulative cap (2359703 + allowance) | **2924703 ms** (48.7 min) | **2789703 ms** (46.5 min) |
| D-19 CLI launches max (9 + new) | **13** | **12** |
| Unallocated inside D-19's 3600000 ms total ceiling | 675297 ms | 810297 ms |
| Conditional acceptance (9 x 240000) | 2160000 ms / 9 CLI | 2160000 ms / 9 CLI |
| Optional ExUnit seeds (101/202/303 at 60000) | 180000 ms / 0 CLI | 180000 ms / 0 CLI |
| **Shared R5 cap** (D19-R5 + acceptance + seeds) | **5264703 ms** | **5129703 ms** |
| **Physical CLI max** | **22** | **21** |

## Does the remaining work fit inside the approved R4 headroom?

- **With the retry: YES. No cap increase.** The new allowance (565000 ms, 4 launches) fits the remaining D19-R4 headroom (772834 ms, 4 launches) with **207834 ms and 0 launches to spare**. The shared cap falls from 5472537 to 5264703 ms. The physical CLI max stays 22.
- **Without the retry: YES. No cap increase.** The new allowance (430000 ms, 3 launches) fits with **342834 ms and 1 launch to spare**. The shared cap is 5129703 ms and the CLI max is 21.
- Both options stay below every Jon-approved R4 figure. Both still exceed D-19's twenty-minute per-signature and ten-invocation figures, as R2, R3 and R4 already did. That is why explicit approval is still required.

Considered and not offered: re-running the first window. It is not needed (see the carry-forward section), and with the retry it would need a 137166 ms and 1-launch increase over the R4 caps.

## Infrastructure retry eligibility (CR5-INFRA-RETRY)

The trigger is the same narrow one R4 used (253-70 dropped R3's `host_failure` cause). The retry is eligible only when all of these hold:

- the halted attempt's receipt records runner-detected suspension (`suspended: true`) or loss of the caffeinate assertion holder (`holder_alive_at_end: false`);
- a separate written diagnostic (`253-LOAD-RECOVERY-NATIVE-R5-INFRA-DIAGNOSTIC.json`) cites independent host evidence, such as a `pmset -g log` excerpt or a process table;
- the retry is unused and the approval is `approve`.

The retry is not eligible for:

- any assertion result or Playwright timeout without suspension;
- a setup failure or a failed count query without suspension (the 253-73 class);
- missing or extra rows caused by test behavior, or an expected-failure mismatch;
- a validator rejection, or an overrun without suspension.

When used, the retry re-runs the halted slot's exact frozen selection once. The original attempt stays preserved and charged. A second infrastructure halt is terminal.

## Halt diagnostics and host-sleep safety (every native window)

Unchanged from R4, plus the psql stderr receipts:

- Every attempt that launches the CLI must leave, in its raw receipts, the sanitized per-test JSONL and every sanitized `error-context.md`, on pass, fail or deadline kill.
- Every halt stop record lists per-test rows (project, title, status, duration, first error line).
- Every R5 count query and the database-absence query keep bounded, redacted psql stderr (no credentials, target email redacted) in a sibling log, with its hash and first line in the receipt. A non-zero exit still rejects the attempt, and the stop reason names the psql error.
- Before any predebit the host must be on AC power, the runner-owned `caffeinate -i -s -m -w <runner pid>` holder must be running, and `pmset -g assertions` must list that holder. A failure stops at zero charge.
- A suspension halts and is charged at max(monotonic, wall).

## Decision options presented at 253-83 Task 1

- `approve` (recommended): the caps in the "With retry" column, with exactly one infrastructure retry. No increase over the approved R4 caps.
- `approve-without-retry`: the caps in the "Without retry" column. No increase. Any further halt ends the native round.
- `reject`: no native launch; CIREL-01 stays open; the phase halts honestly at 253-83.

Any other change to these numbers requires a new planning round, not an in-flight edit.

## Hosted and PR allocations (unchanged)

These are unchanged from `253-LOAD-RECOVERY-BUDGETS.md` and R2 through R4:

- Canary: 117 new measured requests + 3 known historical command allocations, 45 jobs, 60 minutes.
- Production PR allocation: exactly 120 requests, 60 minutes.
- Both reserved reruns are frozen EXPIRED in 253-85.

Each outward GitHub action stays gated by Jon's re-confirmation of the enumerated pre-clock action manifest:

- 253-86 (canary): scoped ref creations, six dispatches, one cancellation, one verifier dispatch.
- 253-87 (PRs): docs object publication plus exactly two draft PRs; no merge and no push to main.

This is the same scope Jon approved for 253-54/253-55, which the never-run 253-66/67 and 253-76/77 carried.

## Plan map for this round

| Plan | Wave | Depends on | Role (supersedes) |
|---|---:|---|---|
| 253-79 | 1 | — | R5-only schema-qualified account count with stderr capture (TDD), a real-Postgres integration test, the raw-SQL audit, plus the R5 ledger, R4-lineage history reader, carried-first-window binding and freeze create/check/init |
| 253-81 | 1 | 253-71 | R5 reconciliation contract (`--revision r5`) covering PLANs 01-88: 38 never-executed, 10 halted; completion verifier load_controls re-pointed to R5 |
| 253-80 | 2 | 253-79 | R5 run path for the three second windows, the R5 evidence verifier (carried-first and 22-row cross-window checks), R5 approval binding and retry gates |
| 253-82 | 3 | 253-79, 253-80, 253-81 | Offline gate on the final committed source (including the real-Postgres test), then create/check/commit the R5 native freeze |
| 253-83 | 4 | 253-82 | Jon's budget decision, then the three second windows under the R5 freeze (supersedes halted 253-73) |
| 253-84 | 5 | 253-83 | Cause assessment and conditional acceptance (supersedes never-run 253-74) |
| 253-85 | 6 | 253-84, 253-49 | Canary adapter, live publication origin, final source freeze (supersedes never-run 253-75) |
| 253-86 | 7 | 253-85 | Jon's outward-action re-confirmation, then the hosted canary (supersedes never-run 253-76) |
| 253-87 | 8 | 253-86 | Jon's outward-action re-confirmation, then normal and docs-only draft PRs (supersedes never-run 253-77) |
| 253-88 | 9 | 253-87, 253-81 | Completion record and accepted-only R5 disposition bundle (supersedes never-run 253-78) |

Execution is sequential on one branch. No allocation is spent by writing this document.
