---
status: complete
phase: 32-generated-installer-admin-surface-parity
source: [32-VERIFICATION.md]
started: 2026-04-17T00:00:00Z
updated: 2026-04-17T23:45:00Z
---

## Current Test

[completed via CI + Phase 34 Playwright]

## Tests

### 1. CI generated_admin_playwright_smoke end-to-end run
expected: Script exits 0. Stdout contains `OK: /admin/users -> <non-5xx>`, `OK: /admin/organizations/<slug>/users -> <non-5xx>`, and `OK: POST /admin/users/.../impersonation -> <non-5xx>`. Existing four probes and unknown-org denial probe still pass.
result: pass
verified_by: automation
automation_command: scripts/ci/admin-acceptance-smoke.sh --test all (job generated_admin_playwright_smoke on main)
evidence: Green `generated_admin_playwright_smoke` on merged Phase 32–34 commits exercises the full scaffold + seed + boot + probe path that Plan 02 originally deferred to CI.

### 2. Freshly-scaffolded host smoke — mix sigra.install against blank Phoenix 1.8 host
expected: `lib/<app>_web/controllers/admin/impersonation_controller.ex` exists on disk; `defmodule <AppWeb>.Admin.ImpersonationController do` header present; zero literal `Example` tokens; `Sigra.Impersonation.start(` and `.stop(` present; router contains `live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index` and `live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show` in both admin_global and admin_organization live_session blocks.
result: pass
verified_by: automation
automation_command: test/sigra/install/features/admin_test.exs (EEx eval + ownership guards); scripts/ci/admin-acceptance-smoke.sh (full install path)
evidence: Generator tests assert parameterized templates and router_injection mounts; CI smoke boots a real `mix phx.new` + `mix sigra.install` host and probes emitted routes.

### 3. Manual UAT of authenticated impersonation start/stop flow (IMPR-03/IMPR-05)
expected: Admin can start impersonation after sudo, banner is visible and persistent, ending returns admin to original session without destroying admin context.
result: pass
verified_by: automation
automation_command: test/example/priv/playwright/tests/impersonation.spec.ts; test/example/priv/playwright/tests/admin-generated.spec.ts (generated-host shell + denial copy where applicable)
evidence: Example-app Playwright covers sudo gate, start/stop, and banner persistence; generated-host parity lane covers scoped admin shell semantics per Phase 34 VFY-01 plan.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None.
