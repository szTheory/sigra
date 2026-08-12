---
phase: 243
fixed_at: 2026-08-12T20:39:32Z
review_path: .planning/phases/243-credential-boundary-and-pipeline-foundation/243-REVIEW.md
iteration: 2
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 243: Code Review Fix Report

**Fixed at:** 2026-08-12T20:39:32Z
**Source review:** `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-REVIEW.md`
**Iteration:** 2

**Summary:**

- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-01: FetchSession clobbers an earlier successful credential pipeline

**Status:** fixed: requires human verification
**Files modified:** `lib/sigra/plug/fetch_session.ex`, `test/sigra/plug/fetch_session_test.exs`
**Commit:** 08d77ec9
**Applied fix:** `FetchSession` now returns an existing normal Scope before consulting the Plug session, session store, or repository. Regression tests cover both an empty session and a present valid-token-shaped session without mock expectations, proving neither collaborator is invoked.

### WR-02: API-token scope configuration example cannot be validated

**Files modified:** `guides/flows/api-authentication.md`, `test/sigra/credential_boundary_docs_test.exs`
**Commit:** 7864b0a9
**Applied fix:** Replaced the invalid `api_token.scopes` example with the supported `api_token.custom_scopes` key and added assertions rejecting the obsolete key while requiring the valid one.

---

_Fixed: 2026-08-12T20:39:32Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 2_
