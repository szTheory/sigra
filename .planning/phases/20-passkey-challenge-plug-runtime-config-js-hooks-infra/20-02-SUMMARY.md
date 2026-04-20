---
phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
plan: 02
subsystem: auth
tags: [passkeys, webauthn, config, rate-limiting, persistent-term, nimble-options]
requires:
  - phase: 19-passkey-schema-contexts
    provides: passkey registration/authentication contexts and config-first ceremony primitives
provides:
  - cached runtime passkey config loading with strict RP validation
  - passkey config schema keys for rp_name and ceremony_rate_limit
  - per-user ceremony initiation throttling in Sigra.Passkeys
affects: [phase-21-passkey-liveviews, runtime-config, passkey-ceremony-entrypoints]
tech-stack:
  added: []
  patterns: [persistent_term runtime config cache, config-first passkey limiter wrapper]
key-files:
  created:
    - test/sigra/passkeys/config_test.exs
    - test/sigra/passkeys/rate_limit_test.exs
  modified:
    - lib/sigra/config.ex
    - lib/sigra/passkeys.ex
key-decisions:
  - "Sigra.Passkeys.config/0 caches the validated %Sigra.Config{} in :persistent_term and exposes reset_cached_config/0 for tests."
  - "Runtime passkey validation raises on blank rp_id or origin and enforces a bounded timeout_ms range before ceremony code runs."
  - "rate_limit_ceremony/3 uses the configured Sigra.RateLimiter module with a fixed sigra:passkeys:<ceremony>:user:<id> namespace and fail-open behavior when no limiter is configured."
patterns-established:
  - "Runtime passkey config is resolved once from :sigra/:otp_app and host :sigra_config, then passed around as a validated Sigra.Config struct."
  - "Per-user ceremony throttling belongs in Sigra.Passkeys rather than ad hoc callers so later phases reuse one key shape and error contract."
requirements-completed: [PK-09, PK-10]
duration: 4min
completed: 2026-04-15
---

# Phase 20 Plan 02: Runtime passkey config cache and per-user ceremony throttling Summary

**Cached WebAuthn runtime config with loud RP validation, exposed `rp_name` and `ceremony_rate_limit` defaults, and locked per-user ceremony limiter keys in `Sigra.Passkeys`**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-15T17:10:00Z
- **Completed:** 2026-04-15T17:14:09Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added focused RED tests for runtime passkey config caching, RP validation failures, default config keys, and per-user ceremony limiter behavior.
- Extended the passkey config schema with `rp_name` and nested `ceremony_rate_limit` defaults in both the docs-facing and runtime `NimbleOptions` schema blocks.
- Implemented `Sigra.Passkeys.config/0`, `reset_cached_config/0`, and `rate_limit_ceremony/3` with `:persistent_term` caching, timeout bounds, and stable limiter key formatting.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write runtime config and ceremony-rate-limit tests** - `6e888aa` (test)
2. **Task 2: Implement strict runtime passkey config loading and per-user throttling** - `9cc31b3` (feat)

## Files Created/Modified
- `lib/sigra/config.ex` - Adds `rp_name` and `ceremony_rate_limit` to the passkey schema and default docs.
- `lib/sigra/passkeys.ex` - Adds cached runtime config loading, strict passkey validation, and per-user ceremony rate limiting.
- `test/sigra/passkeys/config_test.exs` - Covers config caching/reset, RP validation failures, and required passkey defaults.
- `test/sigra/passkeys/rate_limit_test.exs` - Covers ceremony limiter key shape, limiter argument forwarding, and sixth-hit denial.

## Decisions Made
- Used `:persistent_term` for the runtime passkey config cache so ceremony entry points stop re-reading application env after first resolution.
- Kept RP validation in `Sigra.Passkeys` rather than a second config subsystem, which preserves the `%Sigra.Config{}` contract already established in Sigra.
- Normalized the public `ceremony_rate_limit` keyword order to `[limit: ..., window_ms: ...]` so later callers and tests see a stable shape.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced stale `mix test -x` verification usage**
- **Found during:** Task 1 (Write runtime config and ceremony-rate-limit tests)
- **Issue:** The plan's verify command used `-x`, which is no longer accepted by this Mix version.
- **Fix:** Switched execution to `mix test --max-failures 1` for equivalent fail-fast verification.
- **Files modified:** None
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs --max-failures 1`
- **Committed in:** N/A (execution-time adjustment only)

**2. [Rule 1 - Bug] Corrected newly-added config tests to assert the intended failure cases**
- **Found during:** Task 2 (Implement strict runtime passkey config loading and per-user throttling)
- **Issue:** The new tests over-escaped the validation regex and shallow-merged `passkeys` overrides, which made the origin-missing test fail on `rp_id` first.
- **Fix:** Simplified the regex and deep-merged `passkeys` overrides in the test helper.
- **Files modified:** `test/sigra/passkeys/config_test.exs`
- **Verification:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs --max-failures 1`
- **Committed in:** `9cc31b3`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both deviations were narrow correctness fixes. No scope expansion beyond the plan.

## Issues Encountered

- `lib/sigra/config.ex` defines the passkey schema in both the docs block and the runtime `@schema`; both needed to be updated for `ceremony_rate_limit` to validate correctly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 21 can call `Sigra.Passkeys.config/0` once, trust that RP identity is present, and reuse `rate_limit_ceremony/3` without inventing a new key namespace.
- The passkey runtime contract is now fixed around `%Sigra.Config{}` defaults and a stable `{:error, :rate_limited, %{retry_after_ms: ...}}` denial shape.

## Self-Check: PASSED

- Verified `.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-02-SUMMARY.md` exists.
- Verified commits `6e888aa` and `9cc31b3` exist in git history.

---
*Phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra*
*Completed: 2026-04-15*
