# Continue — Plan 245-19

## Last action

Resolved Plan 245-19 D-05's symbolic-HEAD capability mismatch: the probe now invokes the validated `/usr/bin/git` 2.50.1 directly, and disposable fixtures require hook enforcement under a poisoned PATH. The coordinator and pruning shell suites pass; both Node suites pass 5/5; reverting the executable-path fix reproduces the failure. No production refs, worktrees, Git config, coordinator installation, or origin state were mutated. See `.planning/debug/resolved/coordinator-symbolic-head-hook.md` and `245-19-PLAN.md`.

## Next action

Run:

`$gsd-execute-phase 245 --gaps-only`

## Why

The exact pinned-runtime capability gate and its regression coverage now pass. Plan 19 remains active because no fresh D-07 contract or candidate classification has been captured; resume the existing gap plan to continue its admission and mutation-boundary checks.

## Open threads

- No fresh D-07 contract was captured and no candidate was classified. REPO-04 remains open.
- Plan 245-16 remains blocked by halted Plan 245-14. Plans 245-04, 09, 12, and 14 remain halted.
- The historical 11-row PR-base and 30-row cleanup-history audits remain unresolved.
- `/usr/bin/git` is pinned at version 2.50.1 with SHA-256 `b8763cf250e607a778bb4603cecb5b90338814d0a3dfcba0d57b1de242f610e9`; PATH Git is 2.41.0.

## Do not

- Do not bypass Plan 19's D-06 source-pin, current-state, admission, PR/ref, exact-binary, or shared-lock checks. Do not install the production coordinator, delete refs, or push unless the plan's mutation gates pass.
- Do not route to stale `$gsd-verify-work` or restart completed Phase 244 work.
- Preserve the unrelated dirty workspace; do not reset, stash, clean, or broadly stage.
