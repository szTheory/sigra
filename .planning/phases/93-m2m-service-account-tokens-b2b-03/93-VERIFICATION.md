---
phase: 93
slug: m2m-service-account-tokens-b2b-03
status: partial
created: 2026-05-01
updated: 2026-05-01
requirement: B2B-03
---

# Phase 93 Verification

## Verdict

`B2B-03` is substantially implemented in the working tree, but Phase 93 does **not** meet its full original five-plan closeout contract yet. The requirement-level capability exists; the stricter phase-level proof and UI contract do not.

## Requirement Outcome

The core B2B-03 requirement is satisfied locally:

- Sigra can mint org-scoped service-account JWTs via `client_credentials`.
- The bearer path distinguishes service-account callers with `scope.actor_type == :service_account` and `scope.service_account_id`.
- Service-account requests short-circuit user-membership and member-MFA enforcement.
- Generated-host templates and example-app modules now compile with the new service-account surface.
- Adopter-facing recipe and upgrade migration artifacts exist.

## Evidence

### Commands Run

```bash
mix compile --warnings-as-errors
mix test test/sigra/service_accounts_test.exs test/sigra/oauth/token_test.exs test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs
mix docs --warnings-as-errors
cd test/example && mix compile --warnings-as-errors
```

### Observed Passes

- Root compile passes with warnings treated as errors.
- Focused Phase 93 library and plug coverage passes.
- Docs build passes with warnings treated as errors.
- The example app compiles with the new service-account modules, controller, routes, and LiveView present.

## Open Gaps

The following planned Phase 93 gates are still missing:

1. `test/sigra/service_accounts_audit_atomicity_test.exs`
2. Expanded `test/sigra/jwt_test.exs` and `test/sigra/plug/fetch_bearer_test.exs` parity coverage for the service-account bearer path
3. `test/sigra/install/golden_diff_test.exs` gating assertions for service-account artifact emission
4. Full `93-UI-SPEC.md` LiveView implementation, including sudo-gated destructive actions and one-time secret disclosure behavior
5. `test/example/test/example_web/integration/service_account_e2e_test.exs`

## Merge-Gate Outcome

- Requirement-level local proof: PASS
- Full phase closeout per original plan: NOT YET PASSING
- Human-only verification required: no, but additional automated coverage is still required before Phase 93 should be considered fully closed

## Next Action

Finish the remaining Phase 93 proof surfaces before advancing planning truth to a clean "complete" state:

- add the missing atomicity and parity tests
- either implement the full generated LiveView contract or explicitly down-scope the plan/UI artifact
- add the generated-host E2E lifecycle test
