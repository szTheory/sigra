---
phase: 93-m2m-service-account-tokens-b2b-03
plan: 05
subsystem: docs
tags: [recipes, upgrade, changelog, b2b-03]
requires:
  - phase: 93-02
    provides: "Service-account auth-pipeline behavior"
  - phase: 93-03
    provides: "OAuth client-credentials surface"
  - phase: 93-04
    provides: "Generated-host service-account artifacts"
provides:
  - "Published adopter-facing service-account recipe"
  - "RBAC recipe extension covering `scope.actor_type == :service_account`"
  - "Upgrade migration template for service-account tables"
affects: [phase-93, docs, upgrade]
key-files:
  created:
    - "guides/recipes/m2m-service-accounts.md"
    - "priv/templates/sigra.upgrade/alter_add_service_accounts.exs"
  modified:
    - "guides/recipes/role-based-access-control.md"
requirements-completed: [B2B-03]
completed: 2026-05-01
---

# Phase 93 Plan 05 Summary

**Adopter-facing documentation and upgrade scaffolding are now in place, but the full generated-host end-to-end proof from the original plan was not completed.**

## Accomplishments

- Added `guides/recipes/m2m-service-accounts.md` documenting the service-account flow, token exchange, authorization branching, and rotation model.
- Extended `guides/recipes/role-based-access-control.md` with a service-account authorization section using `scope.actor_type`.
- Added `priv/templates/sigra.upgrade/alter_add_service_accounts.exs` as the v1.20 → v1.21 upgrade migration template.

## Deviations From Plan

- `test/example/test/example_web/integration/service_account_e2e_test.exs` was not added.
- This pass does not provide the original plan's full create → mint → call → revoke → 401 generated-host proof or the associated audit-row assertions.
- `CHANGELOG.md` was already locally modified before this reconciliation; this summary does not claim a clean, isolated B2B-03 changelog closeout.

## Verification

- `mix docs --warnings-as-errors`

## Next Dependency

Phase 93 documentation is now discoverable, but the missing end-to-end proof remains the main closeout blocker for a strict Phase 93 completion claim.
