---
phase: 221-unblock-the-gate-ship-honest-generated-host-debt
plan: 04
subsystem: release
tags: [hex, publish, release, operator-gated, provenance]

# Dependency graph
requires: ["221-03"]
provides:
  - "sigra v1.2.0 published to Hex.pm (dry-run verified clean first) — PUB-02"
  - "sigra v1.3.0 published to Hex.pm — PUB-03; this is the smoke-pin target (Plan 03) that lets Plan 05 green the gate on push-to-main"
affects: [221-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Operator-gated Hex release via the ungated hex-publish.yml workflow_dispatch (dry-run then real for v1.2.0; real for v1.3.0), each re-running its own provenance + WAE compile + mix test + docs WAE preflight at the tag ref"

key-files:
  created: []
  modified: []

key-decisions:
  - "hex-publish.yml is workflow_dispatch (ungated — does NOT depend on ci-gate), so the deferred upgrade-smoke <.button type> debt (which lives only in the push-only upgrade_smoke job) does not block the publish; confirmed by reading the workflow's preflight steps — it compiles/tests Sigra itself at the tag ref, not the upgrade-smoke harness"
  - "Dry-run v1.2.0 first (per plan) as the safety net; the dry-run passed clean (provenance, WAE compile, mix test incl. InstallFixture w/ phx_new 1.8.8, docs WAE, packaged-files inspection, mix hex.publish --dry-run) before any real publish"
  - "Published v1.2.0 then v1.3.0 to keep the Hex series contiguous (1.1.0 → 1.2.0 → 1.3.0); latest_stable_version remains 1.20.0 (stray sorts higher under sort -V) until Plan 05 retires it"
  - "Operator authorized the full sequence and delegated dispatch to the agent (gh authenticated as szTheory); the real Hex writes remained explicitly operator-authorized (D-16)"

requirements-completed: [PUB-02, PUB-03]

coverage:
  - id: D1
    description: "Sigra v1.2.0 is published to Hex.pm, dry-run verified clean first (PUB-02)"
    requirement: "PUB-02"
    verification:
      - kind: integration
        ref: "hex-publish.yml dry-run run 29108801612 completed success (all preflight steps green, 'Dry run Hex publish' success, publish steps skipped); real run 29109600146 completed success ('Publish to Hex' + 'Verify version on Hex.pm' success); curl -s https://hex.pm/api/packages/sigra | jq -r '.releases[].version' | grep -x '1.2.0' returns 1.2.0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Sigra v1.3.0 is published to Hex.pm after v1.2.0 (PUB-03); the smoke-pin target is live"
    requirement: "PUB-03"
    verification:
      - kind: integration
        ref: "hex-publish.yml real run 29113000684 completed success ('Publish to Hex' + 'Verify version on Hex.pm' success); curl -s https://hex.pm/api/packages/sigra | jq -r '.releases[].version' | grep -x '1.3.0' returns 1.3.0; preflight confirmed 1.2.0 present and 1.3.0 absent before dispatch"
        status: pass
    human_judgment: false
  - id: D3
    description: "Live Hex API shows both 1.2.0 and 1.3.0 in the release set"
    requirement: "PUB-02, PUB-03"
    verification:
      - kind: integration
        ref: "curl -s https://hex.pm/api/packages/sigra releases now include 1.20.0, 1.3.0, 1.2.0, 1.1.0, 1.0.0, 0.3.0, ...; retirements still {} (retirement of 1.20.0 is Plan 05)"
        status: pass
    human_judgment: false

# Metrics
duration: 71min
completed: 2026-07-10
status: complete
---

# Phase 221 Plan 04: Publish v1.2.0 + v1.3.0 to Hex.pm Summary

**Published the already-tagged, provenance-clean releases v1.2.0 then v1.3.0 to Hex.pm via the ungated `hex-publish.yml` `workflow_dispatch` (dry-run first for v1.2.0, then real; real for v1.3.0). Both confirmed live via the Hex API. v1.3.0 — the smoke-pin target from Plan 03 — is now live, unblocking Plan 05's terminal gate-green observation.**

## Performance

- **Duration:** ~71 min (dominated by three sequential CI runs; each hex-publish run is ~13 min because `mix test` shells out to `mix phx.new` for InstallFixture)
- **Started:** 2026-07-10T16:49:00Z (v1.2.0 dry-run dispatch)
- **Completed:** 2026-07-10T18:14:00Z (v1.3.0 confirmed on Hex)
- **Tasks:** 2 (both `checkpoint:human-action`, operator-gated)
- **Files modified:** 0 (external Hex registry state only)

## Accomplishments
- **Preflight (agent):** snapshotted live Hex before any write — `latest_stable_version=1.20.0`, releases `1.20.0, 1.1.0, 1.0.0, 0.3.0, …`, no `1.2.0`/`1.3.0`, retirements `{}`. Confirmed tags `v1.2.0` (`b0ef1097`) and `v1.3.0` (`8a600ba0`) exist, point at green release-please merge commits (#66, #74), and are in `origin/main` history. Read `hex-publish.yml` to confirm its preflight compiles/tests Sigra itself at the tag ref (not the upgrade-smoke harness), so the deferred `<.button type>` debt does not block the publish.
- **PUB-02 v1.2.0 dry-run:** dispatched `hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=true` (run `29108801612`) — completed **success**: provenance, WAE compile, library tests, docs WAE, packaged-files inspection, and `mix hex.publish --dry-run` all green; publish/verify steps correctly skipped.
- **PUB-02 v1.2.0 real:** dispatched `dry_run=false` (run `29109600146`) — completed **success** including "Publish to Hex", "Verify version on Hex.pm", and "Verify HexDocs source links after publish". Hex API `grep -x 1.2.0` confirms live.
- **PUB-03 v1.3.0 real:** preflight re-confirmed `1.2.0` present + `1.3.0` absent, then dispatched `hex-publish.yml -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=false` (run `29113000684`) — completed **success**; Hex API `grep -x 1.3.0` confirms live. The smoke-pin target is now live.

## Task Commits

Both tasks are operator-gated human-action checkpoints producing external Hex registry state, not repo commits (`files_modified: []`). Verification evidence is the CI run IDs and Hex API responses recorded above.

1. **Task 1: PUB-02 — publish v1.2.0 (dry-run then real)** — runs `29108801612` (dry-run, success) + `29109600146` (real, success); Hex API confirms 1.2.0
2. **Task 2: PUB-03 — publish v1.3.0 (real)** — run `29113000684` (real, success); Hex API confirms 1.3.0

## Files Created/Modified
None — this plan mutates external Hex registry state only.

## Decisions Made
- Delegated `gh workflow run` dispatch to the agent (operator authorized the full sequence up front; `gh` authenticated as `szTheory`). The irreversible real publishes remained explicitly operator-authorized (D-16).
- Confirmed the ungated `workflow_dispatch` path is the correct lever — it does not depend on `ci-gate`, so it is unaffected by the still-red push-only `upgrade_smoke` job and the deferred `<.button type>` debt.
- Kept the Hex series contiguous by publishing v1.2.0 before v1.3.0.

## Deviations from Plan

None — plan executed as written. Dispatch was performed by the agent rather than the operator's own hands, but under explicit operator authorization; the plan's D-16 intent (operator-gated, not silently automated) was honored via the checkpoint pause + AskUserQuestion authorization before any dispatch.

## Issues Encountered

The v1.2.0 real-publish background watcher (`gh run watch`) exited non-zero due to a transient `api.github.com` connection error in the watcher process — NOT a run failure. Re-queried `gh run view`: the run itself completed **success** with all publish/verify steps green, and the Hex API independently confirmed 1.2.0 live. No impact.

## User Setup Required

None beyond the operator authorization already obtained. `HEX_API_KEY` is configured in the repo (it has published before) and was used by the workflow.

## Next Phase Readiness
- v1.3.0 (the smoke-pin target) is live on Hex — Plan 03's pin can now take effect.
- Plan 05 owns: (1) retire the stray Hex `1.20.0` for adopter honesty (PUB-04), and (2) observe the terminal PUB-01 proof — `upgrade_smoke` → success and `ci-gate` green on a push-to-`main` run.
- `latest_stable_version` is still `1.20.0` (sorts higher); Plan 05's retirement addresses adopter honesty, and the smoke pin (not retirement) is what greens the gate.

---
*Phase: 221-unblock-the-gate-ship-honest-generated-host-debt*
*Completed: 2026-07-10*

## Self-Check: PASSED

Hex API confirms both `1.2.0` and `1.3.0` in the sigra release set (`grep -x` each returns a match). CI runs `29108801612` (dry-run), `29109600146` (v1.2.0 real), and `29113000684` (v1.3.0 real) all completed with conclusion `success` and their "Publish to Hex" / "Verify version on Hex.pm" steps green. No repo files were expected or modified (`files_modified: []`).
