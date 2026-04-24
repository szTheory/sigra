---
phase: 74
slug: planning-truth-launch-evidence
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-23
---

# Phase 74 — Validation Strategy

> Documentation and planning-artifact phase: feedback sampling is **grep + link hygiene + compile**, not feature tests.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / Mix (repo compile as sanity gate) |
| **Config file** | none |
| **Quick run command** | `MIX_ENV=test mix compile --warnings-as-errors` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (optional full gate before merge — not required after every doc-only task if compile green) |
| **Estimated runtime** | compile ~30–90s; full test suite longer |

---

## Sampling Rate

- **After every task commit:** `MIX_ENV=test mix compile --warnings-as-errors`
- **After every plan wave:** Headline greps from plan `verify` blocks + compile
- **Before `/gsd-verify-work`:** Full suite green if executor touched `lib/` or `test/` (not expected in **74**)
- **Max feedback latency:** ~2 minutes for compile-only iterations

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 74-01-01 | 01 | 1 | AUD-12 | T-74-01 | Honest planning trace; no false C-1 claims | grep | See **74-01-PLAN** task verify | ✅ | ⬜ pending |
| 74-02-01 | 02 | 1 | UAT-01 | — | Eight SEED rows in order | grep | See **74-02-PLAN** task verify | ✅ post-create | ⬜ pending |
| 74-02-02 | 02 | 1 | UAT-02 | — | ExDoc links evidence path | grep | See **74-02-PLAN** task verify | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Executor: replace row-level greps with the exact `verify` commands from **74-*-PLAN.md** at run time.*

---

## Wave 0 Requirements

- [x] Existing **Elixir** test infrastructure — no new stubs required for doc-only phase.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Readability of new **09-03** paragraph | AUD-12 | Subjective tone | Maintainer skim **Recent bounded batches** for clarity |

---

## Validation Sign-Off

- [ ] All tasks have `verify` or compile gate
- [ ] Sampling continuity: compile after each commit
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when phase execution completes

**Approval:** pending
