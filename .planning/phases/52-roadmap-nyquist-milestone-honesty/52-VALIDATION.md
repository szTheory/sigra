---
phase: 52
slug: roadmap-nyquist-milestone-honesty
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-21
---

# Phase 52 — Validation Strategy

> Process-only phase: **ROADMAP** reader honesty, **audit YAML** disposition for stale `tech_debt`, and a **doc contract** test so the story does not regress.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`MIX_ENV=test`) |
| **Config file** | none (reads `.planning/*.md` via `Path.expand`) |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` |
| **Full suite command** | `MIX_ENV=test mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` |
| **Estimated runtime** | \< 5 seconds |

---

## Sampling Rate

- **After Plan 01 commits (ROADMAP):** Quick run command on touched branch.
- **After Plan 02 commits (audit + new test):** Full suite command (includes **50** regression guard).
- **Before `/gsd-verify-work`:** Full suite command green.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 52-01-01 | 01 | 1 | ROADMAP honesty (1) | T-52-01 | Accurate “done” signals | grep + ExUnit | `MIX_ENV=test mix test test/sigra/planning/phase_52_milestone_honesty_contract_test.exs` | ✅ after 02 | ⬜ pending |
| 52-02-01 | 02 | 1 | Audit disposition (3) | T-52-02 | Stale debt flagged | ExUnit | same file | ✅ after 02 | ⬜ pending |
| 52-02-02 | 02 | 1 | 50 artifact alignment (2) | — | N/A | grep | `grep -q "phase 52\\|Phase 52" .planning/phases/50-nyquist-ci-gate-hygiene/50-VERIFICATION.md` | ✅ after 02 | ⬜ pending |

---

## Wave 0 Requirements

Existing ExUnit + planning tree cover infrastructure. Plan 02 adds **`test/sigra/planning/phase_52_milestone_honesty_contract_test.exs`**.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ROADMAP tone | (1) | Maintainer judgment | Read **§ Reader note: phases 44–45 vs 47–49** (or equivalent title) for clarity. |

---

## Validation Sign-Off

- [ ] Contract test file exists and passes with **`nyquist_compliant: false`** unless team elevates posture
- [ ] No watch-mode flags in commands
- [ ] **50** contract tests still pass in same run

**Approval:** pending
