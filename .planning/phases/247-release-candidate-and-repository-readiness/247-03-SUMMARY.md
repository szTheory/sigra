---
phase: 247-release-candidate-and-repository-readiness
plan: 03
subsystem: release
tags: [release, upgrade-guide, ex-doc, phoenix]
requires:
  - phase: 247-01
    provides: reviewed 1.6.0 source and readiness ledger
  - phase: 247-02
    provides: curated 1.6.0 changelog and exact-head candidate
  - phase: 246
    provides: generated confirmation recovery source and CI evidence
provides:
  - README-to-v1.6-upgrade-guide adopter route
  - source-backed 1.6.0 compatibility, update, migration, and generated-host guidance
  - exact-head CI docs-build and candidate-readiness evidence
affects: [247-04, adopters, release-documentation]
actuals:
  tokens: 7263
  tasks: 1
  commits: 2
plan_head_before: 51c0e7a8ca126888fe618ca5ad2401188ff2188b
plan_head_after: 563f411bc2659bb9ac1652d552ce58ffb0c876b1
commits: 2
tech-stack:
  added: []
  patterns: [versioned-exdoc-upgrade-guide, exact-head-docs-ci-receipt]
key-files:
  created:
    - tmp/phase-247-candidate/guides/introduction/upgrading-to-v1.6.md
  modified:
    - tmp/phase-247-candidate/README.md
    - tmp/phase-247-candidate/mix.exs
    - .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json
key-decisions:
  - "Keep package version constraints separate from the CI-tested toolchain and generated-host smoke cases."
  - "Use the exact-head CI docs step when the isolated candidate lacks locked dependencies; do not install packages."
  - "Treat generated confirmation LiveView changes as host-owned adoption work; no migration or upgrade task is needed solely for this release."
patterns-established:
  - "Versioned adopter guides link from README to the matching changelog heading and distinguish package behavior from generated host code."
requirements-completed: [READY-01]
coverage:
  - id: D1
    description: "README routes existing adopters to the v1.6 guide and its 1.6.0 changelog entry."
    requirement: READY-01
    verification:
      - kind: other
        ref: "CI 37700772880, SHA 563f411; ExDoc Check docs build cleanly"
        status: pass
      - kind: other
        ref: "git show --check at candidate SHA 563f411"
        status: pass
    human_judgment: false
  - id: D2
    description: "The guide gives candidate-backed compatibility, update/check commands, migration status, and selective adoption steps for existing generated hosts."
    requirement: READY-01
    verification:
      - kind: other
        ref: "Source audit of mix.exs, .tool-versions, CI workflow, migration templates, and sigra.upgrade task at candidate SHA 563f411"
        status: pass
      - kind: other
        ref: "CI 37700772880, SHA 563f411; all required jobs and ci-gate passed"
        status: pass
      - kind: other
        ref: "validate-release-readiness.mjs --stage candidate --assert-live-refresh; PR #224 remains open at exact head 563f411, base/main 590eb4e"
        status: pass
    human_judgment: false
duration: 34min
completed: 2026-10-07
status: complete
---

# Phase 247 Plan 03: Release Candidate and Repository Readiness Summary

**PR #224 now has a source-backed v1.6 adopter path, and its corrected exact-head documentation build and required CI passed.**

## Performance

- **Duration:** 34 minutes
- **Started:** 2026-10-07T22:47:35Z
- **Completed:** 2026-10-07T23:21:26Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Routed the README's existing-app upgrade entry to a new v1.6 guide and added that guide to the ExDoc extras. The guide links to the actual 1.6.0 changelog heading.
- Documented supported package constraints separately from the CI toolchain (Elixir 1.19.5 / Erlang-OTP 28.5) and the default generated-host smoke. It gives the exact `{:sigra, "~> 1.6.0"}` tuple, host-root update and test commands, and the release's migration and `mix sigra.upgrade` status.
- Explained that updating Sigra does not rewrite host-owned generated files. Existing hosts can compare and selectively adopt their generated confirmation LiveView; fresh installs receive current output.
- Recorded the final PR #224 head, exact-head CI evidence, and live candidate validator result in the readiness ledger. The PR remains open at `563f411bc2659bb9ac1652d552ce58ffb0c876b1`, based on reviewed main `590eb4ed3323db11dd74326cbee00c9c7973e529`.

## Task Commits

1. **Task 1: Add the v1.6 adopter upgrade path** — `29847f93e` (`docs`).
2. **Task 1 corrective docs fix: link the toolchain file to its versioned repository source** — `563f411bc` (`fix`).

The task's candidate commits were measured from `51c0e7a8ca126888fe618ca5ad2401188ff2188b` through `563f411bc2659bb9ac1652d552ce58ffb0c876b1` (2 commits). Root planning metadata remains for the GSD closeout commit.

## Files Created/Modified

- `tmp/phase-247-candidate/README.md` — routes existing adopters to the v1.6 guide.
- `tmp/phase-247-candidate/guides/introduction/upgrading-to-v1.6.md` — explains the update and selective generated-host adoption path.
- `tmp/phase-247-candidate/mix.exs` — registers the guide as an ExDoc extra.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` — records the corrected PR head, initial failure, successful exact-head CI receipt, and live candidate validation.

## Decisions Made

- Package dependency constraints describe accepted ranges; the guide separately names the fixed CI toolchain and required pull-request smoke coverage.
- No database migration or `mix sigra.upgrade` run is needed solely for 1.6.0 confirmation recovery. The migration-template diff contains no schema change.
- Existing applications must selectively adopt host-owned generated confirmation LiveView changes; dependency updates only deliver library-owned behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed an ExDoc reference warning for `.tool-versions`**
- **Found during:** Task 1 exact-head CI verification
- **Issue:** ExDoc cannot resolve a relative link to `.tool-versions` because that file is outside the documentation package surface; `mix docs --warnings-as-errors` failed on candidate head `29847f93e`.
- **Fix:** Linked to the planned v1.6.0 repository source URL for `.tool-versions`.
- **Files modified:** `guides/introduction/upgrading-to-v1.6.md`
- **Verification:** Corrected exact-head CI run `37700772880` passed the unconditional `Check docs build cleanly` step and all required jobs.
- **Committed in:** `563f411bc`.

**Total deviations:** 1 auto-fixed documentation issue. The guide's scope and claims stayed within the plan.

## Verification

- Local `mix docs --warnings-as-errors` was unavailable because the isolated candidate has no `deps/`; Mix reported unchecked dependencies. No package installation was attempted.
- The first exact-head run `37699084723` exposed the ExDoc warning above and a transient generated-admin browser-install timeout. The docs link was repaired and a fresh pull-request run on the corrected source passed.
- Exact-head CI run [37700772880](https://github.com/szTheory/sigra/actions/runs/37700772880), attempt 1, SHA `563f411bc2659bb9ac1652d552ce58ffb0c876b1`: docs build, generated-admin smoke, install smoke, library lanes, example HTTP/unit/Playwright lanes, and `ci-gate` all passed.
- `git show --check --oneline HEAD` passed in the candidate worktree.
- `validate-release-readiness.mjs --stage candidate --assert-live-refresh` returned `valid: true`; PR #224 is open, live PR head and candidate worktree head match, and base/main remain `590eb4e`.

## User Setup Required

None.

## Next Phase Readiness

Plan 03 satisfies READY-01 and leaves the reviewed candidate ready for Plan 04. This is not phase-wide verification and does not publish, tag, merge, or otherwise release PR #224. After Plan 03 closeout, `init.execute-phase 247` should report Plan 04 as the next runnable plan.

## Self-Check: PASSED

- The summary and v1.6 guide exist.
- Candidate task commits `29847f93e` and `563f411bc` are ancestors of candidate HEAD `563f411bc2659bb9ac1652d552ce58ffb0c876b1`.
- The readiness ledger records the same live candidate head and `candidate_validation.valid: true`.
- Candidate `git show --check --oneline HEAD` passed and its worktree is clean.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-07*
