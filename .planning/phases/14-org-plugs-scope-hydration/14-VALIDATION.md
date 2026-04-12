---
phase: 14
slug: org-plugs-scope-hydration
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-12
completed: 2026-04-12
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

*Populated by planner. Each task in a PLAN.md must map to a row here with an automated command or a Wave 0 test stub reference.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-XX-YY | XX | W | ORG-SCOPE-0N | T-14-XX / — | — | unit/integration | `mix test path/to/test.exs:NN` | ⬜ pending | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/plug/load_active_organization_test.exs` — stubs covering ORG-SCOPE-03 (hydration), ORG-SCOPE-04 (stale pointer reset)
- [ ] `test/sigra/plug/require_membership_test.exs` — stubs for ORG-SCOPE-05 (membership enforcement, role filter)
- [ ] `test/sigra/scope/hydrator_test.exs` — stubs for parity contract (LiveView ↔ Plug byte-identical scope)
- [ ] `test/sigra/auth_org_selection_test.exs` — stubs for ORG-SCOPE-06 (0/1/2+ org landing behavior, session resume)
- [ ] No new framework installs — ExUnit already configured

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Redirect UX (stale pointer → "no active org" landing; non-member → access-denied page) | ORG-SCOPE-04, ORG-SCOPE-05 | End-to-end browser check that redirect targets render correctly in generator-scaffolded host app | Run `mix sigra.install` in a fresh Phoenix app, log in as user with stale org id, confirm landing page renders without 500 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
