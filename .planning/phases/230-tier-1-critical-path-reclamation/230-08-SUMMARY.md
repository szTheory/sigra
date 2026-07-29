---
phase: 230-tier-1-critical-path-reclamation
plan: 08
subsystem: docs
tags: [ci, maintaining, honest-skip-set, accepted-residuals, ci.yml]

# Dependency graph
requires:
  - phase: 230-03
    provides: "design_gallery / design_gallery_snapshots split, aggregator wiring (FAST-02)"
  - phase: 230-04
    provides: "admin_eval_render non-PR demotion, concurrency block (FAST-03/FAST-04)"
  - phase: 230-05
    provides: "changes job, docs_only step/job-level gating, aggregator docs-only line (FAST-05)"
  - phase: 230-06
    provides: "Playwright browser cache (FAST-06, no honest-skip-set entry — a speedup, not a skip)"
  - phase: 230-07
    provides: "timeout-minutes on all 22 jobs (FAST-07, no honest-skip-set entry)"
provides:
  - "MAINTAINING.md '### Honest-skip set after Phase 230 (v1.47 FAST-02/FAST-03/FAST-05)' — three-tier enumeration (pre-existing event-gated, newly event-gated, newly diff-gated) of every construct that legitimately skips on a PR after this phase, each with its literal ci.yml condition"
  - "MAINTAINING.md '#### Accepted residuals introduced by Phase 230' — two numbered disclosures (per-board axe attribution loss, docs-only PR asserting nothing) each with backstop and recovery route"
affects: [231-gate-03, 231-gate-05, 235-fast-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Durable maintainer-facing artifact (MAINTAINING.md) extended in-place rather than a phase SUMMARY, because phase directories archive at milestone close while downstream gates (231's GATE-03/GATE-05) need the list live"
    - "Verify-against-shipped-state discipline: the same command that reads the doc section also yaml.safe_load()s ci.yml and asserts each named construct's literal condition, so the artifact cannot describe intent divorced from the committed workflow"

key-files:
  created: []
  modified:
    - MAINTAINING.md

key-decisions:
  - "Split the two-hunk MAINTAINING.md diff into two atomic commits (Task 1: honest-skip set tiers; Task 2: accepted residuals) by reverting the combined edit and reapplying each hunk separately, so each task's commit maps 1:1 to its own <verify> block — same technique 230-03 used for its ci.yml diff."
  - "Placed the new '#### Accepted residuals introduced by Phase 230' subsection before the pre-existing '#### Accepted residuals (D-07 honest-truth disclosure)' subsection, per the plan's literal instruction that it sit 'immediately after the honest-skip set' — the D-07 section (Phase 196 residuals) now reads second, unchanged."
  - "Followed the plan's explicit instruction to cite 230-EVIDENCE.md for the SC-2 restatement pointer, even though ROADMAP.md itself points to 230-VALIDATION.md — the plan's <action> text is authoritative for this artifact's cross-references."

requirements-completed: [FAST-02, FAST-03, FAST-05]

coverage:
  - id: T1
    description: "Enumerate the post-phase honest-skip set (Tier A pre-existing, Tier B event-gated new, Tier C diff-gated new) in a new MAINTAINING.md subsection, verified against shipped ci.yml"
    requirement: "FAST-02, FAST-03, FAST-05"
    verification:
      - kind: other
        ref: "python3 assertion script parsing MAINTAINING.md section text + yaml.safe_load(ci.yml) confirming admin_eval_render.if, example_playwright_smoke step id design_gallery_snapshots, and library_tests_dep_off.if contain docs_only => OK"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/ => 54 tests, 0 failures, 12 skipped (baseline match)"
        status: pass
    human_judgment: false
  - id: T2
    description: "Record the two accepted residuals (per-board axe attribution, docs-only Playwright no-assertion) with backstop and recovery route, positioned after the honest-skip set"
    requirement: "FAST-02, FAST-03, FAST-05"
    verification:
      - kind: other
        ref: "python3 assertion script confirming required tokens present and section ordering (honest-skip set index < residuals index) => OK; grep -q 'AxeBuilder' test/example/priv/playwright/tests/admin-generated.spec.ts => found"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/planning/ => 54 tests, 0 failures, 12 skipped (baseline match)"
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-07-29
status: complete
---

# Phase 230 Plan 08: Honest-Skip-Set Documentation Summary

**`MAINTAINING.md` now carries a durable, verified-against-shipped-`ci.yml` three-tier enumeration of every construct that legitimately skips on a pull request after Phase 230, plus the two coverage-loss disclosures this phase introduces — living where Phase 231's GATE-03 and Phase 235's GATE-05 can find it after phase directories archive at milestone close.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-29
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `### Honest-skip set after Phase 230 (v1.47 FAST-02/FAST-03/FAST-05)` to `MAINTAINING.md`'s CI cadence section, immediately after the existing Phase 196 enumeration. Three tiers:
  - **Tier A — event-gated, pre-existing (Phase 196):** carries forward `install_matrix`, `upgrade_smoke`, `passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke`, `generated_admin_playwright_smoke`, `nightly_probe`, the two recapture lanes, and `notify_release_lane_rot`, deferring to the section above as authority.
  - **Tier B — event-gated, added by Phase 230:** `admin_eval_render` (`if: github.event_name != 'pull_request'`) and the `design_gallery_snapshots` step inside `example_playwright_smoke`, each with its literal condition, `ci-gate.needs`/ruleset-context status, and aggregator-wiring note.
  - **Tier C — diff-gated (docs-only), added by Phase 230:** the heavy steps of the four app-behaviour required lanes (step-level `docs_only` guard) and the whole `library_tests_dep_off` job (job-level guard), with the fail-open polarity stated in words and `fast_checks`/`library_tests`/`library_tests_shard` named as deliberately exempt (their guards and 13 ExUnit files read `.planning/**` and `guides/**`).
  - Cross-references `230-EVIDENCE.md` for the observed-run evidence backing each claim.
- Added `#### Accepted residuals introduced by Phase 230`, positioned immediately after the honest-skip set and before the pre-existing D-07 residuals subsection:
  1. **Per-board axe failure attribution** — lost by the design-gallery axe/snapshot collapse (D-01). Backstop: DOM selectors in axe violation output. Recovery route: the element-scoped `AxeBuilder(...).include(selector)` pattern already proven at `admin-generated.spec.ts:160-163`.
  2. **A docs-only PR's Playwright required context asserts nothing** — the seam-outcome aggregator's explicit docs-only log line is the backstop; the boundary condition (Markdown/`.planning/` only) and evidence status (classifier self-tested in-phase, end-to-end run is a post-merge `AFTER-DOCSONLY` obligation) are both stated.
  - Plus a one-line pointer that ROADMAP.md's SC-2 wording is superseded by the operative restatement in `230-EVIDENCE.md`.
- Both new sections verified against the shipped `ci.yml` by parsing the workflow with `yaml.safe_load` in the same command that reads the doc text — no entry describes an intention absent from the committed workflow.

## Task Commits

Each task was committed atomically:

1. **Task 1: Enumerate the post-phase honest-skip set in MAINTAINING.md** - `f32f3afd` (docs)
2. **Task 2: Record the two accepted residuals this phase creates** - `fbb2f512` (docs)

_No TDD tasks in this plan._

## Files Created/Modified

- `MAINTAINING.md` - Added `### Honest-skip set after Phase 230 (v1.47 FAST-02/FAST-03/FAST-05)` (three tiers, fail-open polarity, not-skipped note, evidence pointer) and `#### Accepted residuals introduced by Phase 230` (two numbered residuals + SC-2 pointer), both inside the existing CI cadence section, before the pre-existing D-07 residuals subsection.

## Decisions Made

- Split the single conceptual edit into two atomic commits by reverting the combined change (`git checkout -- MAINTAINING.md`) and reapplying each task's hunk separately, so each commit's diff maps exactly to its own `<verify>` block — the same technique used in plan 230-03 for its two-hunk `ci.yml` diff.
- Followed the plan's literal placement instruction: the new residuals subsection sits before the pre-existing D-07 residuals subsection, not after, so a reader encounters both accepted-residuals subsections back-to-back immediately following the honest-skip set.
- Cited `230-EVIDENCE.md` (not `230-VALIDATION.md`) for the SC-2 pointer per the plan's explicit `<action>` text, even though `ROADMAP.md` itself points to `230-VALIDATION.md` for the same claim — the plan's instruction is authoritative for what this artifact cross-references.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' automated `<verify>` commands (Python assertions parsing `MAINTAINING.md` plus `yaml.safe_load(ci.yml)`, and the `AxeBuilder` grep) passed on the first attempt, and `mix test test/sigra/planning/` matched the documented baseline (54 tests, 0 failures, 12 skipped) after each task.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The honest-skip set and its accepted residuals are now durable and verified-against-shipped-state, ready for Phase 231's GATE-03 (auditing skips against this enumerated baseline) and GATE-04 (which this doc explicitly defers `admin_eval_render`'s `continue-on-error` fix to), and Phase 235's GATE-05 (before/after coverage inventory).
- This plan touched only `MAINTAINING.md` — no `ci.yml` edits, consistent with the plan's scope boundary (`files_modified: [MAINTAINING.md]`).
- Plan 230-09 (the phase's remaining evidence-capture plan) is unblocked; nothing in this plan introduces a new evidence obligation beyond what plans 230-03 through 230-07 already deferred to it.

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-29*

## Self-Check: PASSED

- FOUND: MAINTAINING.md
- FOUND: .planning/phases/230-tier-1-critical-path-reclamation/230-08-SUMMARY.md
- FOUND: f32f3afd (Task 1 commit)
- FOUND: fbb2f512 (Task 2 commit)
- FOUND: 700c6788 (SUMMARY commit)
