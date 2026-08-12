---
phase: 240-alpha-operations-rehearsal
plan: "02"
subsystem: auth
tags: [hammer, rate-limiting, phoenix, generated-host, golden-fixture, security]
requires:
  - phase: 240-05
    provides: RED source contracts for the full route/context limiter map
  - phase: 240-01
    provides: Generated Hammer dependency, process, and canonical login limiter
provides:
  - Explicit, independent Hammer ownership for every generated mutating B2C controller boundary
  - Context-level Hammer limits for magic-link and password-reset mail requests
  - Refreshed byte-exact installer fixture and repeat-install contract
affects: [240-03, 240-04, generated-host, b2c-alpha]
tech-stack:
  added: []
  patterns: [route-owned IP limits, context-owned normalized-email limits, deterministic golden reblessing]
key-files:
  created:
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/rate_limit.ex
  modified:
    - lib/sigra/install/features/core.ex
    - priv/templates/sigra.install/core/auth.ex
    - test/sigra/install/generated_rate_limit_context_test.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
    - test/fixtures/install_golden/tree/config/config.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/application.ex
key-decisions:
  - "Each mutating generated controller action uses an independent stable prefix; safe GET and HEAD token/form paths remain outside route throttling."
  - "Magic-link and reset mail requests are limited at their Auth context boundary with three requests per 60,000 milliseconds and their existing normalized-email keys."
  - "The fixture is reblessed only from a fresh installer run, and the repeat-install dependency injection retains a separator for valid generated Mix syntax."
patterns-established:
  - "LiveView email requests must use context-level rate limiting; a router plug does not cover handle_event/3."
  - "Generated dependency snippets inserted at the start of deps/0 must include their own trailing separator."
requirements-completed: [OPS-01]
coverage:
  - id: D1
    description: Canonical generated B2C controller actions and anonymous mail-request seams own independent Hammer limits.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: mix test test/sigra/install/generated_rate_limit_context_test.exs test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/plug/rate_limit_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: A fresh generated host exactly matches the committed fixture and a repeated installation is idempotent.
    requirement: OPS-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs
        status: pass
      - kind: integration
        ref: MIX_ENV=test mix sigra.fixture.rebless_golden --check
        status: pass
    human_judgment: false
metrics:
  duration: 9min
  completed: 2026-08-10
status: complete
---

# Phase 240 Plan 02: Complete Generated B2C Limiter Map Summary

**Generated B2C hosts now limit each mutating controller action by IP and each anonymous mail request by normalized email, with exact installer fixture parity.**

## Performance

- **Duration:** 9 min
- **Tasks:** 2/2
- **Files modified:** 26

## Accomplishments

- Added independent Hammer route prefixes for login, sudo, registration, confirmation request/resend, reset request/update, and MFA controller actions in controller-mode generated hosts.
- Passed explicit Hammer adapter and bounded integer mail-request options through generated magic-link and reset Auth wrappers while retaining generic anti-enumeration outcomes.
- Reblessed and checked the fresh-install fixture, including the generated limiter module, application child, configuration, context calls, and router output.
- Fixed the generated Hammer dependency snippet so a second `mix sigra.install` keeps the generated dependency list syntactically valid and idempotent.

## Task Commits

1. **Task 1: Map and enforce every route and context limiter boundary** — `bb78db5d` (RED test), `318073c9` (feature)
2. **Task 2: Regenerate and verify exact installer golden parity** — `044c6cbe` (fixture refresh and repeat-install correction)

## Verification

- PASS — `mix test test/sigra/install/generated_rate_limit_context_test.exs test/sigra/install/generated_rate_limit_contract_test.exs test/sigra/plug/rate_limit_test.exs` (25 tests)
- PASS — `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs`
- PASS — `MIX_ENV=test mix sigra.fixture.rebless_golden --check`

The selected source-contract tests emit local PostgreSQL connection-refused log noise during application startup, but all selected tests complete successfully without database access.

## Decisions Made

- Used the conservative, host-overridable route default of three requests per 60 seconds and explicit context defaults of three requests per 60,000 milliseconds.
- Kept token-consumption and form-render GET/HEAD routes unthrottled; the generated plug handles only mutating controller requests.
- Kept LiveView mail-request UX generic on context limiter denial so neither absent accounts nor the limiter implementation are disclosed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Contract correction] Aligned the Wave 0 context test with the actual generated wrapper and library key seams.**
- **Found during:** Task 1
- **Issue:** The RED contract looked for obsolete user-facing copy and literal placeholder key strings rather than the wrapper invocation and normalized-key implementation.
- **Fix:** Kept the required behavioral assertions while targeting the generated Auth wrapper and `Sigra.Auth` normalized key prefixes.
- **Files modified:** `test/sigra/install/generated_rate_limit_context_test.exs`
- **Verification:** Focused route/context, ownership, and plug suites pass.
- **Committed in:** `318073c9`

**2. [Rule 1 - Bug] Preserved the dependency-list separator in generated `mix.exs`.**
- **Found during:** Task 2
- **Issue:** The generated Hammer dependency lacked a trailing comma, so a repeat install placed it immediately before the pre-existing Sigra path dependency and produced invalid Mix syntax.
- **Fix:** Added the dependency separator to the generated payload.
- **Files modified:** `lib/sigra/install/features/core.ex`
- **Verification:** `MIX_ENV=test mix test test/sigra/install/idempotency_test.exs` passes.
- **Committed in:** `044c6cbe`

**3. [Rule 3 - Blocking] Reblessed all current deterministic fixture paths.**
- **Found during:** Task 2
- **Issue:** The committed fixture had 21 stale generated paths in addition to the limiter output, preventing byte-exact golden verification.
- **Fix:** Regenerated the fixture only through `sigra.fixture.rebless_golden`, reviewed its scoped delta, and confirmed check-mode parity.
- **Files modified:** `test/fixtures/install_golden/`
- **Verification:** Golden diff, idempotency, and rebless check pass.
- **Committed in:** `044c6cbe`

**Total deviations:** 3 auto-fixed (2 Rule 1, 1 Rule 3). **Impact:** Required for deterministic, syntax-valid generated-host parity; no runtime scope expansion.

## Known Stubs

None.

## Next Phase Readiness

OPS-01's full route/context limiter map and generated-host parity are complete. Plans 240-03 and 240-04 can rely on these deterministic, no-secrets generated-host contracts.

## Self-Check: PASSED

- Required generated fixture and source files exist.
- Task commits `bb78db5d`, `318073c9`, and `044c6cbe` exist in git history.
