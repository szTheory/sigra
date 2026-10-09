---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 08
subsystem: infra
tags: [git, preservation, node, closeout]

# Dependency graph
requires:
  - phase: 249-04
    provides: "Fresh open-PR and worktree inventory"
  - phase: 249-05
    provides: "Protected-promotion source and preservation context"
  - phase: 249-06
    provides: "Closeout validator and final acceptance contract"
provides:
  - "Path-scoped recoverable refs for every safely owned inherited change"
  - "A current preservation record and strict closeout inventory with explicit blockers"
affects: [249-09, 249-10, 249-11, 249-12, REL-02]

# Actuals
actuals:
  tokens: 93176
  tasks: 3
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Preserve an exact path under a scoped ref, verify its bytes, then clean only that path."
    - "Keep ambiguous ownership and unrecoverable historical bytes as explicit blockers."

key-files:
  created:
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json
    - scripts/maintainers/preserve-phase-249-worktrees.mjs
    - scripts/maintainers/preserve-phase-249-worktrees.test.mjs
  modified:
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-CLOSEOUT.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs

key-decisions:
  - "Preserve every safely attributable current path locally, without adding inherited changes to the release candidate."
  - "Leave ambiguous or unrecoverable identities untouched and block promotion until their disposition is established."

patterns-established:
  - "A clean-state assertion uses raw porcelain status across every registered worktree."
  - "Evidence outputs require exact producer, source, hash, and capture-boundary provenance."

requirements-completed: [REL-02]

coverage:
  - id: D1
    description: "Path-scoped preservation helper, strict validator, and regression fixtures."
    requirement: REL-02
    verification:
      - kind: unit
        ref: "node --test scripts/maintainers/preserve-phase-249-worktrees.test.mjs .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Complete live inventory of registered worktrees and open PRs."
    requirement: REL-02
    verification:
      - kind: other
        ref: "249-PRESERVATION.json capture at 2026-10-09T17:47:48.453Z; 5 worktrees, 14 open PRs, all changed-file reads complete"
        status: pass
    human_judgment: false
  - id: D3
    description: "Explicit preservation decisions for every inherited path, including exact unresolved blockers."
    requirement: REL-02
    verification:
      - kind: other
        ref: "validate-closeout.mjs --mode preservation; blocked by 2 unresolved identities"
        status: fail
    human_judgment: true
    rationale: "The owner and destination of the Phase 233 contract-test change and the disposition of the unavailable historical handoff bytes require an informed decision."

# Metrics
duration: 28min
completed: 2026-10-09
status: complete
---

# Phase 249: Path-Scoped Preservation and Strict Closeout Evidence

**Exact-path preservation now accounts for the live inherited worktree set and keeps unresolved identities visible as promotion blockers.**

## Performance

- **Duration:** 28 min elapsed across resumed execution turns
- **Started:** 2026-10-09T13:26:21-04:00 (first Plan 08 implementation commit)
- **Completed:** 2026-10-09T17:54:38Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Added a two-stage preservation helper that pins and verifies exact path bytes before cleaning only the selected tracked path; expanded validator fixtures for missing refs, races, changed bytes, later evidence files, and raw worktree status.
- Refreshed the complete inventory across five worktrees and 14 open PRs. The original v2 record contained 103 inherited identities: 101 preserved and two blocked. The post-plan disposition below supersedes those counts: 102 preserved, one blocked, and no current source path left dirty.
- Materialized the v2 preservation record for the original Plan 08 completion boundary. A post-plan v3 decision record below resolves one inherited path and keeps the historical handoff loss blocked.

## Task Commits

1. **Task 1: Prove one inherited path can be preserved and removed without loss** — `b7b52f568` (`fix(249-08): preserve exact dirty paths with verified local refs`)
2. **Task 2: Account for post-capture evidence and every current dirty path** — `bc3e9d2d9` (`fix(249-08): require exact output provenance and raw worktree status`)
3. **Task 3: Preserve safely owned inherited sets and prove the live state** — `f74b0cde5`, `803b30776`, `b1f5e522d` (record preservation, refresh the inventory, and rebind the TODO-supported paths)

## Files Created/Modified

- `scripts/maintainers/preserve-phase-249-worktrees.mjs` and `.test.mjs` — exact-path scoped-ref preservation with readback and race checks.
- `validate-closeout.mjs` and `.test.mjs` — full raw-status inventory, evidence provenance, and preservation validation.
- `249-CLOSEOUT.json` and `249-PRESERVATION.json` — current inventory and exact path/ref/hash evidence, including blockers.

## Decisions Made

- Preserve paths only when phase, task, or matching TODO evidence establishes their owner and destination; do not include inherited changes in the release candidate.
- Classify the Phase 233 contract-test traversal edit as a separate Sigra test/CI maintenance follow-up, preserve its exact bytes locally, and exclude it from the 1.6.0 release candidate.
- Keep the unavailable historical `.planning/HANDOFF.json` revision blocked; the current handoff does not prove recovery of the historical bytes.

## Deviations from Plan

- The plan’s TDD annotations requested a separate failing-test commit. The existing implementation commits added tests with their corresponding changes; no RED commit was produced, and no retrospective RED claim is made. Project `tdd_mode` is false, and the final regression suite passes.
- The preservation task completed its designed blocked outcome. At Plan 08 completion, two identities remained unresolved; the Phase 233 ownership decision later resolved one without changing the original Plan 08 result. The historical handoff identity remains blocked.

## Issues Encountered

- Preservation mode remains blocked by one exact historical handoff identity. Inventory mode is complete; the phase-level REL-02 closeout is not verified.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 249-09 is gated by its explicit Plan 08 precondition: preservation mode must pass before a candidate can be created. Resume with `$gsd-execute-phase 249 --gaps-only` only if the exact historical handoff bytes become recoverable and the refreshed preservation gate passes. No candidate, push, PR, or merge was created during this plan.

## Post-Plan-08 disposition (2026-10-09)

- **Phase 233 test-discovery edit:** assigned to Sigra maintainers as a separate test/CI maintenance follow-up, not release scope. Its exact source bytes (SHA-256 `02f142f9a1313c3a87523957c932300299a137ff9e29cbe6aa9ad6106e53c2c4`) were read back from `refs/phase-249-preservation/phase-233-bounded-scaffold-discovery` (object `fca3772b0dc546f954cd28c4122e72c29ddd6a05`), then only that source path was cleaned. Phase 249's exact 1.6.0 source validation passed full CI without the edit, so it is excluded from the candidate. The edit has no dedicated hostile-tree regression fixture; preservation does not claim otherwise.
- **Historical handoff:** the exact former `.planning/HANDOFF.json` bytes (SHA-256 `00dba2dfa078f6eef80d75f98799ff345db1df2c3d120ed2ef47d87ea25a7148`) were not found after scanning 22,400 Git objects and 74,345 regular files across the repository and registered worktrees. No Git LFS object store exists. Keep this missing evidence blocked and do not waive it; Plan 249-09 remains gated.
- **Standing verification default:** deterministic seam tests, CI evidence where recurring value justifies it, and no repeat human UAT are already recorded in `AGENTS.md`, `.planning/METHODOLOGY.md`, and the linked `.planning/VERIFICATION-POLICY.md`. Keep that policy as the single source of truth rather than duplicating it.

---
*Phase: 249-publish-and-prove-sigra-1-6-0*
*Completed: 2026-10-09*

- **GitHub/local recovery audit:** on 2026-10-09T19:20:44Z, hashed every blob in the current local object database (22,410 blobs) and a temporary GitHub mirror (18,847 blobs across 65 branches, 14 tags, 300 PR heads and 13 PR merge refs); neither contains the target. A prior file audit covered 74,345 regular files across the repository and registered worktrees. No relevant GitHub Actions artifact metadata or Git LFS store was found. No user-held copy is available, so the same search should not be repeated without new evidence.
