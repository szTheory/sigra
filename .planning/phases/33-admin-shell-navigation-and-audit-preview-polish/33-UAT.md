---
status: complete
phase: 33-admin-shell-navigation-and-audit-preview-polish
source:
  - 33-01-SUMMARY.md
  - 33-02-SUMMARY.md
started: "2026-04-17T18:30:00Z"
updated: "2026-04-17T19:15:00Z"
---

## Current Test

[testing complete — all checkpoints automated in example_app ExUnit]

## Tests

### 1. Global admin shell — live Users navigation
expected: Users is a live `/admin/users` link in top switcher, sidebar (Operations first, before Overview), and mobile bottom nav; Operations above Overview.
result: pass
verified_by: automation
automation:
  file: test/example/test/example_web/admin_shell_test.exs
  test: "renders Admin and Global for the global admin shell"
  asserts: href="/admin/users", sidebar_operations_before_overview?, bottom_nav_users_before_global?

### 2. Organization admin shell — Users link target
expected: Org-scoped admin chrome links Users to `/admin/organizations/{slug}/users`; Operations before Overview; bottom nav order.
result: pass
verified_by: automation
automation:
  file: test/example/test/example_web/admin_shell_test.exs
  test: "renders Admin and the organization name for an organization scope"
  asserts: href to org users path, sidebar_operations_before_overview?, bottom_nav_users_before_global?

### 3. User detail — Recent Audit preview matches explorer language
expected: Presenter `action_label` headings (not raw `session.*` as primary title); impersonation rows show badge + "Impersonation started"; no raw `admin.impersonation.start` as font-semibold heading.
result: pass
verified_by: automation
automation:
  file: test/example/test/example_web/live/admin_user_show_live_test.exs
  tests:
    - "recent audit preview stays aligned with effective_user rows and exposes a scoped full-audit path"
    - "organization-scoped detail page links into the same scoped full-audit surface"
    - "recent audit preview uses Presenter labels and impersonation badge when applicable"

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none — manual UAT replaced by `example_unit_smoke` job: `cd test/example && mix test --include example_app`]

## Agent notes

- Library drift + unit: `mix test test/sigra/templates/installer_drift_test.exs test/sigra/admin/users_actions_test.exs` (includes fix #18 + Presenter contract).
- Phase 33 human checklist is fully covered by **example_app** integration/LiveView tests above; CI already runs them in `.github/workflows/ci.yml` (`example_unit_smoke`).
