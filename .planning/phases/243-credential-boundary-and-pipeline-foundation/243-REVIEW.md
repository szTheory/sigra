---
phase: 243-credential-boundary-and-pipeline-foundation
reviewed: 2026-08-12T20:42:20Z
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
  critical: 0
  warning: 4
  info: 0
  total: 4
status: issues_found
---

# Phase 243: Code Review Report

**Reviewed:** 2026-08-12T20:42:20Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Re-reviewed the exact 17-file phase scope after fixes `08d77ec9` and `7864b0a9`. Both prior findings are resolved: `FetchSession` now preserves an established Scope before session-store or repository access, and the API-token scope example uses the supported `custom_scopes` key. The focused suite passes: 42 tests, 0 failures (the test bootstrap still emits its known local PostgreSQL connection-refused noise).

Four warning-level defects remain. Two executable API examples have result/error paths that do not match the public functions; the JWT-reuse example invokes the wrong revocation API with an unbound variable. Separately, malformed documented `RequireScopes` options reach an unmatched function clause at request time, and `FetchSession` delays required-option failures until the first request.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: API-token creation example cannot match the library's success result

**File:** `/Users/jon/projects/sigra/guides/flows/api-authentication.md:130-135`

**Issue:** `Sigra.Auth.create_api_token/3` returns `{:ok, raw_token, token}` (`lib/sigra/auth.ex:2205-2208`), but the documented `case` only matches `{:ok, %{raw_token: raw, token: token}}`. A host that copies the success path gets a `CaseClauseError` after creating the token, so it cannot display the one-time raw credential.

**Fix:** Match the actual three-element tuple and add a documentation assertion for the result shape.

```elixir
case Sigra.Auth.create_api_token(config, user, %{name: name, scopes: scopes}) do
  {:ok, raw, token} ->
    {:noreply, assign(socket, raw_token: raw, token: token, step: :show_raw)}

  {:error, changeset} ->
    {:noreply, assign(socket, form: to_form(changeset))}
end
```

### WR-02: JWT-reuse example calls an unrelated API with an unbound user

**File:** `/Users/jon/projects/sigra/guides/flows/api-authentication.md:244-248`

**Issue:** On `:reuse_detected`, the example calls `Sigra.Auth.revoke_all_api_tokens(config, user)`, although its surrounding handler never binds `user`. More importantly, this is the PAT revocation API, whereas `Sigra.JWT.refresh/3` already revokes the reused refresh-token family before it returns `:reuse_detected` (`lib/sigra/jwt.ex:228-240`). Copying the example therefore crashes on `user` or performs an unrelated broad PAT revocation instead of the stated JWT-family action.

**Fix:** Remove that call and explain that the refresh operation has already revoked the detected family; if application policy requires additional action, first resolve the user explicitly and document that policy separately.

```elixir
{:error, :reuse_detected} ->
  # Sigra.JWT.refresh/3 has revoked the reused refresh-token family.
  send_resp(conn, 401, "Reuse detected")
```

### WR-03: Invalid `:match` configuration crashes scoped requests instead of failing at boot

**File:** `/Users/jon/projects/sigra/lib/sigra/plug/require_scopes.ex:42-50, 75, 97-103`

**Issue:** The public contract limits `:match` to `:all` or `:any`, but `init/1` never validates it. For example, `RequireScopes.init(scopes: ["write:projects"], error_handler: Handler, match: :either)` succeeds; an authenticated request then calls `has_required_scopes?/3` with `:either`, for which no clause exists, and raises `FunctionClauseError` (500) rather than enforcing a deterministic configuration error.

**Fix:** Validate and normalize `:match` in `init/1`, and add a test that rejects unsupported values.

```elixir
match = Keyword.get(opts, :match, :all)

unless match in [:all, :any] do
  raise ArgumentError, "RequireScopes :match must be :all or :any"
end

Keyword.put(opts, :match, match)
```

### WR-04: `FetchSession` accepts incomplete plug options and crashes only on traffic

**File:** `/Users/jon/projects/sigra/lib/sigra/plug/fetch_session.ex:52-56, 71-75`

**Issue:** Unlike the newly introduced credential plugs, `FetchSession.init/1` only merges cookie defaults and does not require `:config` or `:scope_module`. A router configured without either option starts successfully; the first unauthenticated request reaches `fetch_session/2` and raises `KeyError` at `Keyword.fetch!`. This turns a deploy-time router configuration error into a production 500.

**Fix:** Fetch the two required options in `init/1` before returning the merged options, and cover each missing-option case.

```elixir
def init(opts) do
  _ = Keyword.fetch!(opts, :config)
  _ = Keyword.fetch!(opts, :scope_module)
  user_cookie_opts = Keyword.get(opts, :cookie_opts, [])
  Keyword.put(opts, :cookie_opts, Keyword.merge(@default_cookie_opts, user_cookie_opts))
end
```

---

_Reviewed: 2026-08-12T20:42:20Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
