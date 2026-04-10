---
phase: 10
slug: developer-experience
status: draft
nyquist_compliant: true
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
| 10-01-01 | 01 | 1 | DX-01 | T-10-08 | REQUIREMENTS.md DX-01 text matches shipped signatures | doc | `rg -n 'create_api_token/3' .planning/REQUIREMENTS.md` | ✅ existing | ⬜ pending |
| 10-01-02 | 01 | 1 | DX-01/AUDIT-09* | T-10-06,07 | Sigra.Testing has 9 section headers + audit_event_fixture/1 + assert_audit_event/2 | unit | `mix test test/sigra/testing_audit_test.exs` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | DX-03 | T-10-05,09,10 | Seven scenario fixtures + scenario/2 dispatcher in AuthFixtures template | unit | `mix test test/sigra/auth_fixtures_scenario_test.exs` | ❌ W0 | ⬜ pending |
| 10-03-01 | 03 | 1 | DX-04 | T-10-01,12,13 | :cookie_domain config validates; threads into MFA.Trust.cookie_opts/1; FetchSession grep-confirmed read-only (Open Q2 path b) | unit | `mix test test/sigra/cookie_domain_test.exs` | ❌ W0 | ⬜ pending |
| 10-03-02 | 03 | 1 | DX-04 | T-10-02,11 | UserAuth runtime remember_me_options + mfa_challenge_controller + boot warning | unit | `mix test test/sigra/application_cookie_warning_test.exs` | ❌ W0 | ⬜ pending |
| 10-04-01 | 04 | 2 | DX-02 | T-10-15 | ex_doc builds without warnings; 15 guides in grouped sidebar; subdomain-auth full content | doc/build | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 10-04-02 | 04 | 2 | DX-02 | T-10-15 | mix.exs :extras + :groups_for_extras + mix docs builds clean | build | mix docs --warnings-as-errors | ❌ W0 | ⬜ pending |
| 10-05-01 | 05 | 3 | DX-02 | T-10-04,16 | 14 guide files filled with content; no banned vocabulary; mix docs clean | doc/build | `mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 10-05-02 | 05 | 3 | DX-02 | T-10-17 | Doctests on Sigra.Config / Sigra.Auth / Sigra.Testing pure helpers | unit | `mix test test/sigra/doctest_test.exs` | ❌ W0 | ⬜ pending |
| 10-05-03 | 05 | 3 | DX-02 | — | Human verification of <30 min getting-started readthrough | manual | (checkpoint:human-verify) | n/a | ⬜ pending |
| 10-06-01 | 06 | 4 | DX-02/03 | T-10-03,18 | test/example/ Phoenix app committed and compiles | build | `cd test/example && mix compile --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 10-06-02 | 06 | 4 | DX-02/03 | T-10-19,20 | Six D-17 smoke tests + fixtures test + getting-started flow test green | integration | `cd test/example && mix test --include example_app` | ❌ W0 | ⬜ pending |
| 10-06-03 | 06 | 4 | DX-02 | T-10-21 | example_app_smoke GHA job added with working-directory isolation | ci | `rg -n 'example_app_smoke' .github/workflows/ci.yml` | ❌ W0 | ⬜ pending |
| 10-06-04 | 06 | 4 | DX-04 | T-10-02 | Manual confirmation prod boot warning visible when COOKIE_DOMAIN unset | manual | (checkpoint:human-verify) | n/a | ⬜ pending |

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
