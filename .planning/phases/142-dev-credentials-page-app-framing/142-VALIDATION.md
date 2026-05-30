---
phase: 142
slug: dev-credentials-page-app-framing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-30
---

# Phase 142 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/example/test/test_helper.exs` |
| **Quick run command** | `cd test/example && mix test test/example_web/live/demo/credentials_live_test.exs` |
| **Full suite command** | `cd test/example && mix test` |
| **Estimated runtime** | ~quick file <5s; full example suite per existing baseline |

---

## Sampling Rate

- **After every task commit:** Run `cd test/example && mix test test/example_web/live/demo/credentials_live_test.exs`
- **After every plan wave:** Run `cd test/example && mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds (scoped test file)

---

## Per-Task Verification Map

> Planner fills real task IDs. Behaviors below are the locked Req→behavior coverage
> targets from RESEARCH.md "Validation Architecture" (DEMO-01, DEMO-02).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| {plan}-{task} | {p} | {w} | DEMO-01 | T-142-01 | `/demo/credentials` route is compiled OUT under `MIX_ENV=test` (404 / route-absent) — dev-only exposure cannot leak into a non-dev build | conn | `cd test/example && mix test test/example_web/live/demo/credentials_live_test.exs` | ❌ W0 | ⬜ pending |
| {plan}-{task} | {p} | {w} | DEMO-01 | — | Rendered HTML carries `data-testid="demo-credentials-table"`, per-row `demo-persona-row-{local}`, and `demo-dev-only-badge` | structural (render-direct, NOT `live/2` — route compiled out) | same file | ❌ W0 | ⬜ pending |
| {plan}-{task} | {p} | {w} | DEMO-02 | — | Layout carries `data-testid="app-name"` and browser `<title>` contains "Vaultr" | structural / conn | same file | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/test/example_web/live/demo/credentials_live_test.exs` — stubs for DEMO-01 (404 env guard) + DEMO-02 (content/testid assertions)
- [ ] `test/example/test/example_web/live/demo/` directory (new)

*Existing infrastructure — `ExampleWeb.ConnCase`, `Phoenix.ConnTest`, `Phoenix.LiveViewTest` — already present. No new framework installation needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual SaaS framing ("Vaultr" feels like a real product, not a fixture) | DEMO-02 | Subjective visual judgment beyond testid presence; full visual coverage is Phase 143 (Playwright) | `cd test/example && mix phx.server`, open `/demo/credentials` and the app shell in a dev build |

*Note: rendered-content coverage in-suite uses direct `render/1` (route compiled out under test); cross-page Playwright coverage is deferred to Phase 143.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
