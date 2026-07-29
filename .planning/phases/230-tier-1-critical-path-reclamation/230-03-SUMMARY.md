---
phase: 230-tier-1-critical-path-reclamation
plan: 03
subsystem: ci
tags: [ci, playwright, ci.yml, aggregator, snapshot-recapture]

# Dependency graph
requires:
  - phase: 230-01
    provides: "scripts/ci/ci-run-metrics.sh (not consumed directly by this plan, wave-order dependency only)"
  - phase: 230-02
    provides: "The @snapshot grep seam in admin-design.spec.ts (28 tagged board tests, 13 untagged tests, 1 untagged full-page axe test per design project)"
provides:
  - "PR lane design_gallery step filtered to --grep-invert '@snapshot' (39 executed tests per project)"
  - "Event-gated design_gallery_snapshots step running --grep '@snapshot' on push/schedule/dispatch (84 executed tests per project), in-job so a regression still reds the ruleset-required Example Playwright smoke context"
  - "design_gallery_snapshots wired into the seam-outcome aggregator (D-05 hard-fail boundary)"
  - "ExUnit static contract pinning the recapture-lane-stays-ungrepped and aggregator-enumerates-every-seam invariants"
affects: [230-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CLI-only Playwright filtering (--grep-invert on the PR step, --grep on the event-gated sibling) — never playwright.config.ts grepInvert, which would also filter the ungrepped recapture invocations"
    - "job-region extraction via File.read! + regex (no YAML parser) in the phase_153_infra_stability_contract_test.exs idiom, extended here to job-body slicing between top-level job-id lines"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/sigra/planning/phase_230_design_gallery_split_test.exs

key-decisions:
  - "Filtering is CLI-only on both gallery steps (D-03); test/example/priv/playwright/playwright.config.ts is byte-unchanged, confirmed by git diff --quiet in both Task 1's automated verify and by the recapture-lane ExUnit test"
  - "The new step lives inside example_playwright_smoke rather than a new job, because the job name \"Example Playwright smoke (full lifecycle)\" is a ruleset-14941512 required context (D-04) — an in-job snapshot regression on push to main still reds a hard gate"
  - "design_gallery_snapshots was added to the seam-outcome aggregator's hard-coded outcome list (D-05), not left to the step's own if:, because the aggregator loop — not the step guard — is what decides whether a failure reaches the required context"
  - "Split the two-hunk ci.yml diff into two separate commits (Task 1: filter + new step; Task 2: aggregator wiring) by isolating each hunk with awk and applying them sequentially, so each task's atomic commit maps 1:1 to its own verification"

requirements-completed: [FAST-02]

coverage:
  - id: T1
    description: "The design_gallery step is filtered to --grep-invert '@snapshot' and a new design_gallery_snapshots step runs --grep '@snapshot', gated to github.event_name != 'pull_request', positioned immediately after design_gallery"
    requirement: "FAST-02"
    verification:
      - kind: unit
        ref: "actionlint -shellcheck= .github/workflows/ci.yml && python3 YAML-structure assertions (step order, --grep-invert/--grep presence, if: guards, --project= counts) => OK"
        status: pass
      - kind: unit
        ref: "git diff --quiet -- test/example/priv/playwright/playwright.config.ts => exit 0 (byte-unchanged)"
        status: pass
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --grep-invert '@snapshot' --list => Total: 39 tests"
        status: pass
      - kind: e2e
        ref: "npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --grep '@snapshot' --list => Total: 84 tests"
        status: pass
    human_judgment: false
  - id: T2
    description: "design_gallery_snapshots is added to the seam-outcome aggregator's hard-coded outcome list; the aggregator still keys only on the literal 'failure' and stays if: always()"
    requirement: "FAST-02"
    verification:
      - kind: unit
        ref: "python3 assertion: all six seam ids (admin_behavior, admin_checkpoints, design_gallery, design_gallery_snapshots, non_admin_smoke, demo_showcase) present as steps.<id>.outcome in the aggregator run: block => OK all seams aggregated"
        status: pass
      - kind: unit
        ref: "python3 assertion: aggregator step's if == 'always()' => agg if OK"
        status: pass
    human_judgment: false
  - id: T3
    description: "Three new ExUnit tests mechanically enforce the recapture-lane-stays-ungrepped and every-seam-aggregated invariants, with confirmed-firing regression guards"
    requirement: "FAST-02"
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_230_design_gallery_split_test.exs => 8 tests, 0 failures"
        status: pass
      - kind: unit
        ref: "manual regression: temporarily inserting --grep '@snapshot' into admin_design_recapture's invocation fails the ungrepped-recapture test with the Pitfall-1 hazard message; file restored, suite green again"
        status: pass
      - kind: unit
        ref: "manual regression: temporarily removing steps.design_gallery_snapshots.outcome from the aggregator loop fails the aggregator test with the silently-discarded-failure hazard message; file restored, suite green again"
        status: pass
      - kind: unit
        ref: "grep -c 'YamlElixir\\|:yaml' test/sigra/planning/phase_230_design_gallery_split_test.exs => 0"
        status: pass
    human_judgment: false

# Metrics
duration: ~20min
completed: 2026-07-28
status: complete
---

# Phase 230 Plan 03: Design Gallery CI Wiring (PR Filter + Event-Gated Snapshot Step) Summary

**Wired `ci.yml` so the PR lane's `design_gallery` step runs only the 39 accessibility/behaviour tests (`--grep-invert '@snapshot'`) while a new `design_gallery_snapshots` step runs the 84 pixel-diff board tests on push/schedule/dispatch, in-job so a regression still reds the ruleset-required "Example Playwright smoke (full lifecycle)" context — proven locally by Playwright `--list` reporting exactly 39 and 84, and pinned by three new ExUnit contract tests whose regression guards were manually confirmed to fire.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-28
- **Tasks:** 3 completed
- **Files modified:** 2

## Accomplishments

- Appended `--grep-invert '@snapshot'` to the existing `design_gallery` step's `run:` block, filtering the PR lane to the 39 accessibility and behaviour tests introduced by plan 230-02's split.
- Added a new `design_gallery_snapshots` step immediately after it — `id: design_gallery_snapshots`, `if: ${{ !cancelled() && github.event_name != 'pull_request' }}`, `--grep '@snapshot'` — running the 84 per-board pixel-diff assertions on push, schedule, and `workflow_dispatch` only. The step stays inside `example_playwright_smoke` (not a new job) so a push-to-main snapshot regression still reds the ruleset-14941512 required context (D-04).
- Wired `steps.design_gallery_snapshots.outcome` into the seam-outcome aggregator's hard-coded loop (D-05), preserving the aggregator's skip-tolerant `if [ "$o" = "failure" ]` test and its `if: always()` guard, so a snapshot regression on a non-PR run cannot be silently discarded.
- Confirmed `test/example/priv/playwright/playwright.config.ts` stays byte-unchanged (`git diff --quiet` exits 0) — the filtering is expressed entirely as CLI flags on the two `ci.yml` steps, per D-03.
- Confirmed locally via `npx playwright test ... --list` that the filtered invocation reports exactly 39 tests and the snapshot invocation reports exactly 84 tests across the three design projects, matching the plan's must-have counts.
- Extended `Sigra.Planning.Phase230DesignGallerySplitTest` with three tests: the `admin_design_recapture` job and `scripts/ci/snapshot-recapture-gate.sh`'s design-gallery block stay ungrepped; the PR lane carries `--grep-invert` and the new step carries `github.event_name != 'pull_request'`; the aggregator enumerates all six seam ids. Manually verified both hazard-guarding assertions fire with the correct message when the underlying invariant is broken, then restored the file to green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Filter the PR gallery step and add the event-gated snapshot step** - `09858548` (feat)
2. **Task 2: Add the new step id to the seam-outcome aggregator (D-05 hard-fail boundary)** - `f907f6a3` (fix)
3. **Task 3: Pin the recapture-lane and aggregator invariants in the phase contract test** - `de47dbd1` (test)

## Files Created/Modified

- `.github/workflows/ci.yml` - Filtered `design_gallery`'s invocation with `--grep-invert '@snapshot'`; added the `design_gallery_snapshots` step gated to non-PR events; added `steps.design_gallery_snapshots.outcome` to the aggregator's hard-coded outcome list
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` - Added a job-region extraction helper plus three tests pinning the recapture-lane-stays-ungrepped and every-seam-aggregated invariants

## Decisions Made

- Split the two-hunk `ci.yml` diff into two atomic commits by isolating each hunk (awk-splitting a single `git diff` into per-hunk patch files, then `git checkout` + `git apply` + commit sequentially) so Task 1's commit contains only the filter/new-step change and Task 2's commit contains only the aggregator wiring — each maps 1:1 to its own `<verify>` block.
- Reused the `phase_153_infra_stability_contract_test.exs` `File.read!` + regex idiom rather than introducing a YAML parser; extended it with a small job-region extraction helper (`extract_job/2`) that slices between top-level `<job_id>:` lines so the new tests scope their assertions to the correct job/step region instead of matching anywhere in the 2,300+ line file.
- Confirmed both new regression-guarding assertions (ungrepped-recapture, aggregator-enumerates-every-seam) actually fire on the hazard they name, per the plan's acceptance criteria — not just that the happy-path assertions pass — by temporarily reintroducing each hazard, running the test file, and restoring.

## Deviations from Plan

None — plan executed exactly as written. The only implementation choice not dictated by the plan (Claude's Discretion: commit/plan decomposition) was resolved by splitting `ci.yml`'s diff into two hunks so each task's commit is scoped to exactly what its own `<verify>` block checks.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The `ci.yml` wiring is in place and locally proven via `actionlint`, YAML-structure assertions, and Playwright `--list` counts (39 filtered / 84 snapshot). The live-CI executed-test-count proof (AFTER-PR: 39 executed + snapshot step skipped; AFTER-PUSH/dispatch: 84 executed and hard-fail capable; AFTER-PUSH admin_design_recapture: 123 executed) is explicitly deferred to plan 09 per this plan's own text and the phase-wide D-24 proof-discipline rule — this plan's job was the wiring and its local/static verification, not the observed-run capture.
- `230-EVIDENCE.md`'s AFTER slots for this plan's contribution remain pending; plan 09 is responsible for populating them.
- `test/sigra/planning/phase_230_design_gallery_split_test.exs` now guards both silent-failure modes this plan could have introduced (a grepped recapture lane, an unaggregated seam) on every `mix test` run.

## Self-Check: PASSED

- FOUND: `.github/workflows/ci.yml`
- FOUND: `test/sigra/planning/phase_230_design_gallery_split_test.exs`
- FOUND commit `09858548` (Task 1)
- FOUND commit `f907f6a3` (Task 2)
- FOUND commit `de47dbd1` (Task 3)

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-28*
