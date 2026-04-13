---
phase: 16
slug: org-liveviews-switcher
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Phoenix.LiveViewTest, Phoenix.ConnTest) |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~TBD seconds (planner to measure) |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _Planner fills in during PLAN.md creation_ | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] _Planner fills in based on 16-RESEARCH.md §10 Validation Architecture_

*Planner MUST populate this section before execution begins — reference the file paths listed in `16-RESEARCH.md` §10.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _TBD by planner_ | | | |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
