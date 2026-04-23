---
phase: 59
slug: uat-ga-narrative-alignment
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 59 — Validation Strategy

> Per-phase validation contract for **documentation / narrative** execution (**OA-02**). No new runtime code.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / ExUnit (existing repo — Phase 59 does not add tests) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix compile --warnings-as-errors` |
| **Full suite command** | Same + optional `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_ceremony_audit_test.exs test/sigra/oauth/oauth_test.exs` |
| **Estimated runtime** | compile ~30s; optional OAuth tests ~60s |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors`
- **After every plan wave:** Grep matrix from **Per-Task Verification Map** for edited files
- **Before `/gsd-verify-work`:** All map rows green
- **Max feedback latency:** Bounded by local compile (no new long-running suites required)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | OA-02 | T-59-01 | Honest machine vs human boundaries in public docs | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-01-02 | 01 | 1 | OA-02 | T-59-01 | SEED / GA cross-links point at hub subsection | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-02-01 | 02 | 2 | OA-02 | T-59-01 | GA-03 row layered CI_substitute | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-02-02 | 02 | 2 | OA-02 | T-59-01 | Waiver compensating_controls cite OA-01 modules | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-02-03 | 02 | 2 | OA-02 | — | INDEX optional pointer | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-02-04 | 02 | 2 | OA-02 | — | `ga-evidence.md` GitHub URLs | grep | See plan acceptance | ✅ | ⬜ pending |
| 59-02-05 | 02 | 2 | OA-02 | T-59-02 | PROJECT / MILESTONES vocabulary | grep | See plan acceptance | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- **Existing infrastructure covers all phase requirements.** No new test stubs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| Reader tone | OA-02 | Subjective “over-claim” scan | Maintainer reads GA-03 Notes + SEED-4 row after edits |

---

## Validation Sign-Off

- [ ] All tasks have grep-level `<acceptance_criteria>` or compile verify
- [ ] Sampling continuity: doc tasks use grep between waves
- [ ] Wave 0 N/A — acknowledged
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase evidence complete

**Approval:** pending
