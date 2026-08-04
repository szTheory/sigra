---
phase: 231-gate-honesty-nightly-revival
plan: 10
subsystem: infra
tags: [github-actions, ci, gate-honesty, github-pages, ci-observe, bash]

requires:
  - phase: 231-09
    provides: "GATE-03 closed live in both directions across two event types; ci-gate confirmed green at branch HEAD (a5ca105d)."
provides:
  - "playwright-github-pages.yml seeds the example app before booting it — the publisher's only structural defect (D-17) is fixed and guarded, proven on a real dispatched run."
  - "ci-observe.yml's schedule-lane leniency is deleted — the demotion receipt now fails on the scheduled lane exactly as it does on the push lane (D-19), guarded against reintroduction."
  - "Two new structural prohibition guards (p15, p16), each proven fail-first, each carrying a non-vacuity floor and a negative control."
  - "The publisher-red todo's wrong 'spec drift' hypothesis corrected on the record and moved to resolved."
  - "D-18 (GitHub Pages source builds main's repo root, not gh-pages) diagnosed precisely: the self-heal script is hard-gated to github.ref == 'refs/heads/main' and structurally cannot be exercised from a phase-branch dispatch before this fix merges. Filed as a standing/backstop obligation with exact post-merge verification steps, not claimed as either resolved or confirmed-broken."
  - "MAINTAINING.md residual 4 reconciled from a forward commitment into a past-tense record citing the measured nightly evidence."
affects: [231-11]

tech-stack:
  added: []
  patterns:
    - "A conditional seeds step in a workflow with no diff-classification (`changes`) job is worse than no step at all — it evaluates empty, never runs, and looks like coverage. p15 asserts the copied seeds step is unconditional, not merely present."
    - "A guard's negative controls are literal embedded YAML fixture strings run through the SAME pure extraction/assertion function as the real subject, so the guard's own logic — not just the real file's current shape — is proven falsifiable."
    - "A workflow step hard-gated on `github.ref == 'refs/heads/main'` cannot be exercised by any workflow_dispatch from a feature branch before merge, because dispatch always resolves the workflow definition from the dispatched ref — the fix and the ref==main gate can never both be satisfied pre-merge. This is the same class of 'structurally unobservable pre-merge' finding D-21 solved for gate-ci-green, but here there is no extractable pure-logic escape valve (the gate lives in workflow YAML `if:`, not in a script), so the honest answer is a standing/backstop obligation rather than a live proof."

key-files:
  created:
    - scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs
    - scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs
    - .planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md
  modified:
    - .github/workflows/playwright-github-pages.yml
    - .github/workflows/ci-observe.yml
    - MAINTAINING.md
    - .planning/todos/resolved/2026-07-27-playwright-github-pages-publisher-red.md (moved from pending, resolution appended)

key-decisions:
  - "D-18 is filed as a standing/backstop obligation, not a confirmed self-heal failure. The plan's own acceptance criteria frame D-18 as a binary (self-healed vs. did-not-self-heal-so-file-it), but the live dispatch proved a third, more precise state: the self-heal script cannot be exercised at all from a pre-merge dispatch, because the `Publish to gh-pages branch` / `Point GitHub Pages` steps are hard-gated on `github.ref == 'refs/heads/main'`, and no ref can simultaneously carry this phase's fix and satisfy that gate before merge. Filing it as 'confirmed did not self-heal' would overclaim a negative result the run never actually tested; filing it as 'self-healed' would be false (the live Pages source read is unchanged: `branch: main, path: /`). The todo states this precisely, with reproduction steps for the first post-merge push-to-main or scheduled run, and both of D-18's candidate root causes left open rather than guessed at."
  - "Fixed a staging omission from Task 1 with a small dedicated correction commit (702eeffa) instead of amending. `git mv` staged the todo file's rename, but subsequent Edit calls to flip its status and append the resolution section were made without re-staging before Task 1's commit — so Task 1's commit captured only the bare rename. Per the git safety protocol (never amend unless explicitly requested), the content was committed separately rather than folded backward into Task 1's history or silently absorbed into Task 2's unrelated commit."
  - "GATE-01 is NOT marked complete by this plan. Its literal REQUIREMENTS.md text (\"the nightly scheduled run is green, or every remaining red lane is a filed, diagnosed defect with an owner\") requires observing an actual `schedule`-triggered nightly run, which cannot be forced forward and has not yet happened post-fix. Per CONTEXT's Flagged Planner Assumption A3 and the phase's own D-24 sequencing, plan 231-11 owns that final observation and the requirement's closure. This plan closes the two pieces that were genuinely its own (D-17, D-19) and diagnoses the third (D-18)."

requirements-completed: []

coverage:
  - id: D1
    description: "playwright-github-pages.yml's publish job gains an unconditional `Run demo seeds` step strictly between `Setup example dev DB` and `Boot example app in background`, copied from the one unguarded seeds block in ci.yml (admin_eval_render, :2506-2513)"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "python3 YAML-parse assertion (plan's own verify block) -- OK Setup example dev DB -> Run demo seeds -> Install Playwright deps; env keys byte-identical to admin_eval_render's seeds step"
        status: pass
    human_judgment: false
  - id: D2
    description: "p15 proven fail-first against the pre-fix workflow (no step invokes priv/repo/seeds.exs), then green after the fix, with two negative controls (missing seeds step, seeds-after-boot ordering)"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "node --test scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs -- 1 fail / 3 pass pre-fix (observed verbatim below), 4/4 pass post-fix"
        status: pass
    human_judgment: false
  - id: D3
    description: "The publisher-red todo's 'real spec drift' hypothesis is corrected: root cause was unseeded demo data, cited against scheduled run 30432494488 and its three checkpoint-project failures; continue-on-error correctly never applied"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "test -f + git mv (plan's own verify block) -- pending file gone, resolved file exists with appended Resolution section"
        status: pass
    human_judgment: false
  - id: D4
    description: "ci-observe.yml's schedule-lane leniency block deleted at the RESEARCH-corrected span (:123-136, not CONTEXT's stale :130-136); the unconditional exit 1 survives as the sole terminal branch; GATE-03 boundary note untouched"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "python3 comment-stripped assertion (plan's own verify block) -- OK; actionlint clean"
        status: pass
    human_judgment: false
  - id: D5
    description: "p16 proven fail-first against the pre-deletion workflow (warn-instead-of-fail annotation string present), then green after deletion, with a negative control fixture reintroducing the branch"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "node --test scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs -- 1 fail / 3 pass pre-fix (observed verbatim below), 4/4 pass post-fix"
        status: pass
    human_judgment: false
  - id: D6
    description: "MAINTAINING.md residual 4 rewritten from a forward commitment into a past-tense record citing run 30425416933 (23/25 green) as justifying evidence; the five ruleset-required check-name strings at :104-110 are byte-unchanged"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "python3 assertion (plan's own verify block) -- OK; git diff MAINTAINING.md shows one hunk at :262-269, none at :104-110"
        status: pass
    human_judgment: false
  - id: D7
    description: "D-17's fix judged on a real dispatched run, not the diff: run 30529885885 (workflow_dispatch, ref worktree-discuss-231, commit 8e9e7839), job 90829454715, conclusion success; all three checkpoint projects pass the assertion that failed on scheduled run 30432494488"
    requirement: "GATE-01"
    verification:
      - kind: e2e
        ref: "gh workflow run + gh run view -- job 90829454715 success, checkpoint step '1 flaky / 2 passed (3.2m)' with zero pagination-assertion failures; the one flake was an unrelated known-class first-load timeout that passed on Playwright's own retry"
        status: pass
    human_judgment: false
  - id: D8
    description: "D-18 answered precisely: not self-healed, not confirmed-broken, but structurally unobservable pre-merge (the gh-pages-push and ensure-Pages-source steps are hard-gated to github.ref == 'refs/heads/main', both skipped on this dispatch), with the live Pages source re-confirmed unchanged and a todo filed as a standing/backstop obligation"
    requirement: "GATE-01"
    verification:
      - kind: e2e
        ref: "gh api repos/szTheory/sigra/actions/jobs/90829454715 -- Publish to gh-pages branch: skipped, Point GitHub Pages at gh-pages (REST API): skipped; gh api repos/szTheory/sigra/pages -- source unchanged {branch: main, path: /}"
        status: pass
    human_judgment: false
  - id: D9
    description: "ci-gate remains green at branch HEAD after all three tasks land (Prohibition 5: do not break ci-gate)"
    requirement: "GATE-01"
    verification:
      - kind: e2e
        ref: "PR #125 synchronize run 30530864192 (pull_request event, commit 19d99d65) -- ci-gate job success, all lanes success or legitimately skipped"
        status: pass
    human_judgment: false

duration: ~37min
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 10: GATE-01's structural half — Pages publisher seeded and guarded, schedule-lane leniency deleted and guarded, D-18 diagnosed and filed as a standing obligation

**The two structural defects GATE-01 genuinely owned are fixed and guarded — the Pages publisher now seeds the app it boots (D-17), and the demotion receipt fails on the scheduled lane exactly as it does on the push lane (D-19) — both proven on live runs; D-18's Pages-source question is precisely diagnosed as structurally unobservable before this phase's fix reaches `main`, and filed as a standing obligation rather than guessed at in either direction.**

## Performance

- **Duration:** ~37min (includes ~13min of live CI wall-clock on the dispatched publisher run, plus a ~7min PR-synchronize `ci-gate` confirmation run)
- **Started:** 2026-07-30 ~09:09 UTC
- **Completed:** 2026-07-30 ~09:46 UTC
- **Tasks:** 3 planned, 3 completed
- **Files modified:** 7 (3 created: `p15`, `p16`, the new D-18 todo; 4 modified: `playwright-github-pages.yml`, `ci-observe.yml`, `MAINTAINING.md`, the resolved publisher-red todo)

## Sample size (explicit)

**One dispatched publisher run (`30529885885`), one PR-synchronize CI run (`30530864192`), two prohibition-guard fail-first observations (`p15`, `p16`, each observed exactly once pre-fix and confirmed green post-fix).** Per the executor brief's economy instruction and 231-09's precedent: the Pages publisher's job is deterministic given seeded data (not the kind of intermittent race GATE-02's 320px assertion was), so a single dispatched run judged against the specific assertion that failed on scheduled run `30432494488` is sufficient evidence for D-17's fix — a second or third dispatch would not add information about whether the pagination link renders, only re-confirm it. D-18's answer required zero additional dispatches: the `skipped` conclusion on both downstream steps is definitive and reproducible on every dispatch from any non-`main` ref, so repeating it would prove nothing new. The one PR-synchronize run confirms `ci-gate` health at the final commit, per Prohibition 5.

## Accomplishments

- **D-17 fixed and guarded.** `playwright-github-pages.yml`'s publish job gained an unconditional `Run demo seeds` step, copied verbatim (env keys byte-identical, confirmed via YAML-parsed comparison) from the one seeds block in `ci.yml` that carries no `docs_only` guard (`admin_eval_render`, `:2506-2513`) — deliberately not the three guarded variants, since this workflow has no `changes` job for a docs-only condition to evaluate against (it would silently never run). `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` asserts the step exists, is unconditional, and sits strictly between DB setup and app boot, proven fail-first against the pre-fix workflow and green after, with two negative-control fixtures (a step-omitting fixture, an ordering-violating fixture) proving the guard's own logic is falsifiable, not just coincidentally matching the real file's current shape.
- **D-19 fixed and guarded.** `ci-observe.yml`'s `Verdict` step lost its schedule-lane leniency block — deleted at the RESEARCH-corrected span `:123-136` (not CONTEXT's stale `:130-136`), so the rationale comment and the removal-condition comment are both gone, not just the conditional, leaving no stale prose explaining a branch that no longer exists. The unconditional `exit 1` is now the step's sole terminal branch. `scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs` asserts over comment-stripped content that no `$RUN_EVENT`-keyed early exit or warn-instead-of-fail annotation survives, proven fail-first against the pre-deletion workflow and green after, with a negative-control fixture reintroducing the branch, and a separate assertion that the unrelated `BOUNDARY WITH PHASE 231 (GATE-03)` note survives byte-unchanged.
- **`MAINTAINING.md` residual 4 reconciled.** Rewritten from "that leniency is removed when Phase 231's GATE-01 lands" (a forward commitment) into a past-tense record citing the measured nightly (run `30425416933`, 23/25 green, the only two reds being this same phase's own already-fixed GATE-02/GATE-04 defects) as the evidence that justified the removal, and naming `p16` as the regression guard. The five ruleset-required check-name strings at `:104-110` are confirmed byte-unchanged (`git diff MAINTAINING.md` shows exactly one hunk, at `:262-269`).
- **The publisher-red todo's wrong hypothesis corrected on the record.** Moved from pending to resolved, status flipped, and a Resolution section appended stating plainly that "real spec drift" was never the cause — the actual cause was unseeded demo data starving the admin users index of pagination, cited against scheduled run `30432494488` and its three checkpoint-project failures at `admin-checkpoints.spec.ts:230`, with the `continue-on-error` option the todo had floated correctly noted as never applied (unnecessary and forbidden by 230's D-15).
- **D-17 judged on a real run, not the diff.** Dispatched `Playwright reports (GitHub Pages)` on the phase branch (`workflow_dispatch`, ref `worktree-discuss-231`, commit `8e9e7839`) → run `30529885885`, job `90829454715`, concluded `success`. The checkpoint step (`admin-checkpoints-chromium`, `-mobile`, `-dark`) reported `1 flaky / 2 passed (3.2m)` — the one flake was `admin-checkpoints-mobile`'s first attempt timing out on `waitForLiveViewReady` after 60s (a known-class first-load timing issue, unrelated to seeding, matching the pattern already filed in `.planning/todos/resolved/2026-07-04-admin-eval-first-nav-flake.md`), which passed cleanly on Playwright's own retry #1. Critically, **zero** failures were the pagination assertion that failed on scheduled run `30432494488` — confirming D-17's diagnosis and fix directly.
- **D-18 diagnosed precisely and filed as a standing/backstop obligation, not guessed at.** The dispatched run's `Publish to gh-pages branch` and `Point GitHub Pages at gh-pages (REST API)` steps both concluded `skipped` (confirmed via `gh api .../actions/jobs/90829454715`), because both are hard-gated on `github.ref == 'refs/heads/main'` and the dispatch ran on `worktree-discuss-231`. This is a genuine structural finding, not an oversight: `workflow_dispatch` always resolves the workflow definition from the dispatched ref, so dispatching from `main` would run main's **pre-fix** copy (still missing the seeds step) and prove nothing new, while dispatching from the phase branch to exercise the fix necessarily fails the `ref == main` gate. No single pre-merge dispatch can satisfy both. `gh api repos/szTheory/sigra/pages` was re-read immediately after the run and confirmed unchanged (`source: {"branch": "main", "path": "/"}`). The new todo (`.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`) states this precisely — not "confirmed did not self-heal," which would overclaim a test that never ran — and gives exact post-merge verification steps (watch the PR's own merge-triggered push, or the next `45 6 * * *` schedule run) plus both of D-18's candidate root causes (insufficient `GITHUB_TOKEN` scope vs. a Settings-level block), left open rather than guessed at, per D-18's explicit scope fence (repo-admin, out of this phase).
- **`ci-gate` confirmed green at the final commit.** PR #125's synchronize run (`30530864192`, commit `19d99d65`) shows `ci-gate` job conclusion `success`, with every lane either `success` or a legitimately-gated `skipped` on a `pull_request` event (`Passkeys manual fallback smoke`, `Install matrix`, `Passkeys opt-out smoke`, `Nightly probe`, `Upgrade smoke`, `Admin eval render + probe`, both recapture lanes, and `Notify on red ci-gate` — all Tier-A/B/C lanes documented as pull_request-demoted, none rotted). Prohibition 5 (do not break ci-gate) holds.

## Task Commits

1. **Task 1: Seed the Pages publisher before it boots, and guard it (D-17)** — `df52e6d5` (feat)
2. **[Correction] Include the todo resolution content omitted from Task 1's staging** — `702eeffa` (fix) — see Deviations
3. **Task 2: Remove the schedule-lane leniency from the demotion receipt, and guard it (D-19)** — `8e9e7839` (feat)
4. **Task 3: Observe the publisher on a real dispatched run, and answer D-18's self-heal question** — `19d99d65` (docs)

## Files Created/Modified

- `.github/workflows/playwright-github-pages.yml` — `Run demo seeds` step added between `Setup example dev DB` and `Install Playwright deps` (i.e. strictly before `Boot example app in background`), unconditional, with an explanatory comment recording why it was copied from the unguarded variant.
- `.github/workflows/ci-observe.yml` — the schedule-lane leniency block deleted (`:123-136` corrected span); `exit 1` is now the `Verdict` step's sole terminal branch.
- `MAINTAINING.md` — residual 4 rewritten past-tense, citing run `30425416933` and `p16` as the regression guard; the five required-check strings at `:104-110` untouched.
- `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` — new, 4 tests, proven fail-first.
- `scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs` — new, 4 tests, proven fail-first.
- `.planning/todos/resolved/2026-07-27-playwright-github-pages-publisher-red.md` — moved from pending, status flipped, Resolution section appended.
- `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` — new, D-18's diagnosis, owner (repo admin), and post-merge verification steps.

## Decisions Made

See `key-decisions` in frontmatter. In full:

1. **D-18 filed as a standing/backstop obligation, not a confirmed failure.** The live dispatch proved the self-heal script structurally cannot run pre-merge (hard-gated to `github.ref == 'refs/heads/main'`, unsatisfiable together with the fix before this PR merges) — a more precise finding than the plan's binary "self-healed / did-not-self-heal" framing anticipated. The todo states this precisely rather than forcing the observation into either bucket.
2. **A staging-omission correction commit (`702eeffa`) rather than an amend.** Task 1's `git mv` staged the todo rename, but the subsequent content edits (status flip, Resolution section) were made without re-staging before that commit, so they landed as a small dedicated follow-up commit instead of being folded backward or bleeding into Task 2's unrelated commit.
3. **GATE-01 left Pending in REQUIREMENTS.md.** Its literal text requires observing an actual `schedule`-triggered nightly, which this plan cannot force forward. Plan 231-11 owns that final observation per CONTEXT's own sequencing (D-24, Flagged Planner Assumption A3).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a staging omission in Task 1's own commit before it could compound.**
- **Found during:** preparing Task 2's `git add`, when `git status` unexpectedly showed the already-committed resolved todo file as modified again.
- **Issue:** `git mv .../pending/... .../resolved/...` staged the rename, but the two subsequent `Edit` calls (frontmatter status flip, appended Resolution section) modified the file on top of that staged rename without a re-`git add` before Task 1's `git commit`. Task 1's commit therefore captured only the bare 100%-identical rename; the actual resolution content was left unstaged.
- **Fix:** Committed the content separately (`702eeffa`) before starting Task 2's changes, so Task 1's full deliverable (the corrected record) lives in its own commit rather than silently merging into Task 2's D-19 work.
- **Files modified:** `.planning/todos/resolved/2026-07-27-playwright-github-pages-publisher-red.md`.
- **Commit:** `702eeffa`

**2. [Rule 1 - Bug] Corrected a false "Phase 231 Complete" auto-computation in ROADMAP.md.**
- **Found during:** the state-update step, after `gsd_run query roadmap.update-plan-progress "231"` ran.
- **Issue:** the tool counts `summary_count` by globbing `*-SUMMARY.md` files in the phase directory and compares it against `plan_count` (globbed `*-PLAN.md` files). The phase directory carries an extra, unplanned `231-GAP-GATE02-SUMMARY.md` (from an earlier gap-closure pass) that has no corresponding `*-PLAN.md`. With this plan's `231-10-SUMMARY.md` now present, the raw counts coincidentally both equal 11 (11 `*-PLAN.md` files 01-11, and 11 `*-SUMMARY.md` files 01-10 plus the GAP one) even though `231-11-PLAN.md` has not been executed and carries no summary at all — the tool wrote "11/11, Complete, 2026-07-30" into ROADMAP.md's progress table.
- **Fix:** manually corrected the table row back to "10/11, In Progress" (blank Completed date), reflecting the true state — `231-11-PLAN.md` is still outstanding. The `- [x] 231-10-PLAN.md` checkbox line elsewhere in ROADMAP.md is correct as tool-written and was left alone.
- **Files modified:** `.planning/ROADMAP.md`.
- **Commit:** part of this plan's final metadata commit (below).

**3. [Rule 1 - Bug] The same over-counting propagated into `STATE.md` via `state.advance-plan` / `state.update-progress` — corrected.**
- **Found during:** reviewing `git diff .planning/STATE.md` after the state-update step.
- **Issue:** `state.advance-plan` dropped the `current_phase: 231` frontmatter key entirely, and `state.update-progress` (driven by the same phase-directory summary/plan glob mismatch as the ROADMAP tool above) wrote `completed_phases: 2` (should stay `1` — Phase 231 is not done), `completed_plans: 20` (should be `19` — 9 from Phase 230 plus 10 completed 231 plans, not 11), `percent: 33` (should be `17`, matching `completed_phases/total_phases`), and the body's `Progress: 100%` bar (should reflect 10-of-11 plans in Phase 231, not a false 100%).
- **Fix:** restored `current_phase: 231`; corrected `completed_phases` to `1`, `completed_plans` to `19`, `percent` to `17`; set the body progress bar to `91%` (10/11 plans in Phase 231 complete), replacing the false `100%`.
- **Files modified:** `.planning/STATE.md`.
- **Commit:** part of this plan's final metadata commit (below).

No other deviations. All declared-fence files were touched and no others; `git diff --stat HEAD -- .github scripts MAINTAINING.md` was confirmed empty for Task 3 as its acceptance criterion requires.

## Issues Encountered

None beyond the staging omission documented above (caught and fixed before Task 2 began).

## User Setup Required

None — no external service configuration required. `gh` was already authenticated as `szTheory` with `workflow` scope, sufficient to dispatch `workflow_dispatch` runs. D-18's eventual resolution (if the self-heal does not fire once observable) may require a repo-admin Settings → Pages change, which is explicitly out of this phase's scope per D-18's fence.

## PRs Closed

None. No `github-actions`-spawned recapture PRs were produced by this plan's single dispatch (`gh pr list --state open` confirmed only the three pre-existing PRs: #125 phase PR, #124 docs/230-phase-complete, #122 release-please — untouched).

## Next Phase Readiness

- **GATE-01's structural half is genuinely closed.** Both defects that were "genuinely its own" (D-17, D-19) are fixed, guarded, and proven on live evidence. D-18 is diagnosed precisely and filed with exact post-merge verification steps rather than guessed at.
- **`ci-gate` is confirmed green at branch HEAD** (`19d99d65`) — plan 231-11 can build on this branch without `ci-gate` being broken for it.
- **Plan 231-11 owns GATE-01's final closure**: the actual nightly observation (SC-1) after this phase merges, per CONTEXT's D-24 sequencing and Flagged Planner Assumption A3.
- **The new D-18 todo is a live, actionable backstop**, not a dead-letter finding: it names the exact first observable event (this PR's own merge-triggered push, or the next `45 6 * * *` schedule run) and the exact commands to run against it.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Verification Evidence (actually run)

### Task 1 — p15 fail-first observation (verbatim)

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs
not ok 2 - a demo-seeds step exists, unconditional, strictly between DB setup and app boot
  error: |-
    no step invokes priv/repo/seeds.exs — the publisher boots the app without seeding it, which
    is exactly how scheduled run 30432494488 failed (admin users index never paginates, the
    checkpoint spec's next-page link never renders)
# tests 4
# pass 3
# fail 1
```

### Task 1 — p15 green after the fix, plus full suite and actionlint

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs
# tests 4
# pass 4
# fail 0

$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 62
# pass 62
# fail 0

$ actionlint -shellcheck= .github/workflows/playwright-github-pages.yml
(exit 0, no output)

$ python3 -c "...YAML-parse assertion..."
OK Setup example dev DB -> Run demo seeds -> Install Playwright deps

$ python3 -c "...env-key comparison against admin_eval_render's seeds step..."
env keys MATCH: {'MIX_ENV': 'dev', 'PGUSER': 'postgres', 'PGPASSWORD': 'postgres', 'PGHOST': 'localhost'}
```

### Task 1 — todo resolution

```
$ test ! -f .planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md && echo "pending: gone OK"
pending: gone OK
$ test -f .planning/todos/resolved/2026-07-27-playwright-github-pages-publisher-red.md && echo "resolved: exists OK"
resolved: exists OK
```

### Task 2 — p16 fail-first observation (verbatim)

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs
not ok 2 - no trigger-dependent early exit and no warn-instead-of-fail branch survives
  error: |-
    the warn-instead-of-fail annotation string ("::warning::Demotion receipt FAILED") survives —
    a demoted construct can silently stop executing on the nightly while the receipt merely warns
    instead of failing
# tests 4
# pass 3
# fail 1
```

### Task 2 — p16 green after the deletion, plus full suite, actionlint, and MAINTAINING.md checks

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs
# tests 4
# pass 4
# fail 0

$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 66
# pass 66
# fail 0

$ actionlint -shellcheck= .github/workflows/ci-observe.yml
(exit 0, no output)

$ python3 -c "...comment-stripped RUN_EVENT/exit-1/BOUNDARY assertion..."
OK

$ python3 -c "...MAINTAINING.md residual-4 future-commitment check..."
OK

$ git diff MAINTAINING.md | grep -n "^@@"
5:@@ -264,9 +264,14 @@ treated as "unchanged coverage" -- each is disclosed here with its backstop and
```
(single hunk, confirming `:104-110`'s five required-check strings are byte-unchanged)

### Task 3 — dispatched publisher run

```
$ gh workflow run "Playwright reports (GitHub Pages)" --repo szTheory/sigra --ref worktree-discuss-231
https://github.com/szTheory/sigra/actions/runs/30529885885
```

**Run `30529885885`** (`workflow_dispatch`, ref `worktree-discuss-231`, commit `8e9e7839`), job `90829454715` (`Publish Playwright site`), **conclusion `success`**:

```
Run admin behavior browser truth (chromium): 5 passed (1.3m)

Run admin checkpoints (chromium, mobile, dark-chromium):
  ✓  [admin-checkpoints-chromium] captures curated admin review pages across desktop/mobile/dark (37.4s)
  ✘  [admin-checkpoints-mobile]   captures curated admin review pages across desktop/mobile/dark (1.0m)
       Test timeout of 60000ms exceeded.
       Error: page.waitForSelector: Test timeout of 60000ms exceeded.
         - waiting for locator('[data-phx-session].phx-connected')
         at waitForLiveViewReady (admin-checkpoints.spec.ts:44:14)
  ✓  [admin-checkpoints-mobile]   captures curated admin review pages across desktop/mobile/dark (retry #1) (49.9s)
  ✓  [admin-checkpoints-dark]     captures curated admin review pages across desktop/mobile/dark (37.3s)
  1 flaky
  2 passed (3.2m)

Run non-admin example browser smoke: 12 passed (2.6m)
```

**Zero failures at the assertion that failed on scheduled run `30432494488`** (`admin-checkpoints.spec.ts:230`, the `getByRole('link', { name: 'Next page' })` pagination assertion) — the only failure observed is an unrelated first-load `waitForLiveViewReady` timeout on the mobile project's first attempt, which passed cleanly on Playwright's own retry. D-17's fix is confirmed working on a real run, not just the diff.

### Task 3 — D-18 self-heal observation

```
$ gh api repos/szTheory/sigra/actions/jobs/90829454715 --jq '.steps[] | select(.name | test("Publish to gh-pages|Point GitHub Pages")) | {name, status, conclusion}'
{"conclusion":"skipped","name":"Publish to gh-pages branch","status":"completed"}
{"conclusion":"skipped","name":"Point GitHub Pages at gh-pages (REST API)","status":"completed"}
```

Both skipped because `github.ref` (`refs/heads/worktree-discuss-231`) does not equal `refs/heads/main` — the exact structural gate documented in the new todo, not a run failure.

```
$ gh api repos/szTheory/sigra/pages
{"build_type":"legacy","source":{"branch":"main","path":"/"},"html_url":"https://sztheory.github.io/sigra/", ...}
```

Live Pages source confirmed unchanged immediately after the run — consistent with the ensure-script never having had the opportunity to run.

### Task 3 — plan verify block and scope check

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 66
# pass 66
# fail 0

$ actionlint -shellcheck= .github/workflows/playwright-github-pages.yml .github/workflows/ci-observe.yml
(exit 0, no output)

$ gh --version >/dev/null && echo "gh OK"
gh OK

$ python3 -c "...seeds step present at receipt time..."
publisher wiring intact; the deliverable is the dispatched-run receipt asserted below

$ git diff --stat HEAD -- .github scripts MAINTAINING.md
(empty)
```

### Prohibition 5 — ci-gate confirmed green at final commit

```
$ gh run view 30530864192 --repo szTheory/sigra --json conclusion,jobs -q '{conclusion, ci_gate_conclusion: (.jobs[] | select(.name=="ci-gate") | .conclusion)}'
{"conclusion":"success","ci_gate_conclusion":"success"}
```

PR #125 synchronize run at commit `19d99d65` (all three task commits) — every lane `success` or legitimately-gated `skipped` on `pull_request`.

### Open PRs check (Operational note — none to close)

```
$ gh pr list --repo szTheory/sigra --state open --json number,title,headRefName,baseRefName
[#125 worktree-discuss-231 -> main, #124 docs/230-phase-complete -> main, #122 release-please--branches--main -> main]
```

No `github-actions`-spawned recapture PRs were produced by this plan's single dispatch.

## Self-Check: PASSED

- FOUND: `.github/workflows/playwright-github-pages.yml` — `Run demo seeds` step present, unconditional, correctly ordered
- FOUND: `.github/workflows/ci-observe.yml` — schedule-lane leniency block absent, `exit 1` sole terminal branch, boundary note intact
- FOUND: `MAINTAINING.md` — residual 4 past-tense, required-check strings untouched
- FOUND: `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` — 4/4 passing
- FOUND: `scripts/ci/prohibitions/p16-no-schedule-lane-leniency.test.mjs` — 4/4 passing
- FOUND: `.planning/todos/resolved/2026-07-27-playwright-github-pages-publisher-red.md` — resolved, Resolution section present
- FOUND: `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
- FOUND commit: `df52e6d5`
- FOUND commit: `702eeffa`
- FOUND commit: `8e9e7839`
- FOUND commit: `19d99d65`
- CONFIRMED: run `30529885885` — job `90829454715`, conclusion `success`
- CONFIRMED: run `30530864192` — `ci-gate` job conclusion `success`
- CONFIRMED: `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 66/66 passing locally
- CONFIRMED: `actionlint -shellcheck= .github/workflows/playwright-github-pages.yml .github/workflows/ci-observe.yml` — exit 0
- CONFIRMED: no open recapture PRs to close
