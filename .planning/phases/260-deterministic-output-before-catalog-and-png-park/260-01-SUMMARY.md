---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 01
subsystem: ci
tags: [github-actions, playwright, png-compare, park-pr, contract-test, bgen-06]

requires:
  - phase: 259
    provides: milestone branch and ADR 005 (brand adoption compatibility policy, decision 7)
provides:
  - "Local branch ci/park-png-compare, cut from origin/main, holding the PNG-compare park (not pushed, not merged)"
  - "SIGRA_PNG_COMPARE_SKIP env switch on exactly three Playwright shard steps (1 off dispatch, 0 on dispatch; unset compares)"
  - "Sigra.Planning.Phase260PngParkContractTest pinning the switch, the spec guards, compare-on elsewhere, required names and the canary"
  - "MAINTAINING.md paragraph 'PNG compare switch' with the four release_ref_guard dispatch shapes"
affects: [260-04, 260-11, 261]

actuals:
  tokens: 5278
  tasks: 3
  commits: 4

plan_head_before: 4cf5829eaa96973c064b9b32a215439ae200cf42
plan_head_after: 5e351ebea0890136f0fa945ec2e225266a2172da

tech-stack:
  added: []
  patterns:
    - "Comparison-level park: explicit env skip switch with default-on compare, instead of demoting whole lanes"
    - "String-contract test over ci.yml and Playwright specs with a pure compare_gated?/2 and planted-source controls"

key-files:
  created:
    - test/sigra/planning/phase_260_png_park_contract_test.exs
  modified:
    - .github/workflows/ci.yml
    - MAINTAINING.md
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
    - test/example/priv/playwright/tests/demo-showcase.spec.ts
    - test/example/priv/playwright/tests/admin-design.spec.ts

key-decisions:
  - "Owner chose author-first-option-a: author the park now (wave 1) as an independent branch off origin/main, comparison-level skip, default-on compare"
  - "Skip implemented as an early return after the axe scan (additive diff) rather than wrapping the screenshot call in an if block"
  - "playwright-github-pages.yml deliberately left unedited (RESEARCH Open Question 4 recommended a flag there); the red-after-Phase-261 cost is documented in MAINTAINING.md"
  - "Park branch upstream tracking unset after worktree creation so a stray git push cannot target main"

patterns-established:
  - "Park switch polarity: SIGRA_PNG_COMPARE_SKIP=1 skips only toHaveScreenshot; a forgotten setter fails loud (compares) rather than silently green"
  - "Every skipped compare is visible: png-compare annotation (checkpoints, demo) or Playwright skipped (28 @snapshot boards)"

requirements-completed: [BGEN-06]

coverage:
  - id: D1
    description: "SIGRA_PNG_COMPARE_SKIP is set through env on exactly the three PNG-comparing shard steps (Run admin checkpoints, Run design gallery behavior and snapshots, Run demo showcase) with no if: edited and never inside run:"
    requirement: BGEN-06
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_260_png_park_contract_test.exs#admin_checkpoints lane (tracer) / demo_showcase and design_gallery @snapshot lanes (expansion)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Specs gate only the compare: assertCheckpointScreenshot and assertDemoScreenshot skip toHaveScreenshot after the axe scan, the 28 @snapshot board tests test.skip, the loop shape and demo behavior tests are unchanged"
    requirement: BGEN-06
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_260_png_park_contract_test.exs#compare_gated?/2 positive controls + spec assertions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both recapture jobs, run-playwright-drift.sh, snapshot-recapture-gate.sh and playwright-github-pages.yml are unedited and keep comparing (switch unset means compare)"
    requirement: BGEN-06
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_260_png_park_contract_test.exs#compare stays on where the switch is not set"
        status: pass
    human_judgment: false
  - id: D4
    description: "Five ruleset-required job names, if: predicates, ci-skip-manifest.tsv, spec-ownership.json and the canary guard in fast_checks are unchanged; every pre-existing demotion guard (phase_230, phase_234, 93 prohibition tests, observer self-test) stays green"
    requirement: BGEN-06
    verification:
      - kind: integration
        ref: "mix test phase_260 + phase_230 + phase_234 (31 tests); node --test scripts/ci/prohibitions/*.test.mjs (93 pass); bash scripts/ci/ci-demotion-observer.test.sh (19 passed)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The park actually skips PNG compare on live PR and push runs and still compares on dispatch and in the recapture jobs"
    requirement: BGEN-06
    verification: []
    human_judgment: true
    rationale: "Live GitHub Actions runtime behavior. Playwright browsers and the example app are not run in this plan; plan 04 owns the live positive control and the owner-approved push and merge."

duration: 11min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 01: PNG Compare Park Summary

**Comparison-level PNG park on a local branch off origin/main: an explicit `SIGRA_PNG_COMPARE_SKIP` env switch on the three Playwright shard steps (axe and behavior keep running, unset means compare), pinned by a 17-test contract test with planted controls.**

## Performance

- **Duration:** about 11 min
- **Started:** about 2026-11-15T17:56Z (reconstructed from the plan-ledger file time; PLAN_START_TIME was not captured at start)
- **Completed:** 2026-11-15T18:07Z
- **Tasks:** 3 (Task 0 owner decision, Task 1 tracer, Task 2 expansion)
- **Files modified:** 6 (1 created, 5 modified), all on the park branch

## Accomplishments

- Worktree `../sigra-park-png-compare` on branch `ci/park-png-compare`, cut from the already-fetched `origin/main` (`4cf5829ea`, no fetch), HEAD verified equal to `git rev-parse origin/main`.
- `SIGRA_PNG_COMPARE_SKIP: ${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}` added to the `env:` map of exactly three steps; `ci.yml` diff is 6 insertions, 0 deletions (3 env lines plus 3 one-line comments), no `if:` or `name:` touched.
- `assertCheckpointScreenshot` and `assertDemoScreenshot` keep their axe scan / behavior and return early (with a `png-compare` annotation per skipped slug) before `toHaveScreenshot`; the 28 `@snapshot` board tests call `test.skip(skipPngCompare, ...)` first so Playwright reports skipped. Board loop header and test declaration prefix are byte-identical.
- `MAINTAINING.md` paragraph "PNG compare switch" documents polarity, the skip visibility, the four `release_ref_guard` dispatch shapes (read from the live guard step), the Pages-workflow caveat and the never-allowlisted canary.
- Nothing under `lib/` or `priv/` changed, no PNG touched, no workflow added, nothing pushed or merged.

## Task Commits

All on branch `ci/park-png-compare` in the worktree (base `4cf5829ea`, tip `5e351ebea`):

1. **Task 0: owner decision** - no commit (owner replied in chat to take the recommendation, resume signal `author-first-option-a`)
2. **Task 1: tracer, admin_checkpoints lane**
   - RED `3827d04cd` (test)
   - GREEN `827c04c8e` (feat)
3. **Task 2: demo_showcase + design_gallery @snapshot, docs, guards**
   - RED `3dc1d1ee7` (test)
   - GREEN `5e351ebea` (feat)

**Plan metadata:** docs commit on the milestone branch (SUMMARY, STATE, ROADMAP).

No REFACTOR commits. The red test commits may be squashed away by the owner at merge (the plan allows it).

## TDD Gate Compliance

RED then GREEN is present for both tasks (`test(260-01)` precedes `feat(260-01)`). `workflow.tdd_mode` is not enabled and ExUnit console output is not one of the report formats `gsd_run check tdd-red-evidence` classifies, so no classifier record was produced; the semantic assessment below stands in and is not a classifier verdict.

**Task 1 RED** (untouched worktree, `mix test test/sigra/planning/phase_260_png_park_contract_test.exs`, exit 2, `8 tests, 2 failures`):

- `Run admin checkpoints passes the skip switch through env only` failed on `` `Run admin checkpoints` must set SIGRA_PNG_COMPARE_SKIP: ... in its env: map ``.
- `assertCheckpointScreenshot keeps axe and parks only the toHaveScreenshot compare` failed on `admin-checkpoints.spec.ts must declare skipPngCompare at module scope`.
- The 6 `compare_gated?/2` control tests passed (including the planted unconditional-compare source returning false).
- Semantic assessment: both targets executed and failed on exactly the planned assertion for the planned reason (the switch and guard do not exist yet). No compile, load, zero-test or fixture fault.

**Task 2 RED** (`17 tests, 5 failures`): `exactly the three PNG-comparing shard steps carry the switch` (count 1, expected 3), `admin-design ... must declare skipPngCompare`, `MAINTAINING ... match failed (nil)`, `Run demo showcase ... must set SIGRA_PNG_COMPARE_SKIP`, `assertDemoScreenshot ... must declare skipPngCompare`. The other 12 tests passed because they pin facts that already hold (five required names, canary reference, recapture jobs and Pages workflow unset, untagged axe test, tracer tests, controls). Semantic assessment: each of the 5 failures is the planned missing behavior, not an error.

**Real-file positive controls** (each observed red, then restored with `git checkout -- <file>`): changing the checkpoints guard to `if (false)` failed the gating test; deleting the env line from `Run demo showcase` failed 2 tests.

## Files Created/Modified

- `test/sigra/planning/phase_260_png_park_contract_test.exs` - 17 string-contract tests, `extract_job/2` (copied), `extract_step/2`, `compare_gated?/2` with planted-source controls
- `.github/workflows/ci.yml` - switch on three shard steps (+6 lines)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` - `skipPngCompare` const, early return plus annotation after the axe scan
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` - same in `assertDemoScreenshot` (`_testInfo` renamed to `testInfo`)
- `test/example/priv/playwright/tests/admin-design.spec.ts` - `skipPngCompare` const, `test.skip(...)` first in the `@snapshot` board callback
- `MAINTAINING.md` - "PNG compare switch" paragraph (+24 lines)

## Decisions Made

- **Option A, author first, default-on compare** (owner decision, chat reply). It departs from the literal wording of ADR 005 decision 7 ("demote PNG-compare lanes to dispatch", "at the end of Phase 260"): the lanes stay, only the comparison is skipped, and the park is authored in wave 1.
- Early return after the axe scan instead of wrapping the screenshot call: same semantics, additive diff, tolerance numbers untouched.
- `playwright-github-pages.yml` left unedited on purpose (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

None. No bug, missing-critical or blocking fix was needed.

### Implementation choices that differ from the plan's literal wording

**1. Early return instead of "wrap" the screenshot call** (Tasks 1, 2). The plan said wrap only `toHaveScreenshot` so it runs when `skipPngCompare` is false. An `if (skipPngCompare) { annotate; return; }` placed after the axe scan has identical runtime effect and keeps the diff purely additive. `compare_gated?/2` accepts both shapes.

**2. Double-quoted constant in `demo-showcase.spec.ts`.** That file uses double quotes throughout, so the constant is `=== "1"` there and `=== '1'` in the other two specs. The contract regex accepts either quote style.

**3. One-line YAML comment above each env line** (3 extra `ci.yml` lines, total +6, inside the plan's 12-line budget), so the park is explained at the point of use.

**4. Extra contract assertions beyond the plan's list**: exactly-three-settings count, the PR-lane `Run design gallery behavior` step stays unparked, drift/gate scripts and the Pages workflow do not mention the switch, and the MAINTAINING paragraph mentions the switch, `release_ref_guard`, `phase_244_final_main`, `recapture_branch`, the Pages workflow and the canary guard. All inside the one new test file.

**5. Upstream tracking removed from the park branch.** `git worktree add -b ci/park-png-compare ... origin/main` auto-set the upstream to `origin/main`; I ran `git branch --unset-upstream` so an accidental `git push` cannot target main. Plan 04 must push with an explicit refspec.

**6. RESEARCH Open Question 4 declined on purpose** (also stated in the plan objective): no flag added to `playwright-github-pages.yml`. With default-on compare an unset switch compares, so that workflow keeps comparing with no edit; the cost is a red, non-required Pages run after Phase 261 until baselines are recaptured, documented in MAINTAINING.md.

**Total deviations:** 0 auto-fixed, 6 documented choices. **Impact on plan:** none on scope or acceptance criteria; all acceptance criteria met.

## Issues Encountered

- `node --check` cannot parse the `.ts` specs (inline `type` import modifiers); syntax was verified with `node:module` `stripTypeScriptTypes` instead. Playwright is not installed locally (no `node_modules`), so the specs were not executed; their runtime behavior is covered by the contract test plus Playwright's documented `test.skip(condition, description)` semantics, and the live proof is plan 04's.
- The first `node --test ... | grep '# tests'` printed nothing (the spec reporter prints `ℹ tests 93`, not TAP); re-run showed 93 pass, 0 fail across 19 files. Recorded as a false-negative caught by reading the summary line.
- A broader ripple run of every test that reads `ci.yml`, `ci-skip-manifest` or `MAINTAINING.md`: 141 tests, 0 failures, 8 skipped (pre-existing skips).
- `evaluation-scope --commits-only` run on the milestone branch will not see the four production commits: they live on `ci/park-png-compare` by this plan's own isolation design, not on the milestone branch. The measured ledger (below) is the authoritative commit count.

## Authentication Gates

None.

## Known Stubs

None. The 28 `test.skip` board tests are the designed park, not a defect; they run wherever the switch is `0` or unset.

## Threat Flags

None. The only new surface is one env expression over `github.event_name`, passed through `env:` and never inside `run:` (T-260-03, asserted by the contract test).

## Verification Run (inside the worktree)

| Check | Result |
| --- | --- |
| `mix test` phase_260 + phase_230 + phase_234 contracts | 31 tests, 0 failures |
| `node --test scripts/ci/prohibitions/*.test.mjs` | 93 pass, 0 fail (19 files) |
| `bash scripts/ci/ci-demotion-observer.test.sh` | 19 passed, 0 failed |
| `mix format --check-formatted` | OK |
| `git diff --name-only origin/main` | exactly the 6 planned paths |
| `git diff origin/main -- lib priv` | empty |
| `git diff origin/main` on manifest tsv, `spec-ownership.json`, Pages workflow | empty |
| PNG files in the diff | none |
| `git ls-remote --heads origin ci/park-png-compare` | nothing (not pushed) |

Commit ledger (measured from the persisted base, per-plan file in the worktree git dir): `plan_head_before` `4cf5829eaa96973c064b9b32a215439ae200cf42`, `plan_head_after` `5e351ebea0890136f0fa945ec2e225266a2172da`, `git rev-list --count` = 4. `actuals.tokens` is chars/4 over the added diff lines (21,113 bytes / 4 = 5,278), against a plan estimate of 30,000; not rounded toward the estimate.

## Handoff for Plan 04 and Plan 11

- Branch `ci/park-png-compare`, worktree `../sigra-park-png-compare` (relative to the repo root), tip `5e351ebea`, working tree clean, no upstream, never pushed. Deps are fetched and `MIX_ENV=test` is compiled in the worktree; use `source tmp/db.env` from the milestone checkout for Postgres.
- Plan 04 owns the live positive control (PR run shows PNG compare skipped, a dispatch compares) and the owner-approved push and merge; push with an explicit refspec.
- **Plan 11 follow-up:** append a dated note to ADR 005 recording that the park was authored first (Phase 260 wave 1) and that the mechanism is comparison-level skip (Option A, default-on compare), which departs from the literal decision-7 wording ("demote lanes to dispatch", "at the end of Phase 260").
- Merging this park changes what the required `Example Playwright smoke (full lifecycle)` check measures for every later PR; that merge stays gated on plain-chat owner approval.

## Next Phase Readiness

Ready for the rest of Wave 1 (260-02, 260-03) and, after them, plan 04. The park is authored and locally verified but unmerged, so Phase 261 must not start until plan 04 lands it.

## Self-Check: PASSED

- Created and modified files exist in the worktree (checked with `[ -f ]`): contract test, `ci.yml`, `MAINTAINING.md`, three specs.
- Commits `3827d04cd`, `827c04c8e`, `3dc1d1ee7`, `5e351ebea` are ancestors of `ci/park-png-compare`.
- All Task 1 and Task 2 acceptance criteria re-run and passing (branch, merge-base, lib/priv empty, six paths, `.github` +6/-0 on `ci.yml` only, frozen files empty, no PNG, three switch settings, clean worktree, not pushed).
- Plan-level verification re-run after the last restore: green.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
