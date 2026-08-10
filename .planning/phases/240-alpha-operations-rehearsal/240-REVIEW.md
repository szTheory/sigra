---
phase: 240-alpha-operations-rehearsal
reviewed: 2026-08-10T22:36:00Z
depth: deep
files_reviewed: 15
files_reviewed_list:
  - lib/sigra/install/features/core.ex
  - lib/sigra/plug/rate_limit.ex
  - lib/sigra/rate_limiters/hammer.ex
  - priv/templates/sigra.install/core/auth.ex
  - scripts/ci/passkeys-opt-out-smoke.sh
  - scripts/ci/generated-auth-runtime-proof.sh
  - .github/workflows/ci.yml
  - .github/workflows/generated-auth-runtime-proof.yml
  - guides/recipes/b2c-alpha.md
  - test/sigra/install/generated_rate_limit_contract_test.exs
  - test/sigra/install/generated_rate_limit_context_test.exs
  - test/sigra/planning/phase_240_no_secrets_ci_test.exs
  - test/sigra/plug/rate_limit_test.exs
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/fixtures/install_golden/tree/config/config.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 240: Code Review Re-review Report

**Reviewed:** 2026-08-10T22:36:00Z
**Depth:** deep
**Files Reviewed:** 15
**Status:** issues_found

## Summary

The original generated-router compile defect is resolved: generated rate limiters are valid Phoenix pipelines and protected routes use those pipelines through separate scopes. Route-level values now resolve per request, both credential-free harnesses clear inherited Google credentials before any Mix invocation, and the LiveView and `--no-live` lanes each compile their generated host.

Original finding disposition: **CR-01 resolved; WR-01 resolved; WR-02 resolved; WR-03 resolved.** One follow-on warning remains in the newly configurable context mail-request limits.

## Narrative Findings (AI reviewer)

## Warnings

### WR-04: Context runtime overrides can silently disable mail-request throttling

**File:** `priv/templates/sigra.install/core/auth.ex:143-144,475-476`

**Issue:** Magic-link and reset values are passed directly from `Application.get_env/3` to `Sigra.RateLimiters.Hammer`. Unlike route values, which use `runtime_positive_integer/2` in `lib/sigra/plug/rate_limit.ex:67-68,107-113`, the context values accept zero, negatives, strings, or other malformed runtime configuration. Hammer raises for invalid scale/limit values and `Sigra.RateLimiters.Hammer.check_rate/3` rescues every exception as `{:allow, 0}` (`lib/sigra/rate_limiters/hammer.ex:31-38`). A configuration typo therefore silently fails open and removes throttling from magic-link or password-reset requests.

**Fix:** Resolve these two option pairs through a shared positive-integer runtime-config helper, falling back to the generated defaults before calling `SigraAuth.request_magic_link/3` and `Sigra.Auth.request_password_reset/3`. Add generated-context tests for `0`, negative, and non-integer overrides to prove that each falls back rather than reaching Hammer.

---

_Reviewed: 2026-08-10T22:36:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
