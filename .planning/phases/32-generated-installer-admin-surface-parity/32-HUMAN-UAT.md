---
status: partial
phase: 32-generated-installer-admin-surface-parity
source: [32-VERIFICATION.md]
started: 2026-04-17T00:00:00Z
updated: 2026-04-17T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. CI generated_admin_playwright_smoke end-to-end run
expected: Script exits 0. Stdout contains `OK: /admin/users -> <non-5xx>`, `OK: /admin/organizations/<slug>/users -> <non-5xx>`, and `OK: POST /admin/users/.../impersonation -> <non-5xx>`. Existing four probes and unknown-org denial probe still pass.
result: [pending]

### 2. Freshly-scaffolded host smoke — mix sigra.install against blank Phoenix 1.8 host
expected: `lib/<app>_web/controllers/admin/impersonation_controller.ex` exists on disk; `defmodule <AppWeb>.Admin.ImpersonationController do` header present; zero literal `Example` tokens; `Sigra.Impersonation.start(` and `.stop(` present; router contains `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` and `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in both admin_global and admin_organization live_session blocks.
result: [pending]

### 3. Manual UAT of authenticated impersonation start/stop flow (IMPR-03/IMPR-05)
expected: Admin can start impersonation after sudo, banner is visible and persistent, ending returns admin to original session without destroying admin context.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
