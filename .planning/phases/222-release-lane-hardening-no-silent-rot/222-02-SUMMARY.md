---
phase: 222-release-lane-hardening-no-silent-rot
plan: 02
subsystem: infra
tags: [ci, github-actions, gh-cli, release-please, notify, release-lane]

requires:
  - phase: 222-release-lane-hardening-no-silent-rot
    provides: "222-01's durable resolve_latest_sigra_source stray-exclusion resolver (the fixed upgrade_smoke half of HARD-01)"
provides:
  - "one shared, idempotent, secret-safe tracking-issue script (scripts/ci/notify-failure-issue.sh) proven offline via a hermetic self-test"
  - "notify_release_lane_rot: a red ci-gate on main now opens/updates a durable GitHub Issue (HARD-01 loud-red-main-signal half)"
  - "notify-release-failure: a release-please gate-ci-green/publish-hex failure now opens/updates a durable GitHub Issue instead of stalling silently (HARD-02 fail-loudly half)"
  - "structural test/sigra/planning/phase_222_release_lane_hardening_test.exs locking both consumer jobs' gating, permissions, and not-in-ci-gate posture"
affects: [223-get-current-on-hex-terminal-currency-proof]

tech-stack:
  added: []
  patterns:
    - "shared find-or-create tracking-issue script (D-07) invoked by two independent workflow consumers instead of duplicated inline gh logic"
    - "GitHub context values (run id/sha/tag/version/results) passed to a run: shell block only via the step env: mapping, never inlined into the shell text — prevents context-string injection"
    - "needs-free-from-ci-gate.needs reporter job shape (mirrors nightly_probe) for a push/schedule-gated failure consumer that must never become a required check"

key-files:
  created:
    - scripts/ci/notify-failure-issue.sh
    - scripts/ci/notify-failure-issue.test.sh
    - test/sigra/planning/phase_222_release_lane_hardening_test.exs
  modified:
    - .github/workflows/ci.yml
    - .github/workflows/release-please.yml

key-decisions:
  - "One shared scripts/ci/notify-failure-issue.sh (D-07) is called inline from both workflows instead of a composite action — no new SHA-pinned third-party dependency, and the idempotency logic stays in one shellcheck-able, locally-testable file (per RESEARCH Finding 2)."
  - "notify_release_lane_rot is deliberately NOT added to ci-gate.needs and is not a required check — mirrors nightly_probe's standalone posture to avoid stranding PR merges under ruleset 14941512."
  - "notify-release-failure is a separate aggregator job (not inline if: failure() steps in gate-ci-green/publish-hex) because gate-ci-green's timeout exit 1 reliably yields result: failure, which reliably fires the downstream reporter."
  - "GitHub context values (run id, sha, tag, version, job results) are passed to the run: shell block only via the step's env: mapping and referenced as shell variables, never inlined directly as ${{ github.* }} inside run: text — closes the tampering/injection threat (T-222-02-02)."
  - "Extended the gate to also cover cancelled results (not just failure) for both gate-ci-green and publish-hex, per RESEARCH Finding 2's discretionary recommendation."

requirements-completed: [HARD-01, HARD-02]

coverage:
  - id: D1
    description: "scripts/ci/notify-failure-issue.sh is a shared, idempotent, secret-safe find-or-create tracking-issue script (create-once on no open issue, comment-once on an existing open issue, fail-closed on missing LABEL/TITLE/BODY)"
    requirement: "HARD-01"
    verification:
      - kind: unit
        ref: "scripts/ci/notify-failure-issue.test.sh (Cases A-C)"
        status: pass
    human_judgment: false
  - id: D2
    description: "notify_release_lane_rot (ci.yml) opens/updates the release-lane-rot tracking issue on a red ci-gate on push/schedule/dispatch, is absent from ci-gate.needs, and is not a required check"
    requirement: "HARD-01"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_222_release_lane_hardening_test.exs#222-01"
        status: pass
    human_judgment: false
  - id: D3
    description: "notify-release-failure (release-please.yml) aggregates gate-ci-green/publish-hex failure under the release_created guard and opens/updates the same tracking issue"
    requirement: "HARD-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_222_release_lane_hardening_test.exs#222-03"
        status: pass
    human_judgment: false
  - id: D4
    description: "a forced real failure on main actually opens the tracking Issue end-to-end (red-probe proof)"
    verification: []
    human_judgment: true
    rationale: "Requires dispatching a real workflow run against GitHub's live Issues API with a real GITHUB_TOKEN; deferred to the operator runbook in Plan 03 per 222-VALIDATION.md's Manual-Only classification. Cannot be proven offline/hermetically."

duration: 20min
completed: 2026-07-11
status: complete
---

# Phase 222 Plan 02: Build the shared loud-signal mechanism and wire its two consumers Summary

**Built scripts/ci/notify-failure-issue.sh — one shared, idempotent, secret-safe find-or-create GitHub Issue script — and wired it into two independent consumers: notify_release_lane_rot (ci.yml, red ci-gate on main) and notify-release-failure (release-please.yml, gate-ci-green/publish-hex failure), replacing two previously silent failure modes with one durable tracking issue.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-10T23:58:01Z (approx., continues from Plan 01 session)
- **Completed:** 2026-07-11T00:15:05Z
- **Tasks:** 3
- **Files modified:** 5 (3 created, 2 modified)

## Accomplishments
- New `scripts/ci/notify-failure-issue.sh`: reads `LABEL`/`TITLE`/`BODY` from the environment (fail-closed if any is unset) plus `GH_TOKEN`; finds the single open Issue carrying `LABEL` and either comments on it (idempotent occurrence) or creates it — never both, never a duplicate.
- New `scripts/ci/notify-failure-issue.test.sh`: hermetic self-test with a recording `gh` stub on `PATH` proving all three behavior cases (create-once, comment-once, fail-closed-no-partial-call); wired into `ci.yml`'s `fast_checks` job.
- New `notify_release_lane_rot` job in `ci.yml`: `needs: [ci-gate]`, fires only when `ci-gate.result == 'failure'` on non-PR events, job-level `issues: write`, invokes the shared script with label `release-lane-rot` and a BODY carrying the run URL/SHA/surface. Deliberately absent from `ci-gate.needs` and not a required check.
- New `notify-release-failure` job in `release-please.yml`: aggregates `gate-ci-green`/`publish-hex` failure or cancellation under the `release_created == 'true'` guard, using the pre-existing workflow-level `issues: write`, invoking the same shared script with the release tag/version and failing job named in the BODY.
- New `test/sigra/planning/phase_222_release_lane_hardening_test.exs`: 3 structural tests locking both consumer jobs' gating/permissions/script-invocation and the not-in-`ci-gate.needs` posture.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the shared idempotent notify-failure-issue.sh + offline self-test, wired into fast_checks** - `e424f03d` (feat)
2. **Task 2: Add the HARD-01 red-main consumer job notify_release_lane_rot to ci.yml** - `772c1b79` (feat)
3. **Task 3: Add the HARD-02 publish-failure aggregator notify-release-failure to release-please.yml + author the phase_222 structural test** - `8e3fa374` (feat)

## Files Created/Modified
- `scripts/ci/notify-failure-issue.sh` - shared idempotent find-or-create tracking-issue script (D-07)
- `scripts/ci/notify-failure-issue.test.sh` - hermetic self-test (recording `gh` stub, 3 cases)
- `.github/workflows/ci.yml` - self-test wired into `fast_checks`; new `notify_release_lane_rot` job (HARD-01 consumer)
- `.github/workflows/release-please.yml` - new `notify-release-failure` job (HARD-02 aggregator consumer)
- `test/sigra/planning/phase_222_release_lane_hardening_test.exs` - structural coverage for both consumer jobs

## Decisions Made
- Used `gh issue list --label "$LABEL" --state open --json number --jq '.[0].number' || true` exactly as given in RESEARCH Finding 2, rather than adding extra defensive `2>/dev/null` suppression — the stub's error path is exercised and clean, and matching the cited snippet keeps the script auditable against the research trail.
- Passed `RUN_URL`/`COMMIT_SHA`/`TAG_NAME`/`VERSION`/job-`.result` values into each `run:` shell block exclusively via the step `env:` mapping, then referenced them as shell variables when constructing `BODY` — never interpolating `${{ github.* }}` or `${{ needs.*.result }}` directly into the shell text — closing threat T-222-02-02 (tampering via untrusted context strings).
- Extended both consumers' failure gates to also treat `cancelled` as a fire condition (not just `failure`) for `gate-ci-green`/`publish-hex`, per RESEARCH Finding 2's "consider also `cancelled`" discretionary note — a cancelled gate/publish is just as silent a failure mode as an explicit failure.
- Kept `notify_release_lane_rot` and `notify-release-failure` as separate, job-scoped aggregators (not inline `if: failure()` steps inside existing jobs) to preserve the exact `result`-based gating RESEARCH verified against `gate-ci-green`'s timeout `exit 1` behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. `actionlint` on both workflows reports the same 5 pre-existing, unrelated shellcheck warnings already logged in `deferred-items.md` (Plan 01) — confirmed unchanged in content, only shifted by this plan's line insertions in `ci.yml`. `release-please.yml` is fully actionlint-clean. No new findings introduced by this plan's edits.

## User Setup Required

None - no external service configuration required. The `GITHUB_TOKEN` used by both notify jobs is the default Actions token (already scoped via job-level or workflow-level `issues: write`); no new secret needs to be configured.

## Next Phase Readiness
- HARD-01 is now fully closed: the resolver half (Plan 01) prevents the stray version from silently winning, and the loud-signal half (this plan) makes a red `ci-gate` on `main` discoverable via a tracking Issue.
- HARD-02's automatable half is closed: a `gate-ci-green`/`publish-hex` failure or cancellation now opens/updates the same tracking issue instead of a silent ~30-minute stall.
- Plan 03 owns the remaining manual-only piece per 222-VALIDATION.md: the red-probe proof (a forced failure on `main` actually opening the tracking Issue end-to-end against the live GitHub Issues API) and the operator runbook documentation. No blockers from this plan.

---
*Phase: 222-release-lane-hardening-no-silent-rot*
*Completed: 2026-07-11*

## Self-Check: PASSED

All created files verified present on disk; all three task commits (`e424f03d`, `772c1b79`, `8e3fa374`) verified present in `git log --oneline --all`.
