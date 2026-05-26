---
phase: 123-org-aware-enterprise-routing
plan: 03
subsystem: example-app
tags: [enterprise-sso, example-app, phoenix, routing, oauth, test]
requires: [123-01, 123-02]
provides:
  - example-app parity with the generated enterprise discovery and org-scoped SSO flow
  - route-backed controller and integration coverage for enterprise entry and callback behavior
affects: [example-login, example-router, example-enterprise-sso, example-tests]
tech-stack:
  added: []
  patterns: [generated-host parity, controller-first enterprise entry, mocked oauth exchange with real routing]
key-files:
  created:
    - test/example/lib/example_web/controllers/enterprise_sso_controller.ex
    - test/example/test/example_web/controllers/enterprise_sso_controller_test.exs
    - test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs
  modified:
    - priv/templates/sigra.install/organizations/controllers/enterprise_sso_controller.ex
    - test/example/lib/example/organizations.ex
    - test/example/lib/example_web/controllers/session_controller.ex
    - test/example/lib/example_web/controllers/session_html.ex
    - test/example/lib/example_web/router.ex
    - test/example/test/example_web/controllers/session_controller_test.exs
key-decisions:
  - "Added a configurable `:enterprise_oauth_module` seam so the example app can prove the controller contract without requiring a full external OIDC exchange in test."
  - "Used real enterprise-connection rows for email-domain discovery so route coverage exercises the same routing truth as the library code."
  - "Kept the example app aligned with the installer contract instead of introducing example-only enterprise paths or copy."
patterns-established:
  - "Example coverage mirrors the generated host: login discovery redirects into `/organizations/:org/sso`, then the org-scoped controller owns provider handoff and callback retry UX."
  - "Controller tests mock only the OAuth exchange boundary; enterprise routing and canonical route selection stay real and DB-backed."
requirements-completed: [SSO-03]
duration: 34 min
completed: 2026-05-25
---

# Phase 123 Plan 03 Summary

**The example Phoenix app now matches the generated-host enterprise contract: work-email discovery on the login page, anonymous `/organizations/:org/sso` entry and callback routes, and route-backed tests that lock the flow end to end.**

## Performance

- **Duration:** 34 min
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Added enterprise discovery delegates to `Example.Organizations` and wired the example session controller, login template, and router to the canonical org-scoped SSO entry flow.
- Created `ExampleWeb.EnterpriseSSOController` with configurable OAuth module injection plus per-organization OIDC config assembly from the stored enterprise connection.
- Added controller and integration tests covering login discovery, org entry rendering, provider redirect/session staging, callback success, and bounded callback retry behavior.

## Task Commits

1. **Task 1: Mirror generated enterprise discovery surface in the example app** - pending commit
2. **Task 2: Add example org-scoped enterprise controller with OAuth seam** - pending commit
3. **Task 3: Add route-backed example coverage for enterprise routing flow** - pending commit

## Files Created/Modified

- `test/example/lib/example/organizations.ex` - thin enterprise-routing delegates for discovery and canonical org lookup.
- `test/example/lib/example_web/controllers/session_controller.ex` and `test/example/lib/example_web/controllers/session_html.ex` - login-page enterprise discovery branch and bounded error handling.
- `test/example/lib/example_web/router.ex` - anonymous `/organizations/:org/sso` route family for entry, POST handoff, and callback.
- `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` - org-scoped enterprise entry and callback controller using the configurable OAuth seam.
- `test/example/test/example_web/controllers/session_controller_test.exs` - login-page enterprise discovery coverage.
- `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` and `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` - route-backed controller and integration coverage for entry and callback behavior.
- `priv/templates/sigra.install/organizations/controllers/enterprise_sso_controller.ex` - added the same OAuth seam used by the example app so generated hosts stay testable without contract drift.

## Decisions Made

- Introduced a test-only OAuth module seam rather than forcing the example app to carry a full identity-provider substrate just to verify controller routing and callback handoff.
- Reused real enterprise-connection records for discovery tests so the example flow validates the exact-match domain routing behavior instead of stubbing around it.

## Deviations from Plan

None - the example app was updated to mirror the generated contract and the planned test lanes were executed.

## Issues Encountered

- The example test suite excludes `@example_app` by default; verification needed explicit `--include example_app` flags to execute the new route-backed tests instead of silently filtering them out.

## Verification

- `cd test/example && mix test --include example_app test/example_web/controllers/session_controller_test.exs test/example_web/controllers/enterprise_sso_controller_test.exs` -> passed (`11 tests, 0 failures`).
- `cd test/example && mix test --include example_app test/example_web/integration/enterprise_sso_routing_flow_test.exs` -> passed (`1 test, 0 failures`).
- `rg -n "/organizations/:org/sso|EnterpriseSSOController|_action=enterprise|discover_enterprise_connection|get_routable_enterprise_connection|enterprise_login_form|routing_source" test/example/lib/example test/example/lib/example_web test/example/test/example_web` -> passed.

## User Setup Required

None - the example app remains self-contained and the OAuth boundary is mocked only inside tests.

## Next Phase Readiness

- Installer and golden verification can now lock the generated enterprise surface against a concrete example app implementation.
- The template and example controller now share the same configurable OAuth seam, reducing friction for the remaining installer-focused coverage work.

## Self-Check: PASSED
