# Phase253 current requirement review

CIREL-02 is verified and complete. All five required names and useful selected bodies remain intact. Retained native PR343 and docs-only PR344 evidence verify, as do all six real hosted fixture outcomes and their separate verifier. The negative fixture cases remain non-green. Fresh source comparison proves the current gate inputs match the hosted proof. Ledgers stay separate; no original single-ledger pair acceptance is claimed and no redundant check was removed.

CIREL-01 remains incomplete. The original order log was recovered and authenticated from the Phase252 archive. The approved full161-test prefix on preserved source4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97 passed:64 desktop,64 mobile,33 dark, zero retries/skips. Setup through cleanup took553256ms, below1200000ms. This is a completed diagnostic, not a reproduced/fixed registration failure. No demonstrated cause, tested fix or fresh post-fix repeats exist. The original strict acceptance reader still exits3; all9 historical post-fix slots stay expired.

The environment differs: this host is macOS arm64 with PostgreSQL14.17; the selected CI job used Ubuntu x64 with PostgreSQL15.19, confirmed by the original archived startup log. The original database snapshot and redacted page-state fields remain unavailable. These limits prevent treating a local pass as proof of no CI flake.

Automated UAT is partial:5 passed,1 blocked. GSD's own completion predicate refuses phase advancement because the registration criterion is blocked and canonical phase verification is missing. The verify-work skill does not manufacture that owner's report. No human UAT, additional browser, CI action, budget reset, new numbered repair plan or status detour is required by this review.

Fresh local checks passed:21 shell cases plus5 unit-owner checks,57 Node contracts,151 verifier tests and14 recovery checks. Read-only checks re-opened the actual retained hosted evidence; no GitHub requests or CI launches were made.

Evidence: `.planning/execution/253-registration-order-recovery/full-prefix-result-review.json`, `requirement-review/result.json`, and `253-UAT.md`. Actual native evidence commit:3626e9abb. Next command: `$gsd-execute-phase 253 --gaps-only` for offline diagnosis of the CI environment differences, with no further native invocation authorized. Phase254 remains pending with no context/research/plans; after actual253 completion, recheck readiness and use `$gsd-discuss-phase 254`.

## Prepared Linux reproduction path

The user asked to unblock diagnosis. `.planning/execution/253-registration-linux/README.md` and `proposal.json` now provide a concrete, locally prepared Linux x64 diagnostic using the exact archived PostgreSQL image digest, original tools, hostname, warmup and161-test order. Database setup/app readiness passed in11.4seconds and cleanup completed; zero browser tests ran. This replaces the empty gap-plan scan as the immediate action. After explicit approval of the new one-run/2400-second limit, execute `python3 .planning/execution/253-registration-linux/diagnostic.py --run` once. The old limits remain closed. Emulation/JIT and original snapshot limits are explicit. No cause, fix or phase verification has been claimed.

## Approved Linux replay completed

All161original-order tests passed once,including the original failing dark board-mg-9/populated case. Zero retries/skips;1622.2seconds including cleanup;owned containers removed. Result:`.planning/execution/253-registration-linux/RESULT.json`. The CI timeout remains unreproduced;no demonstrated cause or fix. CIREL-01 and Phase253 remain incomplete;CIREL-02 unchanged. The new one-run approval is consumed. Next:$gsd-debug "Phase 253 registration timeout: inspect the original CI failure and Linux replay logs; offline only, no browser or CI run";no additional browser/CI execution authorized.

## Original registration server failure identified

The authenticated original log shows save161crashing on Ecto.Queryable.to_query/1 during email uniqueness validation, before any account insert or login POST. Its generated account sequence and time match the selected browser failure. This identifies the immediate failure;why the module was unavailable is still unproved. The Linux comparison and two passing local purge probes are retained in `.planning/debug/phase253-registration-timeout/evidence.json`. No product fix or browser/CI execution occurred. CIREL-01 and Phase253 remain incomplete;CIREL-02 unchanged. Next:`$gsd-debug continue phase253-registration-timeout`,for a traced offline reloader unit experiment.

## CI reloader fix implemented and checked offline

Commit a87664733 disables example hot code reloading for CI=true/1. The controlled OTP/Phoenix interleaving produces the exact original module error;the actual patched CI configuration passes the same schedule. This is a component counterexample,not a replay of the original job. Three configuration tests,example compilation and compiled endpoint inspection pass. Evidence:`.planning/debug/phase253-registration-timeout/CONTINUATION-RESULT.json`,retained at b6a607da3. No browser or CI ran;all old scopes remain closed. CIREL-01 and whole-phase verification still need fresh runtime results;CIREL-02 gate implementation is unchanged. Next:`$gsd-debug continue phase253-registration-timeout` to prepare a source-pinned validation bundle offline before any new runtime decision.

## Source-pinned post-fix check prepared

The candidate Linux image rebuilt offline from actual product commit a87664733. Fifteen runner tests pass;three config tests pass for each seed101/202/303;candidate compilation,compiled endpoint inspection and exact per-project list-only selection pass. The actual unapproved command refuses before reservation/allocation. Bundle:b63fb33e665d1a48c7dbcb124a21a09043cb4722;checks:`.planning/execution/253-registration-postfix/CHECKS.json`. No app,database,browser or CI started.

New proposal f879adda9ecfe4e0b5860daf25bb6bb49d908165a5e34fc86db8a6b592fc5b06 requests nine fresh local Linux invocations/1200seconds including cleanup,zero retries and first-failure stop. All prior allowances remain closed. Approval is pending;after approval,use `$gsd-debug continue phase253-registration-timeout` to run the existing prepared bundle once. Normal integration and CIREL-01/phase verification remain after targeted passes. CIREL-02 is unchanged. Phase254 readiness was rechecked:pending,no context/research/plans;its future route after actual253 completion remains `$gsd-discuss-phase 254`.
