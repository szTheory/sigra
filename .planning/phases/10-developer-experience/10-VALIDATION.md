---
phase: 10
slug: developer-experience
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs`, `test/support/*.ex`, `mix.exs` (`:test` env) |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test && mix test --only doctest` |
| **Estimated runtime** | ~30 seconds (library suite); +60s (example-app smoke job) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix test` + `mix credo --strict` + `mix format --check-formatted`
- **Before `/gsd-verify-work`:** Full suite must be green AND example-app smoke job must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

> Task IDs will be filled in by the planner. This table is a scaffold — each PLAN.md task must map to a row here via the planner/checker loop.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | DX-01 | — | REQUIREMENTS.md DX-01 text matches shipped signatures | doc | `rg 'create_api_token/3' .planning/REQUIREMENTS.md` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | DX-03 | — | Seven scenario fixtures importable and return documented shapes | unit | `mix test test/sigra/auth_fixtures_scenario_test.exs` | ❌ W0 | ⬜ pending |
| 10-03-01 | 03 | 1 | DX-04 | T-10-01 | `cookie_domain` config propagates to all remember-me/MFA trust cookies at runtime | integration | `mix test test/sigra/cookie_domain_test.exs` | ❌ W0 | ⬜ pending |
| 10-03-02 | 03 | 1 | DX-04 | T-10-02 | Boot warns when `cookie_domain` unset in `:prod` env | unit | `mix test test/sigra/application_cookie_warning_test.exs` | ❌ W0 | ⬜ pending |
| 10-04-01 | 04 | 2 | DX-02 | — | ex_doc builds without warnings; guides appear in grouped sidebar | doc | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 10-05-01 | 05 | 2 | DX-02 | — | Getting-started guide end-to-end verified against example app | manual+smoke | `cd test/example && mix test test/example_web/getting_started_flow_test.exs` | ❌ W0 | ⬜ pending |
| 10-06-01 | 06 | 3 | DX-02 | — | Example app installs, compiles, and passes all six smoke flows | integration | `.github/workflows/ci.yml` job `example-app-smoke` | ❌ W0 | ⬜ pending |
| 10-07-01 | 07 | 1 | AUDIT-09* | T-09-08 | `audit_event_fixture/1` + `assert_audit_event/2` inspectable in ExUnit | unit | `mix test test/sigra/testing_audit_test.exs` | ❌ W0 | ⬜ pending |
| 10-08-01 | 08 | 1 | DX-01 | — | `Sigra.Testing` section headers present and function grouping intact | doc | `rg '^\s*# --- .* ---$' lib/sigra/testing.ex` | ❌ W0 | ⬜ pending |

*AUDIT-09 = Phase 9 carryover (D-18 in 10-CONTEXT.md).*
*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/auth_fixtures_scenario_test.exs` — stubs for DX-03 (seven scenarios + dispatcher)
- [ ] `test/sigra/cookie_domain_test.exs` — stubs for DX-04 (runtime resolution across 3 call sites)
- [ ] `test/sigra/application_cookie_warning_test.exs` — boot-warning assertion
- [ ] `test/sigra/testing_audit_test.exs` — stubs for D-18 audit helpers
- [ ] `test/example/` — minimal Phoenix app scaffold committed
- [ ] `.github/workflows/ci.yml` — `example-app-smoke` job stub
- [ ] `mix.exs` — `:docs` config with `:extras` + `:groups_for_extras` (stubbed so `mix docs` runs)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Getting-started is readable end-to-end in under 30 minutes on a fresh Phoenix app | DX-02 | Subjective / time-based; cannot be automated meaningfully | Jon (or reviewer) follows `guides/introduction/getting-started.md` from a clean `mix phx.new`, starts a timer, stops at first successful password-reset email. Must complete in <30 min. |
| Sidebar grouping renders correctly in HexDocs | DX-02 | Visual rendering — automated build only asserts compilation | Run `mix docs`; open `doc/index.html`; confirm Introduction/Flows/Recipes/Upgrading groups appear with correct ordering. |
| Prod `cookie_domain` warning is visible in logs | DX-04 | Requires booting with MIX_ENV=prod; automated test covers the Logger call site but not human visibility | Start the example app with `MIX_ENV=prod` and no `COOKIE_DOMAIN` env var; confirm warning appears at startup. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
