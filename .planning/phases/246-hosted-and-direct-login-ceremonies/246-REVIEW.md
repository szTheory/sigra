---
phase: 246-hosted-and-direct-login-ceremonies
reviewed: 2026-08-16T21:11:44Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - .github/workflows/generated-app-login-runtime-proof.yml
  - guides/flows/api-authentication.md
  - guides/introduction/contract.md
  - lib/sigra/app_login.ex
  - lib/sigra/app_login/attempt.ex
  - lib/sigra/install/features/app_sessions.ex
  - priv/templates/sigra.install/app_sessions/app_login_approve.html.heex
  - priv/templates/sigra.install/app_sessions/app_login_continuation.ex
  - priv/templates/sigra.install/app_sessions/app_login_controller.ex
  - priv/templates/sigra.install/app_sessions/app_login_html.ex
  - priv/templates/sigra.install/app_sessions/app_sessions_migration.exs
  - priv/templates/sigra.install/app_sessions/auth_app_sessions.ex
  - priv/templates/sigra.install/app_sessions/first_party_apps.ex
  - priv/templates/sigra.install/app_sessions/router_injection.ex
  - priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex
  - priv/templates/sigra.install/app_sessions/user_app_session_family.ex
  - priv/templates/sigra.install/app_sessions/user_app_session_token.ex
  - priv/templates/sigra.install/core/mfa_challenge_controller.ex
  - priv/templates/sigra.install/core/mfa_challenge_live.ex
  - priv/templates/sigra.install/core/session_controller.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - scripts/ci/generated-app-login-runtime-proof.sh
  - test/sigra/app_login/concurrency_test.exs
  - test/sigra/app_login_audit_cofate_test.exs
  - test/sigra/app_login_direct_fault_test.exs
  - test/sigra/app_login_direct_test.exs
  - test/sigra/app_login_test.exs
  - test/sigra/credential_boundary_docs_test.exs
  - test/sigra/install/app_sessions_auth_continuation_test.exs
  - test/sigra/install/app_sessions_generator_test.exs
  - test/sigra/install/app_sessions_mfa_session_upgrade_test.exs
  - test/sigra/install/app_sessions_routes_test.exs
  - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
  - test/support/app_login_schemas.ex
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: issues_found
---

# Phase 246: Code Review Report

**Reviewed:** 2026-08-16T21:11:44Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Reviewed the hosted/direct app-login ceremony, generated persistence and route templates, MFA handoff, documentation, and runtime-proof automation. No shipping correctness or security defect was proven from the reviewed implementation. One scoped test emits a compiler warning, which makes warning-clean validation noisier and can conceal later warnings.

Focused test execution completed the non-database cases, but database-backed cases could not run because the configured local Postgres endpoint (`127.0.0.1:53988`) refused connections.

## Narrative Findings (AI reviewer)

## Info

### IN-01: Runtime-proof contract test emits an unused-variable compiler warning

**File:** `test/sigra/planning/phase_246_generated_app_login_runtime_test.exs:456`
**Issue:** The `for contract <- ...` loop never reads `contract`; its assertion is a literal interpolation string (`"${mode}_post_ceremony_${contract}"`), so compilation emits an unused-variable warning. This was reproduced by the focused test command.
**Fix:** Either reference the Elixir variable in the expected string, for example `assert harness =~ "${mode}_post_ceremony_#{contract}"`, or replace the loop with one literal assertion if only the literal shell expansion is intended.

---

_Reviewed: 2026-08-16T21:11:44Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
