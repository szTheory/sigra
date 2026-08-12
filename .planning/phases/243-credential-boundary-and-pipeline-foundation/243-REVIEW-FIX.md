---
phase: 243
fixed_at: 2026-08-12T20:45:27Z
review_path: .planning/phases/243-credential-boundary-and-pipeline-foundation/243-REVIEW.md
iteration: 4
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 243: Code Review Fix Report

**Fixed at:** 2026-08-12T20:45:27Z
**Source review:** `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-REVIEW.md`
**Iteration:** 4

**Summary:**

- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: API-token creation example cannot match the library's success result

**Files modified:** `guides/flows/api-authentication.md`, `test/sigra/credential_boundary_docs_test.exs`
**Commit:** 931d72d0
**Applied fix:** Corrected the example to match `{:ok, raw, token}` and added a documentation regression assertion for the public tuple shape.

### WR-02: JWT-reuse example calls an unrelated API with an unbound user

**Files modified:** `guides/flows/api-authentication.md`, `test/sigra/credential_boundary_docs_test.exs`
**Commit:** 55f08d76
**Applied fix:** Removed the unrelated PAT revocation call and documented that `refresh_jwt/2` already revokes the detected refresh-token family before returning `:reuse_detected`.

### WR-03: Invalid `:match` configuration crashes scoped requests instead of failing at boot

**Status:** fixed: requires human verification
**Files modified:** `lib/sigra/plug/require_scopes.ex`, `test/sigra/plug/require_scopes_test.exs`
**Commit:** 5cca2a6b
**Applied fix:** `RequireScopes.init/1` now defaults and validates `:match` as `:all` or `:any`, rejecting unsupported values at router initialization.

### WR-04: `FetchSession` accepts incomplete plug options and crashes only on traffic

**Files modified:** `lib/sigra/plug/fetch_session.ex`, `test/sigra/plug/fetch_session_test.exs`
**Commit:** a2ea066a
**Applied fix:** `FetchSession.init/1` now requires `:config` and `:scope_module`, with regression tests for both missing-option cases.

---

_Fixed: 2026-08-12T20:45:27Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 4_
