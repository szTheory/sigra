---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "03"
subsystem: release-automation
tags: [github-actions, hex, remediation, ci]
requires:
  - phase: 242-02
    provides: default-branch-visible fixed-target remediation workflow
provides:
  - merged correction for the Hex retire command syntax
  - classified, non-retried remediation failure record
affects: [242-03, release-automation, hex-remediation]
actuals:
  tokens: 1100
  tasks: 0
  commits: 2
tech-stack:
  added: []
  patterns: [single-dispatch failure classification, exact-head repair PR gate]
key-files:
  created:
    - .planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-03-SUMMARY.md
  modified:
    - .github/workflows/hex-remediate-phantom.yml
    - scripts/ci/prohibitions/p22-hex-remediation.test.mjs
key-decisions:
  - "Use Hex's supported --message option for the fixed retirement message; do not attempt a second mutation dispatch after the failed run."
requirements-completed: []
coverage:
  - id: D1
    description: "The remediation syntax repair is green on its exact PR head."
    verification:
      - kind: integration
        ref: "PR #256 CI run 35555054938 at 907d875f5e0953777ffde0657e59082bf68d9e21"
        status: pass
    human_judgment: false
  - id: D2
    description: "Public remediation receipt and independently validated observations."
    requirement: REL-03
    verification:
      - kind: integration
        ref: "workflow run 35554955828"
        status: fail
    human_judgment: false
duration: 11min
completed: 2026-09-21
status: halted
---

# Phase 242 Plan 03 Summary

**The single authorized remediation dispatch was safely classified after Hex rejected an unsupported CLI option; its source repair is merged and green, but no successful public receipt exists.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-21T02:40:30Z
- **Completed:** 2026-09-21T02:51:00Z
- **Tasks:** 0/2 completed; Task 2 was not authorized to proceed without a successful receipt
- **Files modified:** 3

## Accomplishments

- Dispatched exactly one fixed-target workflow run, `35554955828`, against `154dd679d0bd0fc18b5d2142c8633c3aa9822ec5`; no matching in-progress run existed and the REST budget was 5,000 before the one 60-second watcher.
- Classified its deterministic failure from the failed-job log: the current Hex client rejects `mix hex.retire ... --yes`; the key remained masked and no success logs or sensitive artifact contents were retrieved.
- Repaired the supported `--message` invocation, updated its prohibition assertion, and merged PR #256 after exact-head CI run `35555054938` passed at `907d875f5e0953777ffde0657e59082bf68d9e21`. The observed `main` merge SHA is `0826a06d48b638c84af5db8984a1e8739f89cfaa`.

## Task Commits

1. **Task 1: Dispatch once, watch once, and retrieve the public remediation receipt** - no successful receipt; deterministic workflow failure classified.
2. **Deterministic failure repair** - `907d875f` (`fix(242): use supported Hex retire syntax`), merged by PR #256 as `0826a06d`.
3. **Plan metadata** - summary commit follows this record.

## Files Created/Modified

- `.github/workflows/hex-remediate-phantom.yml` - uses Hex's supported `--message` retirement syntax.
- `scripts/ci/prohibitions/p22-hex-remediation.test.mjs` - forbids regression to the rejected invocation.
- `.planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1/242-03-SUMMARY.md` - durable halt and repair provenance.

## Decisions Made

- Preserved the plan's no-redispatch rule after a failed mutation attempt. The corrected workflow is on `main`, but a subsequent remediation run requires separate authorization because this plan permits exactly one dispatch and its Task 2 requires a successful artifact.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Hex retire CLI option was unsupported**
- **Found during:** Task 1
- **Issue:** `mix hex.retire sigra 1.20.0 invalid ... --yes` failed before retirement with `--yes : Unknown option`.
- **Fix:** Replaced `--yes` with Hex's supported `--message` option and updated the deterministic prohibition test.
- **Verification:** `node --test scripts/ci/prohibitions/p22-hex-remediation.test.mjs`, `bash scripts/ci/hex-remediation-verify.test.sh`, and PR #256 CI run `35555054938` all passed.
- **Committed in:** `907d875f`, merged as `0826a06d`.

---

**Total deviations:** 1 blocking auto-fix.
**Impact on plan:** The repair is landed, but the explicit no-redispatch rule prevents generating the required successful workflow receipt in this execution.

## Issues Encountered

- Workflow run `35554955828` failed at the retirement step before the after-retirement, docs-revert, root-classification, resolver, and receipt steps. Its uploaded artifact is necessarily incomplete and was not used.

## User Setup Required

None. The protected credential was present and masked; no authentication or interactive checkpoint was encountered.

## Next Phase Readiness

Blocked: a new, explicitly authorized Phase 242 remediation execution must dispatch the corrected default-branch workflow once, obtain a successful `sigra.phase-242-hex-remediation/1` artifact, independently validate it, and then perform Task 2's evidence/todo commit. This plan's only dispatch has already been consumed and must not be repeated under its no-redispatch constraint.

---
*Phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1*
*Halted: 2026-09-21*
