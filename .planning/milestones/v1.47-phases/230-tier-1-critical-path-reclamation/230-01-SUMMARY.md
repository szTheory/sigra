---
phase: 230-tier-1-critical-path-reclamation
plan: 01
subsystem: infra
tags: [ci, github-actions, gh-cli, jq, bash, measurement]

# Dependency graph
requires: []
provides:
  - "scripts/ci/ci-run-metrics.sh — committed CI wall-clock / per-job measurement instrument (D-21), single-run `--jobs <id>` mode and windowed `--limit`/`--mode wall|jobspan` baseline-reproduction mode"
  - "scripts/ci/ci-run-metrics.test.sh — hermetic self-test (9 test groups), wired into `fast_checks`"
  - ".planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md — the phase's observed-run evidence ledger, BEFORE-PR and BEFORE-PUSH captured, six AFTER slots pending as addressable sections"
affects: [230-02, 230-03, 230-04, 230-05, 230-06, 230-07, 230-08, 230-09, 235]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "jq `fromdate` for all duration math (never shell `date -d`/`date -j`) — portable across macOS dev and ubuntu-latest CI without a GNU-vs-BSD date branch"
    - "PATH-shadowed recording `gh` stub for hermetic self-tests (copied from notify-failure-issue.test.sh), extended here with a run-id-keyed lookup table for per-run `gh run view` fixtures"
    - "p50 defined once, in the script header, as sort-ascending 0-based index floor(n/2) — never left ambiguous"

key-files:
  created:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
    - .planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "D-21 satisfied: the measurement script and its hermetic self-test are committed and wired into fast_checks before any other plan in Phase 230 measures anything."
  - "All duration arithmetic uses jq's fromdate on gh's ISO8601 Z-suffixed timestamps, not shell date parsing — avoids the GNU date -d / BSD date -j incompatibility between local macOS dev and CI's ubuntu-latest."
  - "Window mode's gh run list call adds databaseId to RESEARCH's literal reconstructed field list (event,createdAt,updatedAt,conclusion) — required so --mode jobspan can do its per-run gh run view follow-up sweep; wall mode's output is unaffected by the added field."

requirements-completed: [SC-5]

coverage:
  - id: D1
    description: "Single-run measurement mode (`--jobs <run_id>`) implemented, wired into fast_checks, and verified against the real pre-change PR run 30390832059"
    requirement: SC-5
    verification:
      - kind: unit
        ref: "scripts/ci/ci-run-metrics.test.sh — Test A/B/C, D, E, F, G, H"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/ci-run-metrics.sh --jobs 30390832059 (live gh call against real run)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Windowed baseline-reproduction mode (--limit/--since/--event/--mode wall|jobspan) reproducing REQUIREMENTS.md:9-13's exact column shape"
    requirement: SC-5
    verification:
      - kind: unit
        ref: "scripts/ci/ci-run-metrics.test.sh — Test I/J, K, L"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/ci-run-metrics.sh --limit 40 --format table (live; max values match REQUIREMENTS.md:9-13 exactly)"
        status: pass
    human_judgment: false
  - id: D3
    description: "230-EVIDENCE.md evidence ledger opened with BEFORE-PR (run 30390832059) and BEFORE-PUSH (run 30389700235) captured, all eight slots addressable"
    requirement: SC-5
    verification:
      - kind: other
        ref: "python3 slot/status/command structural check (plan 230-01 Task 3 <verify>)"
        status: pass
    human_judgment: false

# Metrics
duration: 13min
completed: 2026-07-28
status: complete
---

# Phase 230 Plan 01: D-21 Measurement Instrument + Evidence Ledger Summary

**Committed `ci-run-metrics.sh` (single-run + windowed `gh`-backed CI measurement, hermetic self-test wired into `fast_checks`) and opened `230-EVIDENCE.md` with both BEFORE observed-run slots captured — the D-21 ordering constraint that every other Phase 230 plan's proof runs through.**

## Performance

- **Duration:** ~13 min (task work; first task commit 2026-07-28T23:42:10Z, last 2026-07-28T23:54:38Z)
- **Started:** 2026-07-28T23:42:10Z
- **Completed:** 2026-07-28T23:54:38Z
- **Tasks:** 3/3
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- `scripts/ci/ci-run-metrics.sh` — the single script every wall-clock / per-job claim in Phase 230 (and Phase 235's FAST-01 verdict) must be produced by. Two modes: `--jobs <run_id>` for a per-job breakdown of one run, and windowed `--limit`/`--since`/`--event`/`--mode wall|jobspan`/`--format table|json` reproducing REQUIREMENTS.md:9-13's baseline table shape exactly.
- `scripts/ci/ci-run-metrics.test.sh` — 9 hermetic test groups (no network, no `GH_TOKEN`) pinning: the per-job table shape, the `admin_eval_render` failure/1053s/17m33s row not being filtered by conclusion, negative-duration clamping to 0, unknown-flag exit 2 with zero `gh` invocations, `gh`-absent / non-zero-exit / empty-list fail-closed paths, `--format json` parity, the exact window-mode header string, the p50 index rule pinned against both an odd-length (n=5) and even-length (n=4) canned window, and `--mode jobspan` reading strictly lower than `--mode wall` on the identical canned window.
- Wired the self-test into `fast_checks` as `CI run metrics self-test`, before the `actions/setup-node` boundary.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` — the phase's real gate. BEFORE-PR (run `30390832059`) and BEFORE-PUSH (run `30389700235`) captured with verbatim `ci-run-metrics.sh` output; all eight slots (including the two planning-added ones, AFTER-NONPR and AFTER-PR-WARM) structured as addressable `## <SLOT>` sections with `Status:` lines; AFTER-PUSH and AFTER-DOCSONLY explicitly labelled post-merge obligations with their post-merge capture commands and one-sentence reasons.
- Restated SC-2 verbatim in the ledger, citing the six skipped-not-absent jobs observed on run `30390832059`.

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end per-run measurement — one path, `--jobs <run_id>`, wired and self-tested** - `667025de` (feat)
2. **Task 2: Expand to the windowed baseline-reproduction mode** - `7d701693` (feat)
3. **Task 3: Open the observed-run evidence ledger with both BEFORE slots** - `24633cbd` (docs)

**Plan metadata:** pending (this commit)

## Files Created/Modified

- `scripts/ci/ci-run-metrics.sh` - single-run (`--jobs`) and windowed (`--limit`/`--since`/`--event`/`--mode`) CI measurement instrument
- `scripts/ci/ci-run-metrics.test.sh` - hermetic self-test, 9 test groups, PATH-shadowed `gh` stub
- `.github/workflows/ci.yml` - adds `CI run metrics self-test` step to `fast_checks`, before the `actions/setup-node` boundary
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` - the phase's observed-run evidence ledger

## Decisions Made

- Used `jq`'s `fromdate` for every duration computation instead of shell `date -d`/`date -j` — the local dev environment (macOS/BSD `date`) and CI (`ubuntu-latest`/GNU `date`) have incompatible flag syntax; `jq` is identical on both and matches the reconstructed baseline method in `230-RESEARCH.md`.
- Added `databaseId` to the `gh run list --json` field list beyond RESEARCH's literal reconstructed command (`event,createdAt,updatedAt,conclusion`) — required so `--mode jobspan`'s per-run `gh run view` sweep has a run ID to call against. Wall mode's output shape and values are unaffected.
- p50 is defined once, in the script's header comment, as sort-ascending 0-based index `floor(n/2)` — matches D-21's explicit requirement that an undefined p50 never be left to silent reinterpretation.

## Deviations from Plan

None - plan executed exactly as written. The two implementation choices above (jq for date math, the added `databaseId` field) were necessary means to the plan's explicit ends (cross-platform correctness; `--mode jobspan` requires per-run IDs) and fall within "Claude's Discretion" per `230-CONTEXT.md` ("measurement script's path/flags").

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The D-21 ordering constraint is satisfied: `ci-run-metrics.sh` and its self-test are committed and wired into `fast_checks` before any subsequent Phase 230 plan measures anything.
- `230-EVIDENCE.md` exists with both BEFORE slots captured and all six AFTER slots enumerated as addressable, pending sections with their capture commands — plans 02-09 fill AFTER-PR, AFTER-PR-WARM, AFTER-NONPR, and AFTER-CANCEL from the phase's own PR/branch runs; AFTER-PUSH and AFTER-DOCSONLY remain post-merge obligations by design.
- No blockers for wave 2 (plans 02-08, the FAST-02..07 implementation plans) or plan 09 (the phase's verification/AFTER-slot fill).

---
*Phase: 230-tier-1-critical-path-reclamation*
*Completed: 2026-07-28*

## Self-Check: PASSED

- FOUND: `scripts/ci/ci-run-metrics.sh`
- FOUND: `scripts/ci/ci-run-metrics.test.sh`
- FOUND: `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md`
- FOUND: `.planning/phases/230-tier-1-critical-path-reclamation/230-01-SUMMARY.md`
- FOUND: commit `667025de`
- FOUND: commit `7d701693`
- FOUND: commit `24633cbd`
- FOUND: commit `ba849610`
