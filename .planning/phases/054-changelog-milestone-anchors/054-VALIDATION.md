---
phase: 54
slug: changelog-milestone-anchors
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / ExUnit (existing repo); primary checks are **grep** on markdown |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Quick compile ~10–30s; full suite minutes (Postgres) |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors` + plan grep contracts
- **After every plan wave:** Quick compile; full test suite optional if only `CHANGELOG.md` changed (CI still green)
- **Before `/gsd-verify-work`:** All grep contracts in plans pass

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | PUB-02 | T-54-01 | Honest version-axis wording | grep | `grep -F 'Planning milestones vs Hex releases' CHANGELOG.md` | ✅ | ⬜ pending |
| 54-01-02 | 01 | 1 | PUB-02 | T-54-02 | Traceability blocks present | grep | `test "$(grep -c '### Roadmap traceability' CHANGELOG.md)" -ge 3` exits 0 | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- **Existing infrastructure covers all phase requirements.** No new ExUnit files; grep + optional full compile.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Traceability prose matches `MILESTONES.md` dates and archive paths | PUB-02 (2) | Subjective alignment | Open `CHANGELOG.md` traceability blocks side-by-side with `.planning/MILESTONES.md` for v1.2–v1.4; confirm dates and relative links match |

---

## Validation Sign-Off

- [ ] All tasks have grep or compile verify
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when execution completes

**Approval:** pending
