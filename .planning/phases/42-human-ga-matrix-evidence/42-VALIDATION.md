---
phase: 42
slug: human-ga-matrix-evidence
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-20
---

# Phase 42 — Validation Strategy

> Documentation and evidence layout; minimal runtime code.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / Mix (repo default) + markdown link checks |
| **Config file** | `mix.exs` (root) |
| **Quick run command** | `bash -lc 'cd /Users/jon/projects/sigra && mix compile --warnings-as-errors'` (only if `*.ex` / `*.exs` touched) |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (only if tests touched — not expected) |
| **Estimated runtime** | ~60–120 seconds when Mix runs; grep-only tasks &lt;5 seconds |

---

## Sampling Rate

- **After every task commit:** Run that task’s `<acceptance_criteria>` grep bundle (mandatory).
- **After every plan wave:** Confirm new/edited markdown files contain required section headers from plans.
- **Before `/gsd-verify-work`:** `mix compile --warnings-as-errors` if any Elixir changed; else skip with note.
- **Max feedback latency:** Bounded by single Mix compile when applicable.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 42-01-01 | 01 | 1 | GA-05 | T-42-01 | Matrix file authoritative, no orphan rows | grep | `grep -q "v1.4-GA-UAT" .planning/v1.4-GA-UAT.md` | ⬜ W1 | ⬜ pending |
| 42-02-01 | 02 | 2 | GA-02..04 | T-42-03 | Evidence templates remind redaction | grep | `test -f .planning/uat-evidence/v1.4/GA-02/README.md` | ⬜ W2 | ⬜ pending |
| 42-03-01 | 03 | 2 | GA-05 | T-42-02 | Coverage doc cross-links matrix | grep | `grep -q "v1.4-GA-UAT" docs/uat-ci-coverage.md` | ⬜ W2 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red*

---

## Wave 0 Requirements

- [x] **Existing infrastructure covers all phase requirements.** No new test modules required for planning artifacts; optional `scripts/ci/getting-started-contract.sh` regression only if `getting-started.md` strings change.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|---------------------|
| GA-02 MUA rendering | GA-02 | Real mail clients | Run `steps.md` in `uat-evidence/v1.4/GA-02/` on release boundary; attach screenshots to evidence path |
| GA-03 live Google | GA-03 | IdP policy + consent UX | Dedicated OAuth client checklist in `GA-03/steps.md` |
| GA-04 clean machine | GA-04 | Human wall-clock | Witnessed 30 min protocol per D-42-03 in `GA-04/steps.md` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: grep after each doc task
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter after execution waves green

**Approval:** pending
