---
phase: 248-exact-source-release-gate
plan: 04
subsystem: release-automation
tags: [github-actions, jq, release-receipts, hex-publish]
requires:
  - phase: 248-exact-source-release-gate
    provides: isolated release credentials and exact-source gate contracts from Plans 01–03
provides:
  - validated atomic JSON receipts for release gate, publication, dry-run, failure, and cancellation outcomes
  - primary and manual recovery workflows that retain receipts before supplementary notification
affects: [phase-248-plan-05, phase-249-release-evidence]
actuals:
  tokens: 13206
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [jq schema validation, atomic same-directory receipt replacement, pinned artifact uploads]
key-files:
  created:
    - scripts/ci/release-receipt.sh
    - scripts/ci/release-receipt.test.sh
  modified:
    - .github/workflows/release-please.yml
    - .github/workflows/hex-publish.yml
    - test/sigra/planning/phase_248_release_gate_contract_test.exs
key-decisions:
  - "Require complete source and workflow identity before writing a canonical release receipt; reject credential-shaped fields and diagnostics."
  - "Use a separate bounded failure record when a manual recovery run cannot resolve any full source SHA, rather than inventing a canonical receipt."
patterns-established:
  - "Persist the validated 90-day release artifact before running supplementary issue and label notification."
  - "Capture timestamps in workflow steps because run_started_at is not an Actions expression-context property."
requirements-completed: [AUTO-02]
coverage:
  - id: D1
    description: "Atomic receipt writer validates identity, timestamps, terminal consistency, retries, and credential exclusion."
    requirement: AUTO-02
    verification:
      - kind: unit
        ref: scripts/ci/release-receipt.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: "Primary and manual workflows retain terminal release receipts independently from issue notification, including dry-run and source-resolution failures."
    requirement: AUTO-02
    verification:
      - kind: integration
        ref: test/sigra/planning/phase_248_release_gate_contract_test.exs
        status: pass
      - kind: other
        ref: actionlint .github/workflows/release-please.yml .github/workflows/hex-publish.yml
        status: pass
    human_judgment: false
duration: 45min
completed: 2026-10-08
status: complete
plan_head_before: f02324fa55602a47beebcbe96809fffc07e4d161
plan_head_after: 0c12c4ccfb9a534858e8d0f6c433ea65d769e7df
---

# Phase 248 Plan 04: Durable Release Receipts Summary

Both release workflows now retain validated, source-linked terminal evidence independently from issue-label notification. The writer validates complete identities and atomically updates the receipt; manual recovery records dry-run and publish outcomes without representing a dry-run as publication.

## Performance

- **Duration:** 45 minutes
- **Started:** 2026-10-08T22:08:25Z
- **Completed:** 2026-10-08T22:53:25Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a jq-validated atomic receipt writer that rejects malformed identity, unsupported source events, inconsistent verdicts, unsafe diagnostics, and credential-shaped fields; retries preserve earlier stage evidence and cannot change source identity.
- Added the primary terminal aggregation job before the existing issue notifier, with pinned 90-day artifact retention and gate/publish run, verdict, attempt, timestamp, and failure details.
- Added matching manual recovery receipts for publish, dry-run, and ordinary validation or preflight failures. If no valid full SHA can be resolved, the workflow stores a bounded failure-only rejection record without asserting release success.
- Added workflow contract coverage for notifier ordering, `workflow_dispatch` preservation, dry-run status, source-resolution fallback, and rejection behavior.

## Task Commits

1. **Task 1: Define and fixture-test the release receipt contract** — `4f501a9e0` (`test(248-04): define terminal release receipt contract`)
2. **Task 2: Persist gate and publish receipts before supplementary notification** — `0c12c4ccf` (`feat(248-04): retain terminal release receipts`)

## Files Created/Modified

- `scripts/ci/release-receipt.sh` — validates and atomically writes the canonical receipt.
- `scripts/ci/release-receipt.test.sh` — covers success, failures, dry-run, cancellation, malformed identity, retries, notifier independence, and credential rejection.
- `.github/workflows/release-please.yml` — aggregates and uploads the primary terminal receipt before notifications.
- `.github/workflows/hex-publish.yml` — records manual publish/dry-run outcomes and source-bound failures.
- `test/sigra/planning/phase_248_release_gate_contract_test.exs` — asserts workflow receipt ordering and manual recovery contract.

## Decisions Made

- The canonical writer requires complete source identity and does not relax validation for recovery failures. When the manual recorder cannot resolve a full SHA, it writes a separate bounded `release_input_rejection` failure record and never labels it successful.
- Start and completion timestamps come from explicit UTC runner steps; unsupported `github.run_started_at` expressions were removed after actionlint identified them.
- Receipt artifacts use the existing fully pinned `actions/upload-artifact` revision and 90-day retention.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Captured workflow timestamps from runner steps**
- **Found during:** Task 2 verification
- **Issue:** `github.run_started_at` is not a supported GitHub Actions expression-context property, so actionlint rejected it.
- **Fix:** Added explicit UTC start-marker steps and passed their outputs between workflow jobs.
- **Files modified:** `.github/workflows/release-please.yml`, `.github/workflows/hex-publish.yml`
- **Verification:** actionlint passed on both workflows.
- **Committed in:** `0c12c4ccf`

**2. [Rule 2 - Missing critical functionality] Preserve manual recovery preflight failures**
- **Found during:** Task 2 review
- **Issue:** A missing credential could fail before candidate checkout, leaving no source SHA and skipping the manual receipt.
- **Fix:** Resolve the requested candidate before the trusted credential preflight, run the recorder for every manual workflow dispatch, resolve the exact version tag from trusted main when the publish job has no SHA, and emit a bounded failure-only rejection artifact when no full SHA exists.
- **Files modified:** `.github/workflows/hex-publish.yml`, `test/sigra/planning/phase_248_release_gate_contract_test.exs`
- **Verification:** focused ExUnit contract and actionlint passed; the canonical helper still rejects missing source identity.
- **Committed in:** `0c12c4ccf`

**Total deviations:** 2 auto-fixed. Both were required to preserve valid timestamps and truthful evidence for early manual-recovery failures.

## Verification

- `bash scripts/ci/release-receipt.test.sh` — 13 passed, 0 failed.
- `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs` — 8 tests, 0 failures.
- `actionlint .github/workflows/release-please.yml .github/workflows/hex-publish.yml` — passed.
- `shellcheck scripts/ci/release-receipt.sh scripts/ci/release-receipt.test.sh` — passed.
- Scoped `git diff --check` — passed.

## Issues Encountered

- A manual run whose version tag cannot be resolved has no truthful full source SHA. It receives the separate failure-only rejection artifact; the canonical receipt helper refuses to fabricate a source-linked receipt. This remains a deliberate evidence boundary.
- The existing manual credential transfers from Plan 03 remain incomplete. Repository secret copies were not modified; the environment setup checkpoint remains required before a live release run can use the missing credentials.

## User Setup Required

The Plan 03 setup checkpoint still requires transferring `RELEASE_PLEASE_TOKEN` to `release-automation` and `HEX_API_KEY` to `hex-publish`. Repository copies remain intact until each environment secret name is confirmed.

## Next Phase Readiness

Plan 05 is runnable according to the fresh `init.execute-phase 248` result. The receipt workflow implementation is complete; no merge, tag, or publication was performed. The missing environment secret transfers remain an external release-readiness item.

## Self-Check: PASSED

- Summary file exists at the plan output path.
- Both task commits (`4f501a9e0`, `0c12c4ccf`) are ancestors of HEAD.
- Scoped production files are committed; inherited unrelated changes remain unstaged.

---
*Phase: 248-exact-source-release-gate*
*Completed: 2026-10-08*
