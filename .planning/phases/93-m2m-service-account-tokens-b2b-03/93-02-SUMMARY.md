---
phase: 93-m2m-service-account-tokens-b2b-03
plan: 02
subsystem: auth-pipeline
tags: [jwt, fetch-bearer, require-membership, require-org-mfa, b2b-03]
requires:
  - phase: 93-01
    provides: "Service-account context plus config/scope plumbing"
provides:
  - "Service-account requests short-circuit `RequireMembership` and `RequireOrgMfa`"
  - "Existing JWT / FetchBearer service-account path is preserved as the single bearer-entry seam"
affects: [phase-93, plug-pipeline, jwt]
key-files:
  modified:
    - "lib/sigra/plug/require_membership.ex"
    - "lib/sigra/plug/require_org_mfa.ex"
    - "test/sigra/plug/require_membership_test.exs"
    - "test/sigra/plug/require_org_mfa_test.exs"
requirements-completed: [B2B-03]
completed: 2026-05-01
---

# Phase 93 Plan 02 Summary

**The existing bearer flow remains the only auth entry point, and service-account requests now bypass user-membership and org-MFA guards correctly.**

## Accomplishments

- Added service-account short-circuit clauses to `lib/sigra/plug/require_membership.ex` and `lib/sigra/plug/require_org_mfa.ex`.
- Added focused plug coverage proving service-account scopes pass through those guards without user-membership or MFA-enrollment assumptions.
- Preserved the existing JWT and `Sigra.Plug.FetchBearer` service-account fork already present in the library.

## Deviations From Plan

- The broader `test/sigra/jwt_test.exs` and `test/sigra/plug/fetch_bearer_test.exs` expansions called for in the plan were not added in this pass.
- Validation here is therefore narrower than the original plan: downstream plug behavior is covered, but the explicit JWT/FetchBearer parity suite is still missing.

## Verification

- `mix test test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs`

## Next Dependency

The plug pipeline is now compatible with service-account scopes, which unblocks the `/oauth/token` surface and generated-host flow.
