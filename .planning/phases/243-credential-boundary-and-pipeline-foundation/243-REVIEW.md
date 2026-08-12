---
phase: 243-credential-boundary-and-pipeline-foundation
reviewed: 2026-08-12T20:31:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - guides/flows/api-authentication.md
  - guides/introduction/contract.md
  - guides/recipes/companion-libs/lockspire.md
  - lib/sigra/plug/credential_auth.ex
  - lib/sigra/plug/fetch_api_token.ex
  - lib/sigra/plug/fetch_app_session.ex
  - lib/sigra/plug/fetch_bearer.ex
  - lib/sigra/plug/fetch_jwt.ex
  - lib/sigra/plug/fetch_session.ex
  - lib/sigra/plug/require_scopes.ex
  - test/sigra/credential_boundary_docs_test.exs
  - test/sigra/plug/fetch_api_token_test.exs
  - test/sigra/plug/fetch_app_session_test.exs
  - test/sigra/plug/fetch_bearer_test.exs
  - test/sigra/plug/fetch_jwt_test.exs
  - test/sigra/plug/fetch_session_test.exs
  - test/sigra/plug/require_scopes_test.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 243: Code Review Report

**Reviewed:** 2026-08-12T20:31:00Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

The explicit credential pipelines correctly avoid placing raw credentials in the Scope or trusted-facts map, and the browser-session path reloads the user. However, the direct JWT pipeline ignores the configuration switch that is documented as disabling JWT support, so a route that installs it can authenticate otherwise-disabled JWTs. The API guide also retains a code sample for an API that does not exist.

Focused Phase 243 tests passed (42 tests, 0 failures); the test bootstrap emitted its known local PostgreSQL connection-refused noise.

## Critical Issues

### CR-01: Disabled JWT support still authenticates through the explicit pipeline

**File:** `lib/sigra/plug/fetch_jwt.ex:35-44`

**Issue:** `FetchJWT` calls `Sigra.JWT.verify_access/2` without checking `config.jwt[:enabled]`. `verify_access/2` itself verifies a signed token regardless of that flag (`lib/sigra/jwt.ex:127-149`); only token generation checks it. Consequently, adding `FetchJWT` to a router while `jwt: [enabled: false]` still accepts valid JWTs signed with the configured key, contradicting the documented opt-in setting and allowing a disabled credential type to authenticate and authorize requests.

**Fix:** Fail closed before verification when JWT is not enabled, and add a regression test that presents a correctly signed JWT to a disabled-JWT config and asserts a nil Scope with no `:sigra_auth` facts.

```elixir
defp fetch(conn, opts) do
  config = Keyword.fetch!(opts, :config)

  if Keyword.get(config.jwt, :enabled, false) do
    fetch_enabled_jwt(conn, opts, config)
  else
    Plug.Conn.assign(conn, :current_scope, nil)
  end
end
```

## Warnings

### WR-01: API guide calls a nonexistent scope-enforcement API

**File:** `guides/flows/api-authentication.md:179-187`

**Issue:** The guide instructs users to call `Sigra.APIToken.require_scope/2`, but there is no such function in `lib/` or the test suite. Following the documented route-level authorization example therefore raises `UndefinedFunctionError`; it also bypasses the newly introduced `RequireScopes` trusted-facts boundary described earlier in the same guide.

**Fix:** Replace the controller example with router-level `Sigra.Plug.RequireScopes` configuration (including the host error handler), or implement and document a real API that delegates to the same trusted-facts check. Add an assertion to `CredentialBoundaryDocsTest` that the primary guide names `RequireScopes` and does not reference `APIToken.require_scope`.

---

_Reviewed: 2026-08-12T20:31:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
