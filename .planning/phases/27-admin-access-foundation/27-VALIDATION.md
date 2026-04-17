---
phase: 27
slug: admin-access-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for library and example-app tests; Phoenix.ConnTest and selective Phoenix.LiveViewTest in the example app |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/config/test.exs` |
| **Quick run command** | `mix test test/sigra/admin/authorizer_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` plus targeted example-app tests under `test/example` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run one task-local smoke command under 30 seconds, starting with `mix test test/sigra/admin/authorizer_test.exs --max-failures 1` for direct-path enforcement work
- **After every plan wave:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` plus targeted example-app tests under `test/example`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | ADMIN-01 | T-27-01 / T-27-04 | Admin installer feature is default-on, isolated to one feature owner, and omitted cleanly with `--no-admin` | unit | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 27-01-02 | 01 | 1 | ADMIN-01 / ADMIN-02 | T-27-02 / T-27-03 | Generated host boundary files include explicit admin policy and router shell seams without hidden inference | unit | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/purely_additive_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 27-02-01 | 02 | 1 | ADMIN-02 / ADMIN-04 | T-27-05 / T-27-07 | Policy contract and resolved admin scope fail closed for global and org-scoped access | unit | `mix test test/sigra/plug/require_admin_access_test.exs test/sigra/live_view/admin_scope_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 27-02-02 | 02 | 1 | ADMIN-03 / ADMIN-04 | T-27-06 / T-27-08 / T-27-09 | Plug and LiveView admin boundaries enforce the same resolved scope before any page render | unit | `mix test test/sigra/plug/require_admin_access_test.exs test/sigra/live_view/admin_scope_test.exs test/sigra/scope/plug_liveview_parity_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 27-02-03 | 02 | 1 | ADMIN-03 / ADMIN-04 | T-27-07 / T-27-08 | Direct-path exports, mutations, and query helpers use library-owned admin authorization and structural org scoping | unit | `mix test test/sigra/admin/authorizer_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 27-03-01 | 03 | 2 | ADMIN-03 / ADMIN-05 | T-27-10 / T-27-11 | Foundation admin LiveViews and example host wiring exist before integration tests run | smoke | `bash -lc 'rg -n "defmodule Sigra\\.Admin\\.Live\\.IndexLive|defmodule Sigra\\.Admin\\.Live\\.OrganizationLive" lib/sigra/admin/live/index_live.ex lib/sigra/admin/live/organization_live.ex && rg -n "defmodule Example\\.SigraAdminPolicy|platform_admin\\?|admin_org_ids" test/example/lib/example/sigra_admin_policy.ex && rg -n "/admin\"|/admin/organizations/:org|Sigra\\.Plug\\.RequireAdminAccess|Sigra\\.LiveView\\.AdminScope" test/example/lib/example_web/router.ex && rg -n "Admin|Global|scope" test/example/lib/example_web/components/admin_shell.ex'` | ❌ W0 | ⬜ pending |
| 27-03-02 | 03 | 2 | ADMIN-03 / ADMIN-04 / ADMIN-05 | T-27-12 / T-27-13 | Example-app integration and installer drift coverage prove global/org behavior and generated route alignment | integration | `bash -lc 'mix test test/sigra/templates/installer_drift_test.exs --max-failures 1 && cd test/example && mix test test/example_web/admin_shell_test.exs test/example_web/integration/phase_27_integration_test.exs --max-failures 1'` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/install/features/admin_test.exs` — installer feature contract and `--no-admin` coverage
- [ ] `test/sigra/plug/require_admin_access_test.exs` — route and pipeline enforcement parity with existing plug tests
- [ ] `test/sigra/live_view/admin_scope_test.exs` — LiveView on-mount enforcement and denial behavior
- [ ] `test/sigra/admin/authorizer_test.exs` — direct-path admin authorization and structural query-scoping coverage
- [ ] `test/example/test/example_web/admin_shell_test.exs` — generated host shell visibility coverage
- [ ] `test/example/test/example_web/integration/phase_27_integration_test.exs` — end-to-end admin entry and scope chrome flow

---

## Manual-Only Verifications

All phase behaviors should have automated verification. No manual-only checks are planned for Phase 27.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
