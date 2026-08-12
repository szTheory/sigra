---
phase: 243-credential-boundary-and-pipeline-foundation
reviewed: 2026-08-12T20:36:30Z
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
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 243: Code Review Report

**Reviewed:** 2026-08-12T20:36:30Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Re-reviewed the exact original scope after fixes `83ac6faf` and `fc707254`. CR-01 is resolved: `FetchJWT` now fails closed when JWT support is disabled, with a regression test using a correctly signed token. WR-01 is resolved: the guide now uses `Sigra.Plug.RequireScopes` rather than the nonexistent `Sigra.APIToken.require_scope/2` API.

The focused Phase 243 suite passes (40 tests, 0 failures). The test bootstrap emits known local PostgreSQL connection-refused noise. Two warning-level defects remain: session authentication violates the documented ordered-pipeline contract, and the guide gives an invalid API-token scopes configuration key.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: FetchSession clobbers an earlier successful credential pipeline

**File:** `lib/sigra/plug/fetch_session.ex:63-107`

**Issue:** Unlike `FetchAPIToken`, `FetchJWT`, `FetchAppSession`, and `FetchBearer`, `FetchSession.call/2` never returns an existing `:current_scope` unchanged. In an intentionally ordered mixed pipeline, a valid PAT/JWT authenticated by an earlier plug is overwritten by the browser-session result: a missing or invalid cookie sets the Scope to `nil`, while a valid cookie silently changes the authenticated principal. This violates the guide's explicit "first successful normal Scope wins" contract and makes the documented host-selected ordering nonfunctional whenever `FetchSession` appears after another credential plug.

**Fix:** Short-circuit before reading the session, matching the other explicit plugs, and add tests for both a pre-existing Scope with no session token and a pre-existing Scope with a valid session token (assert no store or repo interaction).

```elixir
def call(conn, opts) do
  if conn.assigns[:current_scope] do
    conn
  else
    fetch_session(conn, opts)
  end
end
```

Move the current body into `fetch_session/2` unchanged.

### WR-02: API-token scope configuration example cannot be validated

**File:** `guides/flows/api-authentication.md:172-177`

**Issue:** The guide configures `api_token: [scopes: [...]]`, but `Sigra.Config` defines the supported key as `:custom_scopes` (`lib/sigra/config.ex:762-818`). A host that copies the documented example gets a `NimbleOptions` unknown-option validation error instead of configuring available token scopes.

**Fix:** Use the actual configuration key and add a docs assertion that rejects the obsolete `api_token: [scopes:` example.

```elixir
config :my_app, MyApp.Auth.Config,
  api_token: [
    custom_scopes: ["read:projects", "write:projects", "admin"]
  ]
```

---

_Reviewed: 2026-08-12T20:36:30Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
