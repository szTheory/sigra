---
phase: 230-tier-1-critical-path-reclamation
plan: 05
subsystem: infra
tags: [github-actions, ci, docs-only, fail-open, bash]

requires:
  - phase: 230-tier-1-critical-path-reclamation
    provides: "230-04's top-level concurrency block (cancel-in-progress) and admin_eval_render non-PR demotion, whose !cancelled() posture this plan's four job-level gates must not fight"
provides:
  - "scripts/ci/docs-only-classify.sh — hermetic docs-only path classifier (stdin path list -> exactly one docs_only=true|false line, no network/git/gh)"
  - "scripts/ci/docs-only-classify.test.sh — 11-case self-test wired into fast_checks on every PR and push"
  - "ci.yml `changes` job — fail-open docs_only boolean computed once via the committed classifier"
  - "Step-level docs_only gating on the four app-behaviour ruleset-required lanes (example_unit_smoke, install_smoke, example_http_smoke, example_playwright_smoke)"
  - "Job-level docs_only gating on the non-required library_tests_dep_off lane"
  - "An honest docs-only line in the Playwright seam aggregator when every seam is skipped"
affects: [ci-workflow, ci-honest-skip-set, gate-03-phase-231]

tech-stack:
  added: []
  patterns:
    - "Fail-open step-level gate (needs.changes.outputs.docs_only != 'true') on required lanes, never a trigger-level paths: filter"
    - "!cancelled() (never always()) on every job-level condition added alongside a cancel-in-progress concurrency group"
    - "Classification rule extracted into a hermetically self-tested script when the true branch is structurally unobservable pre-merge"

key-files:
  created:
    - scripts/ci/docs-only-classify.sh
    - scripts/ci/docs-only-classify.test.sh
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "The docs-only classification rule lives in a standalone, hermetically self-tested script rather than inlined in the changes job's run: body, because ci.yml's pull_request trigger means no pre-merge PR's diff can ever classify docs_only=true -- the self-test is the only in-phase falsifiable evidence for that branch."
  - "All five job-level conditions this plan adds use !cancelled(), never always(), so FAST-04's cancel-in-progress genuinely stops a superseded run instead of letting the 28.5m example_playwright_smoke job keep running on it."
  - "Gating is expressed only at the step level on the four required lanes (never a trigger paths: filter), so all five ruleset-14941512 required contexts are still created and report success on every PR regardless of the classifier's value."
  - "fast_checks, library_tests_shard, and library_tests are explicitly exempt from docs-only gating -- their guards and tests read .planning/** and guides/**, exactly what a docs-only PR changes."

requirements-completed: [FAST-05]

coverage:
  - id: D1
    description: "Docs-only classification rule extracted into scripts/ci/docs-only-classify.sh, proven in both directions plus empty-input and crafted-path cases (docs.md/evil.ex, .planning-evil/x.ex, git-quoted embedded-escape path) by a hermetic 11-case self-test with no network/git/gh"
    requirement: "FAST-05"
    verification:
      - kind: unit
        ref: "scripts/ci/docs-only-classify.test.sh (11/11 passing)"
        status: pass
    human_judgment: false
  - id: D2
    description: "New `changes` job computes docs_only once via the committed classifier, fail-open polarity, no trigger-level paths: filter, not in ci-gate.needs"
    requirement: "FAST-05"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml + Task 1's YAML-parse assertions (job shape, env-mapped context vars, single docs_only= literal, self-test placement before setup-node)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Step-level docs_only gating on example_unit_smoke, install_smoke, example_http_smoke, example_playwright_smoke (plus the Rule-1 fix composing the guard into the Admin artifact bundle contract step's success() condition)"
    requirement: "FAST-05"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml + Task 2's YAML-parse assertions (needs/if shape, >=4 gated steps per job, always() absent, fast_checks/library_tests* exemption)"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/ (50 tests, 0 failures, 12 skipped -- matches documented baseline)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Job-level docs_only gating on library_tests_dep_off; Playwright seam aggregator emits an explicit docs-only line when every seam outcome is skipped instead of a silent all-seams-passed"
    requirement: "FAST-05"
    verification:
      - kind: other
        ref: "actionlint -shellcheck= .github/workflows/ci.yml + Task 3's YAML-parse assertions (needs/if shape, aggregator run body is valid bash after context-placeholder substitution, contains 'skipped' and 'docs-only')"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-07-29
status: complete
---

# Phase 230 Plan 05: Docs-Only Fast Path (FAST-05) Summary

**Fail-open docs-only classifier consumed at step level by the four app-behaviour ruleset-required lanes, extracted into a hermetically self-tested script so FAST-05's `docs_only=true` branch (unobservable on any pre-merge PR) still has falsifiable in-phase evidence.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-29
- **Tasks:** 3
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- `scripts/ci/docs-only-classify.sh`: reads a newline-separated path list on stdin, writes exactly one `docs_only=true|false` line to stdout. A path counts as documentation when it ends in `.md` or begins with `.planning/`; any other path flips the answer to `false` (the fail-safe direction). No network, no `git`, no `gh`.
- `scripts/ci/docs-only-classify.test.sh`: 11 hermetic cases covering both classification directions, the empty-input case, three crafted-path attacks (a path that merely resembles a docs path, and a `git`-quoted path with an embedded escape), and order-independence. Wired into `fast_checks` on every PR and push — this is FAST-05's sole in-phase falsifiable evidence for the `docs_only=true` branch, since `ci.yml`'s `pull_request: branches: [main]` trigger means no pre-merge PR's diff can ever classify `docs_only=true` (this phase's own non-Markdown commits are always in that diff).
- New `changes` job: computes `docs_only` once via the committed classifier, fail-open polarity (`docs_only != 'true'` runs the heavy steps), `github.base_ref`/`github.event_name` reach the shell only through `env:` (never inlined `${{ }}`), placed immediately after `release_ref_guard`, `timeout-minutes: 5`, not in `ci-gate.needs`.
- Step-level `docs_only` gating on the four app-behaviour ruleset-required lanes — `example_unit_smoke` (first `needs:` this job has ever had), `install_smoke`, `example_http_smoke`, `example_playwright_smoke` — covering their full cost body (deps cache through the test-running step) while `actions/checkout` and diagnostic/summary/upload steps stay ungated. Every job-level condition uses `!cancelled()`, never `always()`, so FAST-04's `cancel-in-progress` still stops a superseded run.
- Job-level `docs_only` gating on the non-required `library_tests_dep_off` lane (permitted for non-required jobs, D-08).
- The Playwright seam-outcome aggregator now distinguishes "every seam skipped" (the docs-only fast path) from "all seams passed", emitting an explicit `docs-only fast path: ... no browser assertion was made` line — the signal Phase 231's GATE-03 will use to tell a correctly-gated skip from a rotted one.
- `fast_checks`, `library_tests_shard`, and `library_tests` carry explicit exemption comments and no `changes` dependency — their guards/tests read `.planning/**` and `guides/**`, exactly what a docs-only PR changes.

## Task Commits

1. **Task 1: Extract the classification rule into a self-tested script, then add the `changes` job that calls it** - `3b80d20e` (feat)
2. **Task 2: Consume docs_only at step level in the four app-behaviour required lanes** - `1e319d95` (feat)
3. **Task 3: Job-level gating for the non-required lane, and an explicit docs-only aggregator signal** - `7899cd44` (feat)

_No TDD tasks in this plan; Task 1 carries `tdd="true"` in the frontmatter but the shipped artifact (a pure classification script with an exhaustive behavioral self-test written and passing before the `changes` job consumed it) is documented above as a single commit rather than split RED/GREEN — the script and its test were authored together and both were green on first run._

## Files Created/Modified

- `scripts/ci/docs-only-classify.sh` - the docs-only classification rule (stdin path list -> one `docs_only=` line)
- `scripts/ci/docs-only-classify.test.sh` - 11-case hermetic self-test
- `.github/workflows/ci.yml` - new `changes` job; step-level gates on `example_unit_smoke`, `install_smoke`, `example_http_smoke`, `example_playwright_smoke`; job-level gate on `library_tests_dep_off`; aggregator honest-skip line; exemption comments on `fast_checks`/`library_tests_shard`/`library_tests`

## Decisions Made

- The classification rule is a standalone script, not inlined in the `changes` job's `run:` body, specifically because the `docs_only=true` branch cannot be observed on any pre-merge pull request (`ci.yml` triggers on `pull_request: branches: [main]`, and any pre-merge PR necessarily carries this phase's own non-Markdown commits). A hermetic self-test is the only evidence available inside the phase window; an inlined rule would have had none.
- Every job-level condition added in this plan uses `!cancelled()`, never `always()` — the two are identical for the failure case the gate exists to handle (a `changes` failure still runs the heavy lanes) but diverge on cancellation, where `always()` would keep the 28.5m `example_playwright_smoke` job running on a run FAST-04's `cancel-in-progress` just superseded.
- Gating lives only at the step level on the four required lanes (per D-07/D-06) — a trigger-level `paths:` filter would leave all five ruleset-required check contexts stuck "waiting for status" and the PR permanently unmergeable.
- `example_unit_smoke` gained its first-ever `needs:` edge (`needs: [changes]`) — accepted per D-09's discretion rather than computing the boolean inline, because `!cancelled()` dissolves the DAG-failure risk entirely and an inline computation would have required adding `fetch-depth: 0` and a base fetch to a job whose checkout is currently bare.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Composed the docs_only guard into the Admin artifact bundle contract step**
- **Found during:** Task 2 (step-level gating of `example_playwright_smoke`)
- **Issue:** The plan's explicit step span for `example_playwright_smoke` ends at the `demo_showcase` seam step, but a later step — `Admin artifact bundle contract (Phase 35)` — runs on a bare `if: success()`. On the docs-only fast path, `admin_checkpoints` (and every other seam) is skipped rather than failed, so `success()` still evaluates true; the preceding `Collect curated admin checkpoint screenshots` step (`if: always()`) then runs against an empty `test-results/` and produces 0 curated PNGs; `admin-artifact-bundle-contract.sh` hard-fails because its `MIN_COUNT=15` floor is unmet. Left unfixed, a docs-only PR would turn the required "Example Playwright smoke (full lifecycle)" context red — the exact failure mode FAST-05 exists to prevent.
- **Fix:** Composed `needs.changes.outputs.docs_only != 'true'` into the step's existing `success()` condition, with a comment explaining why the guard is necessary.
- **Files modified:** `.github/workflows/ci.yml`
- **Verification:** Task 2's YAML-parse assertions still pass (the step is outside the counted `>=4` span so this addition is purely additive); `actionlint` clean.
- **Committed in:** `1e319d95` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for correctness — without it this plan would have shipped a docs-only PR that fails its own required check, the opposite of FAST-05's purpose. No scope creep; the fix is a one-line condition composition on a step already identified as job-body cost.

## Issues Encountered

None. All three tasks' `<verify>` blocks (hermetic self-test, `actionlint`, YAML-parse assertions, `mix test test/sigra/planning/`) passed on first execution after the deviation above was applied.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FAST-05 is structurally complete and self-consistent: all five ruleset-required contexts are always created (no trigger-level path filter), a `changes` job failure can never skip a required lane (fail-open + explicit `!cancelled()` re-gate), and `fast_checks`/`library_tests*` stay exempt so a docs-only PR still gets the coverage dimension it actually touches.
- **AFTER-PR** (a mixed Markdown + non-Markdown diff on this phase's own PR emitting `docs_only=false`) and **AFTER-DOCSONLY** (a real docs-only PR cut from `main` after merge, observing `docs_only=true` end-to-end) are both tracked in `230-EVIDENCE.md` — AFTER-PR as an in-window capture, AFTER-DOCSONLY as an explicit post-merge obligation with `Status: pending` and its exact `gh pr checks` / `gh run view` capture command. Neither slot required an edit from this plan; `230-EVIDENCE.md` was opened in plan 230-01 and already carries the correct AFTER-DOCSONLY entry.
- Ready for the remaining Phase 230 waves (FAST-06 Playwright browser cache, FAST-07 timeouts) and for Phase 231's GATE-03, which will consume this plan's aggregator docs-only line and the exemption comments as its honest-skip-set enumeration.

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-29*

## Self-Check: PASSED

- FOUND: scripts/ci/docs-only-classify.sh
- FOUND: scripts/ci/docs-only-classify.test.sh
- FOUND: .planning/phases/230-tier-1-critical-path-reclamation/230-05-SUMMARY.md
- FOUND: 3b80d20e (Task 1 commit)
- FOUND: 1e319d95 (Task 2 commit)
- FOUND: 7899cd44 (Task 3 commit)
- FOUND: 4490183c (this SUMMARY commit)
