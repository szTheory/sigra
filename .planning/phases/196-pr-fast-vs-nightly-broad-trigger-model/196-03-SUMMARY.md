---
phase: 196-pr-fast-vs-nightly-broad-trigger-model
plan: "03"
subsystem: infra
tags: [ci, github-actions, nightly, workflow-dispatch, probe, forced-failure]

requires:
  - phase: 196-01
    provides: "schedule trigger + 5 nightly-gated jobs (passkeys/install-matrix/upgrade-smoke/example-http-smoke/example-playwright-smoke); force_fail_probe boolean workflow_dispatch input"

provides:
  - "Dedicated needs-free nightly_probe job in ci.yml guarded by github.event_name != 'pull_request'"
  - "force_fail_probe boolean input wired to exit-1 step in nightly_probe (D-14 forced-failure self-test)"
  - "Removal of misplaced probe step from passkeys_manual_fallback_smoke (196-01 overstep remediated)"

affects: [196-04]

tech-stack:
  added: []
  patterns:
    - "Needs-free standalone self-test job pattern: probe job with no needs: key is not pre-empted by release_ref_guard and cannot be dragged into ci-gate failure cascade"
    - "Boolean dispatch input accessor: inputs.<name> (not github.event.inputs.<name>) preserves boolean type across GitHub Actions expressions"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "Task 1 (force_fail_probe input) was already correctly implemented by 196-01 — verified and confirmed as satisfied with no further edits"
  - "Probe relocated from passkeys_manual_fallback_smoke (196-01 overstep) to a dedicated needs-free nightly_probe job per plan spec"
  - "nightly_probe deliberately excluded from ci-gate.needs to preserve D-10 aggregator integrity and avoid skipped-entry bloat"

patterns-established:
  - "D-14 forced-failure probe pattern: needs-free job + if: github.event_name != 'pull_request' + single inputs-guarded exit 1 step"

requirements-completed: [CRIT-02]

duration: 2min
completed: 2026-06-20
status: complete
---

# Phase 196 Plan 03: D-14 Forced-Failure Nightly Probe Summary

**Dedicated `nightly_probe` job added to ci.yml — needs-free, PR-excluded, wired to `force_fail_probe` boolean dispatch input; misplaced probe step removed from `passkeys_manual_fallback_smoke` (196-01 overstep remediated)**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-06-20T16:11:59Z
- **Completed:** 2026-06-20T16:13:33Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Confirmed `force_fail_probe` boolean `workflow_dispatch` input (added by 196-01) is correct — type: boolean, default: false, required: false — no edit needed.
- Removed the misplaced `Forced-failure probe (nightly self-test)` step from `passkeys_manual_fallback_smoke` (lines 615-619 in pre-edit ci.yml), which 196-01 incorrectly placed as a step inside a multi-minute smoke job.
- Added the dedicated `nightly_probe` job: needs-free, `if: github.event_name != 'pull_request'`, single step guarded by `if: ${{ inputs.force_fail_probe }}` that echoes and exits 1; NOT in ci-gate.needs.
- YAML remains valid (python3 yaml.safe_load confirmed).

## Task Commits

1. **Task 1: Verify force_fail_probe boolean input (D-14)** — Already satisfied by 196-01; no commit needed (verified-only task).
2. **Task 2: Add dedicated nightly_probe job + remove misplaced step** — `3a4920dc` (feat)

**Plan metadata commit:** (pending)

## Files Created/Modified

- `.github/workflows/ci.yml` — Removed probe step from `passkeys_manual_fallback_smoke`; added `nightly_probe` job at EOF with PR-guard, no-needs, and `force_fail_probe`-guarded exit-1 step.

## Decisions Made

- Task 1 is a verify-only task: the input already matched the plan's required shape exactly (196-01 correctly added it). No edit, no commit — recorded as satisfied with zero changes.
- Both edits (step removal + job addition) were committed atomically in a single commit since they represent two sides of the same reconciliation (relocate the probe from wrong location to correct location).
- `nightly_probe` is deliberately NOT added to `ci-gate.needs`: it is a standalone D-14 self-test, not a required release gate. Adding it would introduce a `skipped` result on PR runs into the aggregator loop (result != success && result != skipped tolerates skips, but it is conceptually cleaner to keep the gate list to real required lanes).

## Deviations from Plan

### Reconciliation Note (196-01 Overstep)

**196-01 overstep corrected per critical reconciliation context in execute prompt:**

- **Found:** The `Forced-failure probe (nightly self-test)` step was placed INSIDE `passkeys_manual_fallback_smoke` by 196-01 (at the end of that job's steps, lines 615-619 in the pre-edit file). This is incorrect — the probe entangled itself with a real multi-minute smoke job, meaning: (a) it only fires if the passkeys job runs, (b) it extends a real job's run time, (c) it cannot be independently identified in the Actions UI.
- **Fix:** Removed those 5 lines from `passkeys_manual_fallback_smoke`; added the standalone `nightly_probe` job at EOF with the correct structure.
- **Filed as:** Planned reconciliation (not an unplanned Rule 1-3 deviation) — the critical reconciliation context explicitly specified this action.
- **Committed in:** `3a4920dc`

---

**Total deviations:** 1 reconciliation (196-01 overstep relocated)
**Impact on plan:** Purely structural correction; no behavioral change to any real job. End-state exactly matches plan spec.

## Issues Encountered

None — both the input verification and the structural reconciliation were clean.

## Threat Model Verification

- T-196-03-01 (Elevation of Privilege): `force_fail_probe` only triggers `exit 1` — no privileged effect, no secret access. `permissions: contents: read` preserved in ci.yml global block. MITIGATED.
- T-196-03-02 (Denial of Service): `nightly_probe` host has `if: github.event_name != 'pull_request'` — never runs on PRs; needs-free + not in ci-gate.needs so cannot block PRs or drag aggregator. MITIGATED.
- T-196-03-SC (Tampering): No package installs introduced. N/A.

## Known Stubs

None.

## Runbook Note (for Plan 04 MAINTAINING.md)

To verify the nightly lane actually reports red on a real failure:

```bash
# Red the nightly probe job — proves the nightly trigger path detects failures
gh workflow run "CI" -f force_fail_probe=true

# Normal run — probe step skipped, nightly_probe job stays green
gh workflow run "CI"
```

`nightly_probe` will show as red/green in the Actions UI independently of all other jobs.

## Next Phase Readiness

- D-14 forced-failure probe is wired and verified structurally. Plan 04 (MAINTAINING.md runbook) can document the `gh workflow run "CI" -f force_fail_probe=true` invocation as the canonical probe command.
- No blockers.

---
*Phase: 196-pr-fast-vs-nightly-broad-trigger-model*
*Completed: 2026-06-20*
