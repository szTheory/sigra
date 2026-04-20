---
phase: 19-passkey-schema-contexts
plan: 03
subsystem: auth
tags: [passkeys, authentication, sign_count, audit, webauthn, security]
provides:
  - Sigra.Passkeys.Authentication challenge and verification helpers with user-scoped credential lookup
  - Sigra.Passkeys.SignCountPolicy pure policy machine for warn, require_reauth, and revoke modes
  - Sigra.Passkeys.authenticate/4 with atomic success updates and regression audit handling
  - Authentication tests covering credential ownership checks and all sign-count policy branches
affects: [phase-19-wave-4, phase-20-passkey-runtime, phase-21-passkey-ui]
tech-stack:
  added: []
  patterns:
    - Authenticate preloads a credential by {user_id, credential_id} before calling Wax.authenticate/6
    - Sign-count regressions are handled as explicit policy branches with audit logging in the same Multi
    - Authentication updates use the host schema's update_changeset/2 when available and fall back to Ecto.Changeset.change/2
key-files:
  created:
    - lib/sigra/passkeys/authentication.ex
    - lib/sigra/passkeys/sign_count_policy.ex
    - test/sigra/passkeys/authentication_test.exs
    - test/sigra/passkeys/sign_count_policy_test.exs
  modified:
    - lib/sigra/passkeys.ex
key-decisions:
  - "Authentication refuses to cross the Wax boundary until a credential is found for the exact {user_id, credential_id} tuple."
  - "Warn mode preserves the stored sign_count while still auditing the regression instead of decreasing the counter."
  - "Require-reauth and revoke modes emit the same regression audit payload shape before returning an auth error."
patterns-established:
  - "Security-sensitive passkey branches get direct focused tests with fixture-backed assertions and Mox-verified Multi shapes."
  - "Regression-only side effects are isolated into audit-first Multi builders so policy modes stay easy to reason about."
requirements-completed: [PK-04, PK-05, PK-07, PK-08]
duration: 30min
completed: 2026-04-15
---

# Phase 19: passkey-schema-contexts Summary

**Passkey authentication, sign-count regression policy handling, and user-scoped StrongKey-style ownership checks for the Phase 19 auth path**

## Performance

- **Duration:** 30 min
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added the authentication ceremony wrapper that preloads credentials by `{user_id, credential_id}` before invoking `Wax.authenticate/6`.
- Implemented the sign-count policy machine and wired `authenticate/4` to warn, require reauth, or revoke with audit-backed branches.
- Verified the whole auth slice with fixture-backed assertion tests and a full passkey subset run.

## Task Commits

1. **Task 1: authentication primitive and policy machine** - not committed separately in this session
2. **Task 2: passkey auth branch coverage** - not committed separately in this session

## Files Created/Modified

- `lib/sigra/passkeys/authentication.ex` - Handles passkey auth challenge creation, scoped lookup, user_handle checks, and the Wax authentication call.
- `lib/sigra/passkeys/sign_count_policy.ex` - Implements the pure regression policy evaluator.
- `lib/sigra/passkeys.ex` - Adds `authenticate/4` and the persistence/audit branches for sign-count handling.
- `test/sigra/passkeys/authentication_test.exs` - Covers ownership enforcement and all authenticate policy modes.
- `test/sigra/passkeys/sign_count_policy_test.exs` - Locks the zero-zero carve-out and each regression policy result.

## Decisions & Deviations

The implementation followed the plan’s security invariants directly. The main design choice was to keep the sign-count policy machine pure and let `Sigra.Passkeys.authenticate/4` own the DB side effects, which keeps the audit/delete/update behavior explicit and testable.

## Next Phase Readiness

Wave 4 can now add rename/delete management helpers, install-feature wiring, and vault promotion on top of a complete passkey data and authentication layer.
