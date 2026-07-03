---
phase: 215
slug: terminal-ratification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-03
---

# Phase 215 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) — library + example; Playwright (example smoke) |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/` |
| **Quick run command** | `source tmp/db.env 2>/dev/null; mix test --stale` |
| **Full suite command** | `source tmp/db.env 2>/dev/null; mix test` (library) · `cd test/example && MIX_ENV=test mix test` (example) |
| **Estimated runtime** | ~library 60–120s · example ~30–60s (live Postgres required) |

---

## Sampling Rate

- **After every task commit:** Run the relevant `mix test <target>` (scoped to the file/lane the task verifies)
- **After every plan wave:** Run the full library + example suites
- **Before `/gsd-verify-work`:** Full library + example suites green with zero failures; required GitHub CI lanes green on the v1.43 PR
- **Max feedback latency:** ~120 seconds (full library suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 215-01-01 | 01 | 1 | HEALTH-01 | T-215-01 / — | N/A (verification) | suite | `source tmp/db.env 2>/dev/null; mix test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Populated fully by the planner per PLAN.md task breakdown.*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — this is a verification/ratification phase; the library + example suites and the CI lanes already exist. No new test framework or fixtures are installed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Required GitHub CI lanes green on the v1.43 PR | HEALTH-04 | GitHub Actions runs remotely — the 5 required contexts (Library tests, Example unit smoke, Install smoke, Example HTTP smoke, Example Playwright smoke) cannot be fully reproduced locally | Push the v1.43 PR; observe all 5 required checks pass green on the PR under ruleset 14941512 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
