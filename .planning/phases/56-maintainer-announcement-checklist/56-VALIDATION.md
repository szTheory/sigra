---
phase: 56
slug: maintainer-announcement-checklist
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 56 — Validation Strategy

> Documentation phase: validation is **Mix + ExDoc + grep policy gates**, not a separate test harness.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (sanity only) + ExDoc |
| **Config file** | `mix.exs` (`docs/0` extras include `MAINTAINING.md`) |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `mix docs --warnings-as-errors` |
| **Estimated runtime** | ~60–120 seconds (project-dependent) |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors`
- **After every plan wave:** `mix docs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Doc build must be green; grep invariants from `56-01-PLAN.md` must pass

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 56-01-01 | 01 | 1 | MAINT-01 | T-56-01 / T-56-02 | No false GA certification; no HexDocs-broken `.planning/` relatives | doc build + grep | `mix docs --warnings-as-errors` + plan greps | ✅ | ⬜ pending |

---

## Wave 0 Requirements

Existing Mix / ExDoc infrastructure covers this phase — **no Wave 0 stubs**.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Roster UX | MAINT-01 | Tracking-issue template is org-specific | Release captain confirms Assignment block matches their GitHub label/process |

---

## Validation Sign-Off

- [ ] `mix docs --warnings-as-errors` green after `MAINTAINING.md` change
- [ ] No bare `](.planning/` links in `MAINTAINING.md`
- [ ] `nyquist_compliant: true` set in plan frontmatter when phase completes verification

**Approval:** pending
