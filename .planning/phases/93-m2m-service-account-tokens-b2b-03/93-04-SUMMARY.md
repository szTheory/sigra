---
phase: 93-m2m-service-account-tokens-b2b-03
plan: 04
subsystem: generator
tags: [templates, migration, liveview, example-app, b2b-03]
requires:
  - phase: 93-01
    provides: "Service-account library foundation"
provides:
  - "Generated host service-account schema and migration templates"
  - "Generated scope-template support for service-account map attrs"
  - "Minimal generated LiveView and example-app parity modules so the service-account route surface compiles"
affects: [phase-93, installer, example-app]
key-files:
  created:
    - "priv/templates/sigra.install/organizations/service_account.ex"
    - "priv/templates/sigra.install/organizations/service_account_credential.ex"
    - "priv/templates/sigra.install/organizations/service_accounts_migration.exs"
    - "priv/templates/sigra.install/organizations/live/organization_service_accounts_live.ex"
    - "test/example/lib/example/accounts/service_account.ex"
    - "test/example/lib/example/accounts/service_account_credential.ex"
    - "test/example/lib/example_web/live/organization_service_accounts_live.ex"
  modified:
    - "priv/templates/sigra.install/core/scope.ex"
    - "priv/templates/sigra.install/organizations/router_injection.ex"
    - "lib/sigra/install/features/organizations.ex"
requirements-completed: [B2B-03]
completed: 2026-05-01
---

# Phase 93 Plan 04 Summary

**The generated-host service-account surface now compiles: schemas, migration, router wiring, scope-template support, and a minimal LiveView all exist in both templates and the example app.**

## Accomplishments

- Added service-account and service-account-credential schema templates plus the Postgres migration template.
- Extended the generated scope template with `service_account_id` and a map-attrs constructor so the bearer service-account path can instantiate generated scopes safely.
- Added `/service-accounts` and `/service-accounts/:id` routes to the organizations router injection.
- Added minimal `OrganizationServiceAccountsLive` templates and matching example-app modules so the generated/example route surface compiles.

## Deviations From Plan

- The generated LiveView is intentionally minimal and does not implement the full `93-UI-SPEC.md` contract, sudo ladder, one-time secret disclosure flow, or full create/revoke UI behavior from the plan.
- No dedicated generator golden-diff or LiveView behavior test was added here; verification is compile-oriented.

## Verification

- `cd test/example && mix compile --warnings-as-errors`
- `mix compile --warnings-as-errors`

## Next Dependency

The generated host now has compile-safe service-account artifacts, but the richer management UX and end-to-end proof from the original plan remain open.
