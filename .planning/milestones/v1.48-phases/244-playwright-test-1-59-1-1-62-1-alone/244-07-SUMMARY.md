---
phase: 244-playwright-test-1-59-1-1-62-1-alone
plan: 07
subsystem: testing
tags: [playwright, npm, source-tree, security, shell]
requires:
  - phase: 244
    provides: paired Playwright capture runner and version-specific dependency selection from Plans 01–06
provides:
  - Fail-closed source-tree comparison for paired Playwright installs
  - Hermetic fixtures for package transforms and source mutations
  - Post-install source-tree enforcement before browser setup
affects: [244-08, playwright-measurement, ci]
plan_head_before: cf98d420c4a7c19435ddfd9274fb2d3d7aeed276
commits: 4
actuals:
  tokens: 4529
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Immutable measured-SHA reference tree shared across install roots
    - Node test wrapper for TAP-compatible execution of hermetic shell fixtures
key-files:
  created:
    - scripts/ci/verify-playwright-source-tree.sh
    - scripts/ci/verify-playwright-source-tree.test.sh
    - scripts/ci/verify-playwright-source-tree.test.mjs
  modified:
    - scripts/ci/run-playwright-drift.sh
key-decisions:
  - "Compare all files outside node_modules and validate dependency JSON after removing only Playwright trio selections."
  - "Extract one reference archive from GITHUB_SHA and check each npm ci root before browser installation."
  - "Use a real Node node:test wrapper so the GSD TDD gate observes actual failing and passing assertions."
requirements-completed: [QUEUE-02]
coverage:
  - id: D1
    description: "Paired Playwright source roots reject source edits and allow only a validated version trio transform."
    requirement: QUEUE-02
    verification:
      - kind: unit
        ref: "bash scripts/ci/verify-playwright-source-tree.test.sh"
        status: pass
      - kind: unit
        ref: "node --test scripts/ci/verify-playwright-source-tree.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both dependency and render installs check source equality after npm ci and before browser or capture commands."
    requirement: QUEUE-02
    verification:
      - kind: integration
        ref: "verify-playwright-source-tree.test.sh runner-wiring assertions"
        status: pass
      - kind: other
        ref: "bash -n scripts/ci/run-playwright-drift.sh"
        status: pass
    human_judgment: false
decisions:
  - "Check package manifest and lockfile semantics after removing only the three selected Playwright package entries, so unrelated edits in those files remain detectable."
  - "Classify a source-tree guard mismatch separately so the measurement runner halts before browser setup or capture for that root."
metrics:
  duration: 18min
  completed: 2026-09-26
status: complete
---

# Phase 244 Plan 07: Paired Playwright Source-Tree Guard Summary

**Paired Playwright installs now prove their source trees match the measured SHA, with only the validated Playwright dependency trio allowed to vary.**

## Performance

- **Duration:** 18min
- **Started:** 2026-09-26T22:22:31Z
- **Completed:** 2026-09-26T22:40:08Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a fail-closed guard that compares sorted relative paths and SHA-256 digests while excluding generated `node_modules` directories.
- Verified package manifests and lockfiles resolve the expected `@playwright/test`, `playwright`, and `playwright-core` versions; unrelated dependency-file changes still fail.
- Wired the shared measured-SHA reference archive into both dependency setup and render installs, before browser setup and snapshot backup.

## Task Commits

1. **Task 1 RED: source-tree contract fixtures** — `fbf101f7`
2. **Task 1 GREEN: source-tree comparison guard** — `c332598f`
3. **Task 2 RED: install-boundary assertions** — `edb7042c`
4. **Task 2 GREEN: post-install runner enforcement** — `8b6e33dc`

## Files Created/Modified

- `scripts/ci/verify-playwright-source-tree.sh` — compares file inventories and contents and validates the allowed dependency transform.
- `scripts/ci/verify-playwright-source-tree.test.sh` — exercises positive, mutation, dependency-version, and runner-wiring fixtures using temporary directories.
- `scripts/ci/verify-playwright-source-tree.test.mjs` — runs the shell fixture suite as a real Node test assertion for the GSD TDD evidence gate.
- `scripts/ci/run-playwright-drift.sh` — checks dependency and render roots after `npm ci`, before browser setup and capture.

## Decisions Made

- Dependency-file exceptions are checked semantically: only the Playwright trio entries are normalized, preserving detection of unrelated package edits.
- All install roots compare against one archive extracted from `GITHUB_SHA`.
- A Node `node:test` wrapper runs the shell fixtures because the GSD TDD checker accepts parsed Node test evidence. The wrapper records the shell suite’s actual exit status and assertion output.

## Deviations from Plan

### Verification harness adjustment

The plan specified a shell test suite. The GSD TDD evidence checker only accepts a named failing test in Node TAP output, so a small `.mjs` wrapper was added. It invokes the planned shell fixture suite and asserts its actual exit status; it does not synthesize test results. Both the shell suite and Node wrapper pass after implementation.

## Verification

- `bash scripts/ci/verify-playwright-source-tree.test.sh` — passed.
- `node --test scripts/ci/verify-playwright-source-tree.test.mjs` — passed.
- `bash -n scripts/ci/run-playwright-drift.sh` — passed.
- `bash -n scripts/ci/verify-playwright-source-tree.sh` — passed.
- Two archives of the committed measured source passed the guard at version `1.62.1`.
- `git diff --check` — passed.

## Issues Encountered

- The first TDD evidence attempt used the shell test output directly; GSD correctly classified it as `INVALID_RED` because it was not Node TAP. The test was run through a genuine Node assertion wrapper, and the gate then returned `RED_EVIDENCE_OK` for the actual failing fixture and runner-wiring assertions.

## User Setup Required

None.

## Next Phase Readiness

Plan 244-07 closes SEC-244-07 and completes its QUEUE-02 work. Plan 244-08 remains untouched.

---
*Phase: 244-playwright-test-1-59-1-1-62-1-alone*
*Completed: 2026-09-26*

## Self-Check: PASSED

- Summary file exists at the planned path.
- All four task commits are present in git history.
- Task fixtures, Node TDD wrapper, and shell syntax checks pass.
