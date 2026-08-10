---
phase: 240-alpha-operations-rehearsal
plan: 04
subsystem: ci-security
tags: [github-actions, ci, oidc, credential-boundary, exunit]
requires:
  - phase: 238-generated-auth-runtime-proof
    provides: Credential-free generated-host loopback OIDC runtime proof.
  - phase: 240-alpha-operations-rehearsal
    provides: Wave 0 no-secrets source contract.
provides:
  - Independent fresh-generator and loopback-runtime credential-free CI proof lanes.
  - Fail-closed source contracts for secret injection, fixture provenance, and bounded local-only claims.
affects: [ci, generated-auth-runtime-proof, b2c-alpha-operations]
tech-stack:
  added: []
  patterns:
    - Workflow-job-scoped source contracts avoid unrelated workflow prose and jobs.
    - Fixed local credentials are documented as disposable fixtures adjacent to their literals.
key-files:
  created: []
  modified:
    - test/sigra/planning/phase_240_no_secrets_ci_test.exs
    - scripts/ci/passkeys-opt-out-smoke.sh
    - scripts/ci/generated-auth-runtime-proof.sh
    - .github/workflows/ci.yml
    - .github/workflows/generated-auth-runtime-proof.yml
key-decisions:
  - "Repository CI claims only generator shape/compile/boot, local OIDC state/PKCE/callback, and rendered B2C behavior; host staging remains unclaimed."
  - "CLOAK_KEY and loopback OIDC client values are explicit disposable fixtures, never deployment credentials."
patterns-established:
  - "Keep generated-auth runtime proof outside the legacy skip-tolerant ci-gate aggregate."
requirements-completed: [OPS-02]
coverage:
  - id: D1
    description: "Independent no-secret generator and loopback runtime lanes reject secret injection and provider-success claims."
    requirement: OPS-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_240_no_secrets_ci_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs"
        status: pass
      - kind: other
        ref: "bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-10
status: complete
---

# Phase 240 Plan 04: No-Secrets CI Contract Summary

**Independent B2C generator and loopback-OIDC runtime proofs now fail closed on credential injection, fixture ambiguity, lane merging, and claims of host-staging success.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-10T22:10:00Z
- **Completed:** 2026-08-10T22:17:46Z
- **Tasks:** 1/1
- **Files modified:** 5

## Accomplishments

- Scoped ExUnit source contracts to the relevant workflow jobs, preserving separate generator and rendered-runtime evidence lanes.
- Documented fixed Cloak and loopback OIDC values as disposable local fixtures and unsets inherited Google credentials before runtime boot.
- Replaced fixed harness sleeps with required bounded readiness probes, while retaining zero Playwright retries and source checks against browser-state mutation.
- Added explicit workflow boundaries so no repository CI result claims host-staging success.

## Task Commits

1. **Task 1: Enforce independent credential-free lanes and truthful claims** - `c8a88bcb` (test, RED), `dc0c54ec` (feat, GREEN)

## Files Created/Modified

- `test/sigra/planning/phase_240_no_secrets_ci_test.exs` - Positive and negative source contracts for the two no-secret evidence lanes.
- `scripts/ci/passkeys-opt-out-smoke.sh` - Disposable Cloak fixture provenance and bounded fresh-host readiness.
- `scripts/ci/generated-auth-runtime-proof.sh` - Disposable loopback OIDC/Cloak provenance, Google env boundary, and bounded readiness.
- `.github/workflows/ci.yml` - Explicit bounded claim comments for independent CI jobs.
- `.github/workflows/generated-auth-runtime-proof.yml` - Explicit local-loopback claim boundary for dispatched evidence.

## Decisions Made

- Workflow contracts inspect only the relevant job regions so unrelated GitHub-secret use elsewhere cannot invalidate or mask these two lanes.
- The runtime proof remains outside `ci-gate`; folding it into the legacy skip-tolerant aggregate would require a separate evidence-contract change.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- ExUnit initialization logged local PostgreSQL connection-refused noise, but both focused source-contract modules executed and passed without database access.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- OPS-02 now has deterministic repository evidence for its no-secrets CI boundary.
- Real Google, mail provider, DNS/TLS, reverse proxy, and physical-device staging evidence remain deliberately host-owned and unclaimed by CI.

## Verification

- PASS: `mix test test/sigra/planning/phase_240_no_secrets_ci_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs`
- PASS: `bash -n scripts/ci/passkeys-opt-out-smoke.sh scripts/ci/generated-auth-runtime-proof.sh`
- PASS: exact `COVERAGE.md` local-only declaration source assertion.

## Self-Check: PASSED

- All five modified source-contract files exist.
- Task commits `c8a88bcb` and `dc0c54ec` exist in git history.

---
*Phase: 240-alpha-operations-rehearsal*
*Completed: 2026-08-10*
