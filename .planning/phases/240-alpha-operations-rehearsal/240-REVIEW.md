---
phase: 240-alpha-operations-rehearsal
reviewed: 2026-08-10T22:23:16Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - lib/sigra/install/features/core.ex
  - priv/templates/sigra.install/core/rate_limit.ex
  - priv/templates/sigra.install/core/auth.ex
  - scripts/ci/passkeys-opt-out-smoke.sh
  - scripts/ci/generated-auth-runtime-proof.sh
  - .github/workflows/ci.yml
  - .github/workflows/generated-auth-runtime-proof.yml
  - guides/recipes/b2c-alpha.md
  - guides/recipes/deployment.md
  - test/sigra/install/generated_rate_limit_contract_test.exs
  - test/sigra/install/generated_rate_limit_context_test.exs
  - test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs
  - test/sigra/planning/phase_240_no_secrets_ci_test.exs
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/fixtures/install_golden/tree/config/config.exs
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/rate_limit.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/application.ex
findings:
  critical: 1
  warning: 3
  info: 0
  total: 4
status: issues_found
---

# Phase 240: Code Review Report

**Reviewed:** 2026-08-10T22:23:16Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

The submitted generated-host rate-limit implementation has a release-blocking Phoenix router error: it emits `plug` declarations inside `scope` blocks, where Phoenix rejects them. The focused source-contract tests pass, but they do not compile a generated router, so they miss this failure. Runtime rate-limit overrides and no-secret lane boundaries also do not meet the documented contract.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: BLOCKER — generated router cannot compile because rate-limit plugs are outside pipelines

**File:** `lib/sigra/install/features/core.ex:553` (rendered at `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex:93`)

**Issue:** `rate_limit_route/2` renders `plug Sigra.Plug.RateLimit` directly inside a `scope`. `Phoenix.Router.plug/2` is valid only while defining a `pipeline`; its macro raises `cannot define plug at the router level, plug must be defined inside a pipeline` otherwise. Every generated B2C router contains this invalid form, so the new limiter output prevents the host application from compiling rather than protecting its POST route. The source-only contracts pass because none compiles this generated router.

**Fix:** Define a dedicated rate-limit pipeline for each protected flow (or a route-specific wrapper plug/controller), then place that pipeline in a separate `scope`'s `pipe_through` list for the one mutating route. Add a generated-host compilation/integration test for both live and `--no-live` output; source-string assertions alone cannot prove router validity.

## Warnings

### WR-01: Runtime rate-limit overrides are evaluated at router compilation, not at request time

**File:** `lib/sigra/install/features/core.ex:557-558`

**Issue:** The generated options call `Application.get_env/3` in the router DSL. Once the declarations are moved into valid pipelines, those expressions are evaluated while the router module compiles and become pipeline options; changing `config/runtime.exs` on a release will not update the supposedly host-configurable limits/windows. This contradicts the generated comment and the recipe's claim that operators can tune the generated runtime limits.

**Fix:** Resolve the configured limit/window in code that runs for each request (for example, a small generated wrapper plug that invokes `Sigra.Plug.RateLimit` with current values), or explicitly make these compile-time configuration values and remove the runtime-override guidance. Add a release/runtime-config regression test.

### WR-02: Context mail-request limits are fixed constants and cannot be tuned through the documented host configuration

**File:** `priv/templates/sigra.install/core/auth.ex:142-144` and `priv/templates/sigra.install/core/auth.ex:474-476`

**Issue:** Magic-link and password-reset paths hard-code `max_requests: 3` and `window_ms: 60_000`. Unlike the router paths, they have no generated configuration keys. The B2C recipe tells hosts to set generated limiter ceilings/windows, but those changes cannot affect these LiveView/context-only sensitive flows.

**Fix:** Add distinct host configuration keys for magic-link and reset limits/windows and read them in the context functions at runtime. Document all flow keys and cover each override in generated-host tests.

### WR-03: Fresh-generator lane leaves inherited Google credentials in its process environment

**File:** `scripts/ci/passkeys-opt-out-smoke.sh:24-35`; insufficient contract at `test/sigra/planning/phase_240_no_secrets_ci_test.exs:90-95`

**Issue:** The runtime proof unsets `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`, but the independent fresh-generator script does not. This violates the stated two-lane credential-free boundary and allows an ambient developer/runner credential to be visible to `mix sigra.gen.oauth` or any generated-host process it launches. The source contract only asserts unsetting in the runtime script, so it cannot prevent regression in the generator lane.

**Fix:** Unset both Google variables at the top of `passkeys-opt-out-smoke.sh` before any Mix invocation, and require the unset statement in the generator-harness branch of `Phase240NoSecretsCiTest`.

---

_Reviewed: 2026-08-10T22:23:16Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
