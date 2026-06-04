---
phase: 157
slug: overview-landings-highest-effort
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 157 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) + Playwright (admin checkpoints) |
| **Config file** | `test/test_helper.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/example/lib/example_web/live/admin_shell_test.exs` |
| **Full suite command** | `mix test` (needs live Postgres at localhost:5432 postgres/postgres) |
| **Estimated runtime** | ~60 seconds (ExUnit); Playwright checkpoints separate (admin-checkpoints job) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command for the touched layer
- **After every plan wave:** Run `mix test` (full ExUnit suite)
- **Before `/gsd:verify-work`:** Full ExUnit suite green + Playwright `admin-checkpoints` + `admin-generated` lanes green
- **Max feedback latency:** ~60 seconds (ExUnit)

---

## Per-Task Verification Map

> Populated by gsd-planner from the RESEARCH.md "## Validation Architecture" section.
> Each LAND-0x requirement maps to an observable proof at the correct test layer.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | LAND-01 | — | needs-review alarm renders loud (risk tone) above task grid; all-clear when 0 | LiveView | `mix test test/example/lib/example_web/live/admin_shell_test.exs` | ✅ | ⬜ pending |
| TBD | TBD | TBD | LAND-02 | — | task_card grid is primary content; posture/capability demoted | LiveView | `mix test test/example/lib/example_web/live/admin_shell_test.exs` | ✅ | ⬜ pending |
| TBD | TBD | TBD | LAND-03 | — | both Overviews share identical front-door archetype rhythm | LiveView | `mix test test/example/lib/example_web/live/admin_shell_test.exs` | ✅ | ⬜ pending |
| TBD | TBD | TBD | LAND-04 | — | GET mount renders skeleton; `live/2` connected mount renders data (two-state proof) | LiveView | `mix test test/example/lib/example_web/live/admin_shell_test.exs` | ✅ | ⬜ pending |
| TBD | TBD | TBD | LAND-05/D-06 | — | `global-overview`+`org-overview` checkpoints axe-green ×3; wait-for-loaded-data; existing 5 slugs not re-recorded; `admin-generated` green | Playwright | admin-checkpoints + admin-generated lanes | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/lib/example_web/live/admin_shell_test.exs` — add `describe "Phase 157 Overview redesign"` covering both skeleton (GET) and data (`live/2`) states for Global + Org. (No `live/2` connected-mount tests exist for either Overview screen today — RESEARCH finding #1.)

*Existing ExUnit + Playwright infrastructure covers all other phase requirements — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | — | — |

*All phase behaviors have automated verification (LiveView two-mount tests for LAND-01..04; Playwright checkpoint + axe for LAND-05/D-06). Aligns with the zero-human-UAT preference.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
