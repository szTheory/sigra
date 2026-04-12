---
phase: 13
slug: organizations-schemas-context
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/organizations` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/organizations`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | ORG-01 | T-13-01 / O-1 | `for_org/2` raises on missing `:organization_id` | unit | `mix test test/sigra/organizations/query_test.exs` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | ORG-04 | T-13-02 / O-4 | Last-owner guard blocks removal/demotion | integration | `mix test test/sigra/organizations_test.exs` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | ORG-05 | T-13-03 / O-9 | Reserved slug rejected by changeset | unit | `mix test test/sigra/organizations/organization_test.exs` | ❌ W0 | ⬜ pending |
| 13-01-04 | 01 | 1 | ORG-06 | T-13-04 / O-10 | Soft-delete preserves audit rows via nilify_all | integration | `mix test test/sigra/organizations_test.exs` | ❌ W0 | ⬜ pending |
| 13-01-05 | 01 | 1 | ORG-07 | — | `prepare_query/3` raises on unscoped query | integration | `mix test test/sigra/organizations/query_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/organizations/query_test.exs` — stubs for ORG-01, ORG-07
- [ ] `test/sigra/organizations_test.exs` — stubs for ORG-03, ORG-04, ORG-05, ORG-06, ORG-08
- [ ] `test/sigra/organizations/organization_test.exs` — schema changeset tests
- [ ] `test/support/fixtures/organization_fixtures.ex` — shared test helpers

*Existing ExUnit infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Migration adapter branching | ORG-01 | Requires MySQL/SQLite database to verify non-PG paths | Run `mix sigra.install` with each adapter configured |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
