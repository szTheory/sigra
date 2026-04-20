---
phase: 33
slug: admin-shell-navigation-and-audit-preview-polish
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-17
---

# Phase 33 — Validation Strategy

## Test infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit — library drift tests + example `ConnCase` |
| **Quick run** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/installer_drift_test.exs test/example/test/example_web/admin_shell_test.exs --max-failures 1` |
| **Full slice** | Same as quick run plus any plans in `33-*-PLAN.md` that reference additional test paths |

## Per-task verification map

| Task | Requirement | Command / check | Status |
|------|-------------|-------------------|--------|
| Shell parity | USER-05 | `installer_drift_test.exs` contains `admin_shell users nav` marker | approved (retro) |
| Example parity | USER-05 | `admin_shell_test.exs` green | approved (retro) |

## Manual-only

| Behavior | Why manual |
|----------|------------|
| Mobile bottom-nav label order and tap targets | Visual / device judgment |

## Validation sign-off

- Retroactive approval: **Sigra maintainers**, 2026-04-17 — evidence in `33-*-SUMMARY.md` + example/generator tests above.
