---
phase: 238-generated-auth-runtime-proof
reviewed: 2026-08-05T20:10:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/sigra/install/features/core.ex
  - lib/sigra/auth.ex
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/reset_password_live.ex
  - priv/templates/sigra.install/core/session_live.ex
  - priv/templates/sigra.install/core/settings_live.ex
  - test/example/priv/playwright/tests/generated-auth.spec.ts
  - test/sigra/install/generator_reset_test.exs
  - test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 238: Code Review Report

**Reviewed:** 2026-08-05T20:10:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

The three prior review items are resolved in the generated flow: reset submission revalidates the mounted signed token, both magic-link and reset delivery use the normalized address for lookup and issuance, and the browser logout path now uses the current-session control then proves denial at an authenticated route.

Two security defects remain in the session invalidation paths. Password reset only deletes rows from the legacy `user_tokens` table while generated sessions live in `user_sessions`, so an attacker with a reset link cannot evict a stolen existing browser session. The new current-session revocation event also accepts a client-provided session identifier without constraining the delete to the authenticated user.

Focused source-contract tests passed (37 tests), the shell harness parses, the two allowlisted Playwright tests resolve under the generated-auth project, and `git diff --check` is clean. The proposed raw-template formatter command cannot run because EEx templates are not standalone Elixir source; that does not validate or invalidate either finding.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Password reset does not revoke canonical browser sessions

**File:** `/Users/jon/projects/sigra/lib/sigra/auth.ex:1207`
**Issue:** The signed reset path removes only the supplied `user_token_schema` rows. Generated applications store browser sessions in the separate canonical `user_sessions` table (configured in `priv/templates/sigra.install/core/auth.ex:596-599`), and the reset call at `priv/templates/sigra.install/core/auth.ex:547-554` supplies no session-store deletion. Consequently, a valid password-reset completion leaves every pre-existing browser session usable, despite the generated API documentation promising that sessions are invalidated. The new two-page test only proves reset-token consumption; it has no independently authenticated session that could expose this regression.

**Fix:** In the reset transaction, delete the target user's rows from the configured session store (and broadcast any LiveView disconnects) atomically with the password update and token deletion. Pass the generated session-store configuration to `Sigra.Auth.reset_password/4`, then add a browser regression with a second, already-authenticated context that is denied after the reset.

### CR-02: Session-revocation event lacks an ownership constraint

**File:** `/Users/jon/projects/sigra/priv/templates/sigra.install/core/session_live.ex:111-115`
**Issue:** Both revocation events decode the client-controlled `phx-value-token` and call `Auth.revoke_session/1`. That wrapper forwards no `user_id` to `Sigra.Auth.revoke_session/3` (`priv/templates/sigra.install/core/auth.ex:619-621`). The library explicitly deletes any supplied session when `user_id` is absent and only enforces ownership when it is present (`lib/sigra/auth.ex:1502-1521`). A signed-in user who obtains another user's hashed session identifier can therefore cause a cross-account logout by altering the LiveView event payload.

**Fix:** Change the generated wrapper to accept the authenticated user (or user ID) and call `Sigra.Auth.revoke_session(sigra_config(), hashed_token, user_id: user.id)`; invoke it in both handlers with `socket.assigns.current_scope.user`. Add a regression that submits a foreign session hash and asserts it remains present.

---

_Reviewed: 2026-08-05T20:10:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
