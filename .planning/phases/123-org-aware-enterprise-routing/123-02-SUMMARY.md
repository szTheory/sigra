---
phase: 123-org-aware-enterprise-routing
plan: 02
subsystem: generated-host
tags: [enterprise-sso, generated-host, installer, phoenix, routing, ui]
requires: [123-01]
provides:
  - template-owned enterprise discovery branch on the login page
  - canonical org-scoped enterprise controller and route injection
  - thin generated-host delegates into Sigra enterprise routing APIs
affects: [installer-output, generated-host-login, organization-scoped-entry]
tech-stack:
  added: []
  patterns: [controller-first enterprise entry, redirect-before-oidc discovery, same-mode enterprise retry]
key-files:
  created:
    - priv/templates/sigra.install/organizations/controllers/enterprise_sso_controller.ex
  modified:
    - lib/sigra/install/features/organizations.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - priv/templates/sigra.install/core/login_html.ex
    - priv/templates/sigra.install/organizations/organizations.ex
    - priv/templates/sigra.install/organizations/router_injection.ex
key-decisions:
  - "Kept enterprise discovery on the existing login page but made it redirect into the canonical org route before OIDC starts."
  - "Placed `/organizations/:org/sso` outside authenticated pipelines so enterprise login remains a real entry path instead of an authenticated-only tenant page."
  - "Used a controller-first enterprise handoff page with lightweight org truth rather than inventing a second LiveView-only auth surface."
patterns-established:
  - "Generated hosts call `Sigra.EnterpriseRouting` through thin `Organizations` delegates instead of duplicating org or connection eligibility logic."
  - "Enterprise callback failures stay inside the org-scoped enterprise flow with bounded flash copy and no silent downgrade."
requirements-completed: [SSO-03]
duration: 40 min
completed: 2026-05-25
---

# Phase 123 Plan 02 Summary

**The generated-host templates now expose the canonical enterprise entry surface: a separate enterprise discovery branch on the login page, anonymous `/organizations/:org/sso` controller routes, and thin host delegates into the library-owned routing and OAuth contracts.**

## Performance

- **Duration:** 40 min
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Registered a new generated `EnterpriseSSOController` template and added thin `discover_enterprise_connection/1` and `get_routable_enterprise_connection/1` delegates to the host `Organizations` wrapper.
- Extended the generated session controller and login HTML template with a bounded enterprise discovery branch that redirects into the canonical org route before OIDC starts.
- Added anonymous `/organizations/:org/sso` and callback route injection plus a controller-first enterprise handoff page that preserves same-mode retry behavior.

## Task Commits

1. **Task 1: Add template-owned canonical org entry and bounded discovery delegates** - `2d4a5bd` (feat)
2. **Task 2: Add template-owned enterprise controller and org-scoped routes** - `2d4a5bd` (feat)

## Files Created/Modified

- `priv/templates/sigra.install/organizations/controllers/enterprise_sso_controller.ex` - canonical org-scoped enterprise entry and callback controller.
- `priv/templates/sigra.install/core/session_controller.ex` and `priv/templates/sigra.install/core/login_html.ex` - generated login-page enterprise discovery branch and bounded failure copy.
- `priv/templates/sigra.install/organizations/organizations.ex` - thin host delegates into `Sigra.EnterpriseRouting`.
- `priv/templates/sigra.install/organizations/router_injection.ex` - canonical `/organizations/:org/sso` route family outside authenticated pipelines.
- `lib/sigra/install/features/organizations.ex` - template registration for the new controller file.

## Decisions Made

- Kept the enterprise entry controller anonymous so the org route can be the actual login entry point rather than an authenticated-only settings path.
- Redirected successful enterprise callbacks to an org-scoped authenticated page so the first post-login request exercises the active-organization session truth immediately.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first router draft incorrectly placed enterprise entry behind `:require_authenticated`; that was corrected before verification so the route remains a valid anonymous login entry path.

## Verification

- `mix test test/sigra/install/features/organizations_test.exs` -> passed (`65 tests, 0 failures`).
- `rg -n "/organizations/:org/sso|EnterpriseSSOController|_action=enterprise|discover_enterprise_connection|handle_callback" priv/templates/sigra.install lib/sigra/install/features/organizations.ex` -> passed.

## User Setup Required

None - the generated host receives these routes and templates through the installer.

## Next Phase Readiness

- The committed example app can now mirror the generated login branch, enterprise controller, and scoped callback behavior one-for-one.
- Installer and golden coverage can lock the template contract once the committed example app is updated.

## Self-Check: PASSED
