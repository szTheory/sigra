---
phase: 240-alpha-operations-rehearsal
plan: "01"
subsystem: auth
tags: [hammer, rate-limiting, phoenix, generated-host, security]
requires:
  - phase: 240-05
    provides: Wave 0 red generated-rate-limit contract
provides:
  - Generated host-owned Hammer ETS limiter with explicit supervision and Sigra configuration
  - Explicit bounded rate limit on the canonical B2C login POST route
  - Credential-free fresh-host proof for bounded exhaustion and Retry-After behavior
affects: [240-02, generated-host, b2c-alpha]
tech-stack:
  added: [hammer ~> 7.4 in generated hosts]
  patterns: [host-owned limiter module, explicit route limiter configuration, disposable-host bounded request probe]
key-files:
  created: [priv/templates/sigra.install/core/rate_limit.ex]
  modified: [lib/sigra/install/features/core.ex, lib/sigra/install/injector.ex, scripts/ci/passkeys-opt-out-smoke.sh, test/sigra/plug/rate_limit_test.exs]
key-decisions:
  - "The generated login route defaults to three requests per 60 seconds and reads host runtime overrides from :sigra."
  - "The fresh-host probe injects a limit of two before boot and exhausts one limiter window without delays."
patterns-established:
  - "Generated dependency, module, child, config, and route ownership must be explicit and idempotent."
requirements-completed: [OPS-01]
coverage:
  - id: D1
    description: Generated B2C hosts own an explicit Hammer limiter dependency, ETS module, child, config, and login route plug.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: test/sigra/install/generated_rate_limit_contract_test.exs
        status: pass
      - kind: integration
        ref: scripts/ci/passkeys-opt-out-smoke.sh
        status: pass
    human_judgment: false
  - id: D2
    description: The rate-limit plug rounds Retry-After at exact and one-millisecond-over boundaries.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: test/sigra/plug/rate_limit_test.exs
        status: pass
    human_judgment: false
  - id: D3
    description: A disposable generated B2C host permits its injected bound then returns a generic 429 with positive Retry-After.
    requirement: OPS-01
    verification:
      - kind: integration
        ref: scripts/ci/passkeys-opt-out-smoke.sh
        status: pass
    human_judgment: false
metrics:
  duration: 8min
  completed: 2026-08-10
status: complete
---

# Phase 240 Plan 01: Generated B2C Rate Limiter Summary

**Canonical B2C installs now generate and supervise a Hammer ETS limiter, explicitly protect login POSTs, and prove bounded generic throttling in a fresh host.**

## Performance

- **Duration:** 8 min
- **Tasks:** 1/1
- **Files modified:** 6

## Accomplishments

- Added the generated host-owned `RateLimit` module, Hammer dependency, explicit `:sigra` module configuration, and child placement before Endpoint.
- Applied `Sigra.Plug.RateLimit` to `POST /users/log_in` with an explicit Hammer adapter, a stable login prefix, host-overridable bounds, and generic handler.
- Added a disposable-host ExUnit probe that synchronously proves two allowed attempts and the third generic 429 response with a positive `Retry-After`.
- Covered 1,000ms, 1,001ms, and 30,500ms Retry-After ceiling behavior in the library suite.

## Task Commits

1. **Task 1: Generate and exercise one protected B2C POST path end to end** — `a6bb1ceb` (feat)

## Verification

- `mix test test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/install/features/core_test.exs test/sigra/plug/rate_limit_test.exs` — PASS (51 tests)
- `bash -n scripts/ci/passkeys-opt-out-smoke.sh` — PASS
- `scripts/ci/passkeys-opt-out-smoke.sh` — PASS (fresh B2C host compiles, boots, and the generated route probe exhausts its bound without a limiter-window delay)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added a dedicated generated application-child injection anchor**
- **Found during:** Task 1
- **Issue:** The existing injector could only add a Vault child; it could not place a generated `RateLimit` child immediately before Endpoint.
- **Fix:** Added `:rate_limit_child`, with marker-based idempotency and endpoint-relative child insertion.
- **Files modified:** `lib/sigra/install/injector.ex`, `test/sigra/install/features/core_test.exs`
- **Verification:** Focused installer contracts and fresh-host smoke pass.
- **Committed in:** `a6bb1ceb`

**2. [Rule 1 - Regression prevention] Updated Core file-count and injector-anchor contracts**
- **Found during:** Task 1
- **Issue:** Core’s existing invariant tests had fixed file counts and a static supported-anchor list, both changed by the generated limiter output.
- **Fix:** Added the new template assertion, adjusted counts, and registered the two reused/added anchors.
- **Files modified:** `test/sigra/install/features/core_test.exs`
- **Verification:** Focused installer contracts pass.
- **Committed in:** `a6bb1ceb`

**Total deviations:** 2 auto-fixed (1 Rule 3, 1 Rule 1). **Impact:** Necessary generator-seam and invariant updates; no scope expansion.

## Issues Encountered

The local focused test command logs unavailable shared test-Postgres connections during application startup, but its selected 51 tests complete successfully; the required fresh-host smoke also passes.

## User Setup Required

None. Generated hosts may tune `:login_rate_limit` and `:login_rate_limit_window` in their own runtime configuration.

## Next Phase Readiness

Plan 240-02 can extend the proven explicit generated-limiter pattern to the remaining sensitive flows.

## Self-Check: PASSED

- Generated template exists at `priv/templates/sigra.install/core/rate_limit.ex`.
- Task commit `a6bb1ceb` exists.
