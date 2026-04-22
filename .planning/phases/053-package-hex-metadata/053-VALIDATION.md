---
phase: 53
slug: package-hex-metadata
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / ExUnit (existing repo) |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Quick ~10–30s; full suite minutes (Postgres) |

---

## Sampling Rate

- **After every task commit:** Run `mix compile --warnings-as-errors`
- **After every plan wave:** Run quick compile; run full suite before merge if `mix.exs` deps were touched (this phase should not touch deps)
- **Before `/gsd-verify-work`:** Quick compile green; maintainer manual read for PUB-01(3)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01 | 1 | PUB-01 | T-53-01 | Honest capability claims | compile | `mix compile --warnings-as-errors` | ✅ | ⬜ pending |
| 53-01-02 | 01 | 1 | PUB-01 | T-53-02 | No forbidden URLs | grep | `! grep -E '\.planning/|planning/' mix.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- **Existing infrastructure covers all phase requirements.** No new test files required for Nyquist on this metadata-only phase; grep + compile suffice.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Maintainer agrees Hex blurb is announcement-safe | PUB-01 (3) | Subjective tone / legal comfort | Read `mix.exs` `description` aloud; confirm no optional feature implied as default; sign off in PR or `MAINTAINING.md` follow-up |

---

## Validation Sign-Off

- [ ] All tasks have compile or grep verify
- [ ] Sampling continuity: compile after each edit
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when execution completes

**Approval:** pending
