---
phase: 246-hosted-and-direct-login-ceremonies
plan: 17
subsystem: auth
tags: [app-login, postgres, github-actions, runtime-proof, mfa]
requires:
  - phase: 246-14
    provides: hosted MFA session and approval concurrency repairs
  - phase: 246-16
    provides: independent app-session installer contract
provides:
  - PostgreSQL-backed generated-host proof for hosted and direct ceremonies
  - Immutable successful CI receipt and run provenance
affects: [app-login, app-sessions, CI evidence]
tech-stack:
  added: []
  patterns: [redacted source-bound CI evidence, deterministic generated-host assertions]
key-files:
  created:
    - .planning/phases/246-hosted-and-direct-login-ceremonies/246-RUNTIME-PROOF.json
    - .planning/phases/246-hosted-and-direct-login-ceremonies/246-RUNTIME-PROOF-RUN.json
  modified:
    - scripts/ci/generated-app-login-runtime-proof.sh
    - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
key-decisions:
  - "Use typed persisted-state assertions instead of comparing captured Mix output."
  - "Retain only a byte-identical redacted receipt plus immutable-head provenance."
patterns-established:
  - "Generated-host CI evidence must bind each source digest to the dispatched immutable head."
requirements-completed: [APP-01, APP-02, APP-03]
coverage:
  - id: D1
    description: "Hosted and direct app-login ceremonies have source-bound PostgreSQL CI proof."
    requirement: APP-01
    verification:
      - kind: integration
        ref: "GitHub Actions run 31961276529; scripts/ci/generated-app-login-runtime-proof.sh --all"
        status: pass
    human_judgment: false
  - id: D2
    description: "Hosted S256, approval replay protection, MFA upgrade, and shared FetchAppSession contract are proven."
    requirement: APP-02
    verification:
      - kind: integration
        ref: "GitHub Actions run 31961276529; 246-RUNTIME-PROOF.json"
        status: pass
    human_judgment: false
  - id: D3
    description: "Direct backup-code MFA, replay rejection, and browser-required ordering are proven."
    requirement: APP-03
    verification:
      - kind: integration
        ref: "GitHub Actions run 31961276529; 246-RUNTIME-PROOF.json"
        status: pass
    human_judgment: false
metrics:
  duration: 10m
  completed: 2026-08-16
status: complete
---

# Phase 246 Plan 17: Generated app-login runtime evidence Summary

**A source-bound PostgreSQL CI receipt now proves hosted and direct app-login ceremonies, including MFA, replay, browser policy, and shared app-session authentication.**

## Performance

- **Duration:** 10m
- **Started:** 2026-08-16T17:17:00Z
- **Completed:** 2026-08-16T17:27:33Z
- **Tasks:** 2/2
- **Files modified:** 5

## Accomplishments

- Repaired the disposable generated-host proof through deterministic PostgreSQL-backed MFA, replay, and browser-policy checks.
- Replaced a flaky captured command-output comparison with a typed persisted-family assertion and regression coverage.
- Retained the byte-identical successful receipt and exact immutable-run provenance from [run 31961276529](https://github.com/szTheory/sigra/actions/runs/31961276529).

## Task Commits

1. **Task 1: Make `--all` causally prove every remaining Phase 246 behavior** - `9d909c99`, `13f330eb`, `54f33ac7`, `7caa8c66`, `0352b9e5`, `2f8ec6eb`, `dbe62cad`, `c07514f8`, `f9657493`, `ab7a05eb`, `62d22419` (fix)
2. **Task 2: Dispatch once and retain the exact successful CI evidence** - `867c4e87` (docs)

## Files Created/Modified

- `scripts/ci/generated-app-login-runtime-proof.sh` - generated-host causal proof with deterministic browser-policy persistence verification.
- `test/sigra/planning/phase_246_generated_app_login_runtime_test.exs` - regression contract for deterministic persisted-state checking.
- `246-RUNTIME-PROOF.json` - byte-identical redacted receipt downloaded from the successful artifact.
- `246-RUNTIME-PROOF-RUN.json` - exact dispatch, run, immutable SHA, artifact, and coverage provenance.
- `246-RUNTIME-PROOF-RUN-FAILED-56.json` - redacted diagnostic for the superseded failed head.

## Decisions Made

- Used the existing typed `assert_one_family` check after browser-required rejection; generated-host logger output is not a stable assertion surface.
- The durable receipt explicitly proves prior immutable implementation head `62d2241981dad891868beacaf7b0ba5db108dad2`, not evidence-only commit `867c4e87`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced nondeterministic aggregate-output comparison**
- **Found during:** Task 1
- **Issue:** CI logger output could vary despite unchanged family state, failing the browser-required aggregate comparison.
- **Fix:** Reused the typed family/attempt assertion after the rejection and added a source regression test.
- **Files modified:** `scripts/ci/generated-app-login-runtime-proof.sh`, `test/sigra/planning/phase_246_generated_app_login_runtime_test.exs`
- **Verification:** Focused ExUnit suite and `generated-app-login-runtime-proof.sh --all` both passed locally; CI run 31961276529 passed.
- **Committed in:** `62d22419`

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Required reliability repair only; scope and evidence contract remained unchanged.

## Issues Encountered

Earlier immutable heads failed in CI and were retained as redacted numbered diagnostics. The final repair head passed once; no failed head was redispatched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

APP-01, APP-02, and APP-03 have durable automated evidence. The retained receipt and provenance validate offline against the immutable implementation head.

## Self-Check: PASSED

- Receipt and provenance exist and parse.
- Receipt is byte-identical to the downloaded artifact.
- Successful run `31961276529` and implementation commit `62d22419` exist.
