---
phase: 243-credential-boundary-and-pipeline-foundation
reviewed: 2026-08-12T20:47:52Z
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
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 243: Code Review Report

**Reviewed:** 2026-08-12T20:47:52Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Re-reviewed the exact 17-file Phase 243 scope after commits `931d72d0`,
`55f08d76`, `5cca2a6b`, and `a2ea066a`. The four prior warnings are resolved:
the PAT example matches the public success tuple, the JWT-reuse guidance relies
on the correct refresh-family behavior, `RequireScopes.init/1` rejects invalid
match modes, and `FetchSession.init/1` rejects incomplete router options.

One documentation defect remains. The API-token expiry guidance points hosts to
the generic token-cleanup function, which cannot clean API-token rows. The
focused phase suite passes (45 tests, 0 failures), and scoped formatting passes.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: API-token expiry guidance invokes the wrong cleanup API

**File:** `/Users/jon/projects/sigra/guides/flows/api-authentication.md:217`

**Issue:** The guide says `Sigra.Workers.TokenCleanup.cleanup_expired_tokens/2`
deletes expired API-token rows. That function queries generic user-token
contexts such as `"confirm"`, `"session"`, and `"api_refresh"`
(`lib/sigra/workers/token_cleanup.ex:27-68`); an API-token schema does not have
the required `:context` field, so a host following the documented inline call
will fail with an Ecto query error. The API-token-specific function is
`cleanup_revoked_api_tokens/1`, which uses `api_token_schema` and deletes
revoked/expired rows only after the configured retention period
(`lib/sigra/workers/token_cleanup.ex:163-195`).

**Fix:** Replace the claim with the API-token-specific retention behavior and
show the correct call. Do not imply that the generic worker automatically runs
for API tokens unless the host has actually scheduled that job.

```elixir
# Schedule this from the host if retained API-token cleanup is desired.
Sigra.Workers.TokenCleanup.cleanup_revoked_api_tokens(config)
```

---

_Reviewed: 2026-08-12T20:47:52Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
