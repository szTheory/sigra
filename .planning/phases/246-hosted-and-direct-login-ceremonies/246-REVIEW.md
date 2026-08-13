---
phase: 246-hosted-and-direct-login-ceremonies
reviewed: 2026-08-12T00:00:00Z
depth: standard
files_reviewed: 39
files_reviewed_list:
  - .github/workflows/generated-app-login-runtime-proof.yml
  - guides/flows/api-authentication.md
  - guides/introduction/contract.md
  - lib/mix/tasks/sigra.install.ex
  - lib/sigra/app_login.ex
  - lib/sigra/app_login/attempt.ex
  - lib/sigra/app_login/pkce.ex
  - lib/sigra/app_session.ex
  - lib/sigra/config.ex
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
  - test/mix/tasks/sigra.install_test.exs
  - test/sigra/app_login/concurrency_test.exs
  - test/sigra/app_login_audit_cofate_test.exs
  - test/sigra/app_login_direct_fault_test.exs
  - test/sigra/app_login_direct_test.exs
  - test/sigra/app_login_test.exs
  - test/sigra/config_test.exs
  - test/sigra/credential_boundary_docs_test.exs
  - test/sigra/install/app_sessions_auth_continuation_test.exs
  - test/sigra/install/app_sessions_generator_test.exs
  - test/sigra/install/app_sessions_routes_test.exs
  - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
  - test/support/app_login_schemas.ex
findings:
  critical: 3
  warning: 2
  info: 0
  total: 5
status: issues_found
---

# Phase 246: Code Review Report

**Reviewed:** 2026-08-12T00:00:00Z
**Depth:** standard
**Files Reviewed:** 39
**Status:** issues_found

## Summary

The generated hosted ceremony is not operable end-to-end: its exchange controller rejects the required callback field, and approval cannot insert into the generated schema. The browser route also treats an MFA-pending session as sufficient assurance to mint an app credential. The fresh-host CI lane does not exercise a valid ceremony, so it currently masks these failures.

## Critical Issues

### CR-01: Generated exchange endpoint rejects every valid request

**File:** `priv/templates/sigra.install/app_sessions/app_login_controller.ex:57-60`
**Issue:** The map pattern requires `callback`, but the exact-key guard immediately requires a list that omits `"callback"`. Any request containing all required fields fails the guard, while a request without callback fails the pattern. Therefore no hosted authorization code can be exchanged through a generated host.
**Fix:** Include `callback` in the exact key list and add a controller/integration test for a successful exchange.

```elixir
with %{"code" => code, "code_verifier" => verifier, "profile_id" => profile,
       "callback" => callback} <- params,
     ["callback", "code", "code_verifier", "profile_id"] <- Enum.sort(Map.keys(params)),
     {:ok, credentials} <- AppSessions.exchange_hosted(code, verifier, profile, callback) do
  json(conn, credentials)
end
```

### CR-02: Hosted approval cannot persist to the generated attempt table

**File:** `lib/sigra/app_login.ex:82-90`
**Issue:** Approval inserts no `kind`, but the generated `user_app_login_attempts.kind` column is `NOT NULL` (`priv/templates/sigra.install/app_sessions/app_sessions_migration.exs:37-40`). Every hosted approval on an installed host consequently returns `:invalid_continuation` instead of creating its code. The in-repo test schema omits this column, hiding the production failure.
**Fix:** Persist the discriminator expected by the generated `Ecto.Enum`, and test against the actual generated schema/migration contract.

```elixir
struct!(schema, %{
  kind: :hosted_code,
  digest: Token.hash_token(code),
  # ...
})
```

### CR-03: MFA-pending browser sessions can approve and mint app credentials

**File:** `priv/templates/sigra.install/app_sessions/app_login_controller.ex:7,15-18,90-94`
**Issue:** `require_authenticated_browser/2` and `start/2` accept any `current_scope.user`; neither rejects `conn.private[:sigra_session]` with `type: :mfa_pending`. The generated route uses only `[:browser, :app_login_public]` (`router_injection.ex:13-19`), so its normal MFA-enforcement plug is not applied. A user who has completed only the password stage can directly visit a valid `/users/app-login` URL, approve it, and receive a first-party session without completing MFA.
**Fix:** Require a fully authenticated, non-`:mfa_pending` browser session before rendering or accepting approval/continuation; redirect pending sessions to `/users/mfa` while preserving only the signed continuation handle. Add a regression test starting from an MFA-pending session.

## Warnings

### WR-01: Generated direct MFA route cannot use backup codes

**File:** `priv/templates/sigra.install/app_sessions/app_login_controller.ex:79-85`
**Issue:** The facade wires both `mfa_verify/2` and `mfa_verify_backup/2` (`auth_app_sessions.ex:53-57`), but the HTTP endpoint accepts no factor selector and calls `complete_direct_mfa/2`, which defaults to `:totp`. Direct clients therefore cannot complete an MFA challenge with the advertised backup-code verifier.
**Fix:** Accept one exact, validated factor field (for example `"factor" => "totp" | "backup_code"`), map it to a trusted atom in the facade, and reject all other values with the existing uniform failure response.

### WR-02: Fresh-host proof does not prove a successful generated ceremony

**File:** `scripts/ci/generated-app-login-runtime-proof.sh:109-116`
**Issue:** The only HTTP checks intentionally submit malformed requests. The subsequent lifecycle tests run in the Sigra repository against hand-written test schemas, not the generated host. This lane therefore passes despite the generated exchange contradiction and missing `kind` above, while its receipt claims callback/state, approval, replay, and fault proof.
**Fix:** Drive one valid hosted start → browser approval → redirect code → exchange flow in the generated application, and assert persisted attempt kind plus one-use behavior there. Keep the malformed-input probes as separate negative checks.

---

_Reviewed: 2026-08-12T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
