---
phase: 252-measure-current-ci
plan: 01
subsystem: ci-observability
tags: [bash, jq, github-actions, evidence]
requires: []
provides:
  - Bounded read-only Actions and rule-source collection with durable request ledgers.
  - Hash-checked offline replay for required-check wait and runner cost.
  - Current-effective required-context preflight evidence.
affects: [252-measure-current-ci]
actuals:
  tokens: 81880
  tasks: 2
  commits: 7
commits: 7
plan_head_before: a99dce2008f8f2924e147440585ea8859bfd8df7
plan_head_after: 4a14a1a3e4733169d126ce74513261a7b8eded1e
tech-stack:
  added: []
  patterns:
    - Shared request guard for every new live GitHub read.
    - Source bundles verify retained response hashes before replay.
key-files:
  created:
    - .planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json
    - .planning/phases/252-measure-current-ci/252-run-family-38144377407-retry1/manifest.json
  modified:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci-run-metrics.test.sh
key-decisions:
  - Current enforced context names determine eligibility; observed ruleset IDs remain provenance.
  - Missing source-revision data produces unknown timing and remains one family observation.
patterns-established:
  - Live collection uses explicit GET requests through a 600-request, 60-minute, 250-core threshold and per-request deadline guard.
  - Offline replay rejects source hash or identity mismatches and retains literal conclusions.
requirements-completed: []
coverage:
  - id: D1
    description: Collect and replay a source-bound Actions run without network access during replay.
    requirement: CIMEAS-01
    verification:
      - kind: integration
        ref: "scripts/ci/ci-run-metrics.test.sh#Test P: one PR family collects to a hash-checked offline replay"
        status: pass
      - kind: other
        ref: "live run 38144377407 replay: 477-second endpoint, 2080 runner-seconds"
        status: pass
    human_judgment: false
  - id: D2
    description: Keep changed rules, unbound checks, incomplete timestamps, and uncollected revisions unknown.
    requirement: CIMEAS-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-run-metrics.test.sh#Tests Q, S, and T"
        status: pass
    human_judgment: false
duration: 22min
completed: 2026-10-12
status: complete
---

# Phase 252 Plan 01: Capture and replay a source-bound CI family

**The collector now bounds each read-only GitHub request, snapshots current required checks, and replays retained run data into required-check wait and summed runner cost.**

## Performance

- **Duration:** 22 minutes
- **Started:** 2026-10-12T17:19:07Z
- **Completed:** 2026-10-12T17:41:21Z
- **Tasks:** 2
- **Files modified:** 24

## Accomplishments

- Added preflight and collection modes that route reads through one guarded GET helper. Requests stop at 600 calls, 60 minutes, or core remaining of 250; each call also has a process deadline and at most one transient retry.
- Captured the current five enforced context names, branch rules, active rulesets, toolchain, checkout identity, and API budget. Preflight status is `ready`, with no missing capabilities and no required-rule change.
- Saved run 38144377407, its check runs, jobs, rules, and request ledger with SHA-256 records. Offline replay with `gh` removed reports a 477-second first/eventual required-check endpoint and 2,080 runner-seconds.
- Added fixture coverage for rate/time/request limits, transient retries, changed rules, unbound checks, missing timestamps, reruns, literal outcomes, hash tampering, and multi-revision input.

## Task Commits

1. **Task 1: Capture and replay one real PR family through its enforced context endpoint** — `6b2071768` (feat)
2. **Task 2: Reject ambiguous identity, changed rules and incomplete source records** — `de2f77afa` (test)

Additional scoped commits: `30df8ca19` preserved an incomplete first collection attempt; `0d021eeb6` and `e259480b2` refreshed preflight evidence after read-back preservation; `a5063f29a` enforced actual per-request deadlines.

## Files Created/Modified

- `scripts/ci/ci-run-metrics.sh` — bounded preflight/collection and identity-checked offline replay; legacy collector modes remain available.
- `scripts/ci/ci-run-metrics.test.sh` — hermetic coverage for guards, replay identities, outcomes, and unknown cases.
- `.planning/phases/252-measure-current-ci/252-EVIDENCE-PREFLIGHT.json` — clean-checkout preflight against current effective required checks.
- `.planning/phases/252-measure-current-ci/252-run-family-38144377407-retry1/` — retained live source bundle and request ledger.

## Decisions Made

- Current enforced context names determine eligibility. Ruleset identifiers are retained only as provenance, so replacing an ID without changing the effective names does not invalidate the measurement.
- A manifest with multiple revisions remains one family observation. Since every revision needs its own retained source bundle, replay returns unknown timing until that source exists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical control] Enforced actual per-request deadlines**
- **Found during:** Final bounded-request audit
- **Issue:** `gh` does not recognize the `GH_HTTP_TIMEOUT` variable, so it could not guarantee that a request ends within the remaining time budget.
- **Fix:** Wrap each guarded API call with the available `timeout` or `gtimeout` command and stop before networking if neither is installed.
- **Files modified:** `scripts/ci/ci-run-metrics.sh`
- **Verification:** `bash -n scripts/ci/ci-run-metrics.sh`; full test suite passed 26/26.
- **Committed in:** `a5063f29a`

**Total deviations:** 1 auto-fixed (Rule 2). The change tightens the planned request budget and does not add dependencies.

## Issues Encountered

- The first live collection received HTTP 404 from the legacy branch-protection endpoint. Current rulesets provide the effective checks, so the collector now records branch protection as not configured and continues; the exact incomplete first attempt is preserved in `252-run-family-38144377407/`.
- The selected run’s `pull_requests` field was empty. The captured live measurement therefore proves one source SHA and its attempts, not a full multi-revision PR history. The offline multi-revision fixture confirms that such input stays one family and cannot report a timing without each revision’s source.
- The hosted baseline is not being marked passed here. Phase requirements stay pending until phase-level verification gathers the required population.

## Planning Write-Ahead Preservation

| Prior revision | Durable ref | Exact bytes verified before refresh |
|---|---|---|
| Initial preflight | `6b2071768` | `252-EVIDENCE-PREFLIGHT.json` `1cb55f889f36a31e81ba9011d2f089b5977bb1b5913a8d13fb86029bdeef1664`; request ledger `89f0fbf8191baa33befe9f002c11b0ca52de06ecca4118dcd0ed4eaf81672897` |
| Second preflight | `0d021eeb6` | `252-EVIDENCE-PREFLIGHT.json` `0674bbb646c3317596861b0766ef0216f8121db1829f83352fcf5ec690c93f8a`; request ledger `17270aa5fa7a37fe2e4ccdc5a6e8fb426a9f104b3cdde89dcf3a6c24189c7bef` |
| Intermediate SDK state | `4a14a1a3` | `STATE.md` `d2cb1492bfa82269c07b5aaa09ab01486c36f1cfec89f3192f0e11b54dbd099c`; `state.json` `fcc0b3df18bbd81c4448f82cb416bbec8e826fdd5157ef9614108a5a7873fe72`; `ROADMAP.md` `7a13cec1f837ab15277afdc272af7fa209a84fde4a3fe5c3470ba7bc5e225ab0` |

## User Setup Required

None.

## Next Phase Readiness

Plan 252-01 implementation and its automated checks are complete. Phase 252 still has five plans and phase-level verification pending; continue with `$gsd-execute-phase 252` after the next-plan readiness check. No requirement is marked complete by this plan.

## Self-Check: PASSED

- Summary and preflight evidence files exist.
- All seven task and preservation commits are ancestors of the current branch.
- The preflight shape and the full test suite passed: 26 passed, 0 failed.

---
*Phase: 252-measure-current-ci*
*Completed: 2026-10-12*
