---
phase: 222-release-lane-hardening-no-silent-rot
plan: 03
subsystem: infra
tags: [ci, github-actions, gh-cli, hex-publish, release-please, maintaining-docs]

requires:
  - phase: 222-release-lane-hardening-no-silent-rot
    provides: "222-02's shared notify-failure-issue.sh + notify_release_lane_rot / notify-release-failure consumer jobs and the release-lane-rot tracking-issue label they open"
provides:
  - "HARD-02 readiness evidence: a real hex-publish.yml dry_run=true CI run against the already-shipped tag v1.3.0, proving the publish path (compile + Postgres-backed mix test + mix hex.build --unpack + mix hex.publish --dry-run) is green with every Hex-write step skipped"
  - "MAINTAINING.md ### Release-lane rot signals & recovery (HARD-01/HARD-02) subsection documenting the hex-publish.yml manual dispatch command, gate-ci-green timeout diagnosis, the release-lane-rot red-probe pattern, and a cross-reference to the canonical docs/release-runbook-v1-0.md"
  - "4th structural assertion in phase_222_release_lane_hardening_test.exs locking the new runbook subsection's presence, insertion point, and required content"
affects: [223-get-current-on-hex-terminal-currency-proof]

tech-stack:
  added: []
  patterns:
    - "Operator-dispatched CI proof (dry_run=true against an already-shipped tag) substitutes for a throwaway release cut when proving a publish path end-to-end (D-06.1)"
    - "MAINTAINING.md entry-point-index + canonical-doc cross-reference (no matrix duplication) — same pattern as the existing D-14 forced-failure-probe runbook"

key-files:
  created: []
  modified:
    - MAINTAINING.md
    - test/sigra/planning/phase_222_release_lane_hardening_test.exs

key-decisions:
  - "Used the orchestrator-dispatched hex-publish.yml dry_run=true run against v1.3.0 (run URL below) as the single HARD-02 readiness-evidence artifact, rather than re-dispatching — it is idempotency-safe and fully re-runnable, so the same run doubles as the runbook's documented repeatable proof (per 222-RESEARCH.md Finding 3 / D-06.1)."
  - "Inserted the new MAINTAINING.md subsection immediately after the existing 'Recovery / one-off publish:' line, in the D-14 forced-failure-probe copy-paste style, rather than creating a new top-level doc or duplicating the release gate matrix already owned by docs/release-runbook-v1-0.md (D-08 + the file's own anti-duplication guidance)."
  - "Documented that the release-please-side notify-release-failure aggregator has no dedicated force-fail input (unlike ci.yml's force_fail_probe); the red-probe section treats a genuine stalled/failed release as the equivalent real-world proof rather than inventing a synthetic dispatch input not present in the shipped workflow."

requirements-completed: [HARD-02]

coverage:
  - id: D1
    description: "hex-publish.yml dry_run=true run against tag v1.3.0 concluded green with real Publish to Hex + all post-publish verify/evidence steps SKIPPED (no Hex write) — HARD-02 readiness evidence (D-06.1)"
    requirement: "HARD-02"
    verification:
      - kind: other
        ref: "https://github.com/szTheory/sigra/actions/runs/29132375168 (conclusion: success; Compile/Run library tests/Check docs build/Inspect packaged files/Dry run Hex publish all succeeded; Publish to Hex + Verify version on Hex.pm + Verify HexDocs source links + Upload release post-publish evidence all skipped)"
        status: pass
    human_judgment: true
    rationale: "The checkpoint was a blocking human-verify gate whose dispatch and verification were performed and approved by the orchestrator (per the pre-resolved checkpoint evidence in this plan's prompt) prior to this executor session; the run URL and skipped-Hex-write posture are recorded here as the durable evidence trail."
  - id: D2
    description: "MAINTAINING.md documents the hex-publish.yml manual-dispatch runbook (tag/release_version/dry_run inputs, when to use vs auto-publish), gate-ci-green timeout diagnosis + release-lane-rot tracking-issue pointer, red-probe pattern, and cross-reference to docs/release-runbook-v1-0.md without duplicating the release matrix"
    requirement: "HARD-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_222_release_lane_hardening_test.exs#222-04"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-07-11
status: complete
---

# Phase 222 Plan 03: Prove the publish path green and document the recovery runbook Summary

**HARD-02 closed: a real hex-publish.yml dry_run=true run against the already-shipped v1.3.0 tag proved the release-please publish path green with zero Hex writes, and MAINTAINING.md now carries a copy-paste operator runbook for manual dispatch, timeout diagnosis, and red-probing the new loud-failure signal.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-11T00:17:55Z (continues from Plan 02 session; Task 1 checkpoint pre-resolved by orchestrator)
- **Completed:** 2026-07-11T00:31:33Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- **HARD-02 readiness evidence (D-06.1) captured:** `hex-publish.yml` dispatched with `-f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=true` (`gh workflow run "Hex publish (manual recovery)"`) concluded **green** at [run 29132375168](https://github.com/szTheory/sigra/actions/runs/29132375168). Confirmed step posture: compile (warnings-as-errors), Postgres-backed `mix test`, docs build, and package inspection all `success`; `Dry run Hex publish` ran; `Publish to Hex`, `Verify version on Hex.pm`, `Verify HexDocs source links after publish`, and `Upload release post-publish evidence` were all **SKIPPED** — proving the full publish path is green without a real Hex write.
- Added `### Release-lane rot signals & recovery (HARD-01/HARD-02)` to `MAINTAINING.md`, immediately after the existing "Recovery / one-off publish:" line, in the same copy-paste `gh workflow run` style as the D-14 forced-failure-probe runbook. Covers: (1) the `hex-publish.yml` manual dispatch command with `tag`/`release_version`/`dry_run` inputs and when to use it vs release-please auto-publish, (2) how to read a `gate-ci-green` ~30-min timeout and where the `release-lane-rot` tracking Issue (opened by Plan 02's `notify-release-failure`) surfaces the failure, (3) how to red-probe the loud signal mirroring D-14, (4) a cross-reference to the canonical `docs/release-runbook-v1-0.md` — no matrix duplication, no new top-level doc.
- Extended `test/sigra/planning/phase_222_release_lane_hardening_test.exs` with a 4th structural test (`222-04`) asserting the subsection heading, dispatch inputs, `release-lane-rot` reference, correct insertion point (between the Recovery line and the First public launch section), and the canonical cross-reference.

## Task Commits

Each task was committed atomically:

1. **Task 1: Prove the publish path green via hex-publish.yml dry_run=true against v1.3.0** - checkpoint pre-resolved by orchestrator; no repo commit (operator-dispatched CI run, not a repo edit). Evidence: [run 29132375168](https://github.com/szTheory/sigra/actions/runs/29132375168), conclusion `success`.
2. **Task 2: Add the MAINTAINING.md recovery/manual-dispatch runbook subsection + phase_222 structural assertions** - `54fca5a2` (docs)

## Files Created/Modified
- `MAINTAINING.md` - new `### Release-lane rot signals & recovery (HARD-01/HARD-02)` subsection (manual dispatch command, timeout/tracking-issue guidance, red-probe steps, canonical cross-reference)
- `test/sigra/planning/phase_222_release_lane_hardening_test.exs` - added test `222-04` locking the new runbook subsection's presence, content, and insertion point

## Decisions Made
- Treated the orchestrator's already-dispatched and already-verified `hex-publish.yml` dry-run run (29132375168) as the authoritative HARD-02 readiness evidence rather than re-dispatching a second run — the checkpoint is idempotency-safe and fully re-runnable, so no duplicate dispatch was needed.
- Inserted the new subsection at the exact point identified in 222-RESEARCH.md Finding 5 (immediately after the "Recovery / one-off publish:" line, before "## First public launch"), mirroring the existing D-14 runbook's copy-paste style rather than inventing a new documentation pattern.
- Documented the red-probe step honestly: `notify-release-failure` (release-please.yml) has no synthetic force-fail input like `ci.yml`'s `force_fail_probe` — the runbook says so and points to a genuine stalled/failed release as the equivalent proof, rather than fabricating an input that doesn't exist in the shipped workflow.

## Deviations from Plan

None - plan executed exactly as written. Task 1's checkpoint verification was performed by the orchestrator prior to this session per the pre-resolved checkpoint evidence supplied in the plan-execution prompt; this executor recorded that evidence in the SUMMARY and proceeded directly to Task 2.

## Issues Encountered

None. `mix test test/sigra/planning/phase_222_release_lane_hardening_test.exs` passes (4 tests, 0 failures) and both automated verification greps (`docs/release-runbook-v1-0.md`, `dry_run`) pass against the updated `MAINTAINING.md`.

## User Setup Required

None - no external service configuration required. The HARD-02 dry-run proof was an operator-dispatched `gh workflow run` against an already-authenticated `gh` session; no new secrets or config were introduced.

## Next Phase Readiness

- HARD-02 is now fully closed: the automatable half (Plan 02's `notify-release-failure` loud-signal job) plus this plan's dry-run readiness proof (D-06.1) and wiring-trace confirmation (D-06.2, 222-RESEARCH.md Finding 4) together satisfy "auto-publish proven-or-fails-loudly."
- HARD-01 and HARD-02 are both closed; Phase 222 (release-lane-hardening-no-silent-rot) is complete (3/3 plans).
- Phase 223 (get-current-on-hex-terminal-currency-proof) can proceed — its human-gated operator steps (`mix hex.retire sigra 1.20.0` + v1.2.0/v1.3.0 publish dispatch) are unblocked by this phase's proof that the publish path itself is green.
- No blockers from this plan.

---
*Phase: 222-release-lane-hardening-no-silent-rot*
*Completed: 2026-07-11*

## Self-Check: PASSED

All modified files verified present on disk (`MAINTAINING.md`, `test/sigra/planning/phase_222_release_lane_hardening_test.exs`); Task 2 commit `54fca5a2` verified present in `git log --oneline --all`.
