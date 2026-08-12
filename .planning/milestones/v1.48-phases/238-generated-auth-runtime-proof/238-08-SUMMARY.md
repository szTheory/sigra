---
phase: 238-generated-auth-runtime-proof
plan: "08"
subsystem: auth
tags: [phoenix, liveview, session-revocation, playwright, github-actions]
requires:
  - phase: 238-07
    provides: generated-host runtime harness and exact-SHA evidence receipt
provides:
  - Atomic reset-time canonical-session revocation and post-commit LiveView disconnects.
  - Ownership-constrained generated session revocation controls.
  - Fresh generated-host proof for the final session-security correction SHA.
affects: [generated-auth, session-management, ci-evidence]
tech-stack:
  added: []
  patterns:
    - Delete canonical session rows within the reset Ecto.Multi and broadcast only after commit.
    - Derive socket disconnect topics from persisted hashed session identities.
key-files:
  modified:
    - lib/sigra/auth.ex
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/user_auth.ex
    - priv/templates/sigra.install/core/session_live.ex
    - test/sigra/auth_test.exs
    - test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs
    - test/example/priv/playwright/tests/generated-auth.spec.ts
    - .planning/phases/238-generated-auth-runtime-proof/238-EVIDENCE.json
key-decisions:
  - "Use application PubSub for generated reset broadcasts; Phoenix starts AppModule.PubSub, not WebModule.PubSub."
  - "Keep canonical session deletion inside the reset transaction and broadcast hashes only after commit."
requirements-completed: [AUTH-01, AUTH-02, AUTH-03]
coverage:
  - id: D1
    description: Password reset atomically revokes canonical sessions and disconnects existing generated browser sessions.
    requirement: AUTH-01
    verification:
      - kind: unit
        ref: "test/sigra/auth_test.exs"
        status: pass
      - kind: automated_ui
        ref: "GitHub Actions run 31287052180 / Generated auth runtime proof job 93177695136"
        status: pass
    human_judgment: false
  - id: D2
    description: Generated session revocation derives ownership from current_scope and rejects foreign hashes.
    requirement: AUTH-01
    verification:
      - kind: unit
        ref: "test/sigra/auth_test.exs#keeps a foreign session when public revocation receives another user's id"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: Generated B2C reset, OAuth collision, accessibility, and stable locator coverage pass on the final correction SHA.
    requirement: AUTH-02
    verification:
      - kind: e2e
        ref: "GITHUB_WORKSPACE=\"$PWD\" scripts/ci/generated-auth-runtime-proof.sh --all"
        status: pass
    human_judgment: false
  - id: D4
    description: Rendered generated-auth states retain deterministic accessibility and DOM contracts.
    requirement: AUTH-03
    verification:
      - kind: e2e
        ref: "GitHub Actions run 31287052180 / Generated auth runtime proof job 93177695136"
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-08-08
status: complete
---

# Phase 238 Plan 08: Final Session Security Closure Summary

**Password reset now atomically revokes canonical generated sessions, disconnects affected LiveViews after commit, and prevents cross-user per-session revocation.**

## Accomplishments

- Extended `Sigra.Auth.reset_password/4` to delete configured canonical sessions in its existing transaction, then broadcast post-commit disconnects using persisted hashed session identities.
- Updated generated auth to use a started application PubSub, hash the LiveView socket identity, and constrain each session-revoke event to `current_scope.user`.
- Added independent-browser-context reset denial proof and recorded a passing exact-SHA generated-host job at `e06d68a0f46263d37afa2d201c59ec460c8a60e4`.

## Task Commits

1. **Task 1: Revoke canonical sessions atomically when a password is reset** — `951c0d4e`, `16d09f17`
2. **Task 2: Enforce current-user ownership in generated session revocation** — `951c0d4e`
3. **Task 3: Replace runtime evidence on the exact security-correction SHA** — `e06d68a0`

## Files Modified

- `lib/sigra/auth.ex` — Deletes configured canonical sessions inside reset and broadcasts disconnects after commit.
- `priv/templates/sigra.install/core/auth.ex` — Supplies the generated session schema, application PubSub, and authenticated-user revoke constraint.
- `priv/templates/sigra.install/core/user_auth.ex` — Uses the hashed session identity for LiveView disconnect topics.
- `priv/templates/sigra.install/core/session_live.ex` — Reads ownership solely from `socket.assigns.current_scope.user`.
- `238-EVIDENCE.json` — Records final exact-SHA CI metadata and preserves prior attempt lineage.

## Decisions Made

- Used `<%= app_module %>.PubSub` for generated reset broadcasts after the first direct run proved that `<%= web_module %>.PubSub` is not a started registry.
- Preserved failed run `31286905514` in the receipt; no failed or wrong-SHA run is treated as proof.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected generated PubSub ownership after the first exact-SHA runtime run**
- **Found during:** Task 3 generated-host evidence.
- **Issue:** The planned reset wrapper targeted `WebModule.PubSub`, which Phoenix does not start.
- **Fix:** Switched reset disconnect broadcasts to `AppModule.PubSub` and tightened the source contract.
- **Verification:** 86 scoped ExUnit tests passed; direct job `93177695136` passed.
- **Committed in:** `e06d68a0`.

**Total deviations:** 1 auto-fixed Rule 1 issue. The correction is required for generated-host correctness and does not expand scope.

## Issues Encountered

The first final-SHA run (`31286905514`) exposed the invalid PubSub module after the database transaction committed. The receipt retains that failed attempt; the corrected fresh SHA passed the full direct job.

## User Setup Required

None.

## Next Phase Readiness

Phase 238 has complete machine-readable runtime evidence for AUTH-01 through AUTH-03. Phase-level verification remains the next workflow gate.

## Self-Check: PASSED

All plan artifacts exist, the scoped ExUnit suite passed (86 tests), Playwright discovery passed (2 tests), and GitHub Actions run `31287052180` passed with the direct generated-auth job on the final correction SHA.
