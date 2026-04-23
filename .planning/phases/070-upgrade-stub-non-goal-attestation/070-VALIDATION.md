---
phase: 70
slug: upgrade-stub-non-goal-attestation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-23
---

# Phase 70 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution (documentation + planning-surface phase).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Elixir / Mix (no new test framework) |
| **Config file** | `mix.exs` (ExDoc `extras`) |
| **Quick run command** | `MIX_ENV=dev mix compile --warnings-as-errors` |
| **Full suite command** | `MIX_ENV=dev mix docs --warnings-as-errors` |
| **Estimated runtime** | ~1–5 minutes |

---

## Sampling Rate

- **After every task commit:** `MIX_ENV=dev mix compile --warnings-as-errors`
- **After every plan wave:** `MIX_ENV=dev mix docs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Docs build green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 70-01-01 | 01 | 1 | ACF-05 | T-70-01 | No false “guaranteed secure upgrade” claims | grep + docs | `test -f guides/introduction/upgrading-to-v1.10.md` | ✅ | ⬜ pending |
| 70-01-02 | 01 | 1 | ACF-05 | — | `extras` order after v1.8 path | ruby | `ruby -e 't=File.read(%q{mix.exs}); i=t.index(%q{guides/introduction/upgrading-to-v1.8.md}); j=t.index(%q{guides/introduction/upgrading-to-v1.10.md}); exit(i && j && j>i ? 0 : 1)'` | ✅ | ⬜ pending |
| 70-02-01 | 02 | 1 | ACF-06 | — | Out of scope links ADR + SEED paths | grep | `grep -F 'decisions/001-defer-sigra-lockspire-glue-package.md' .planning/REQUIREMENTS.md` AND `grep -F 'seeds/SEED-002-phase-9-log-safe-atomicity-followup.md' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |
| 70-02-02 | 02 | 1 | ACF-06 | — | PROJECT milestone cites both artifacts | grep | `grep -F '001-defer-sigra-lockspire' .planning/PROJECT.md` AND `grep -F 'SEED-002-phase-9' .planning/PROJECT.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Existing infrastructure covers all phase requirements** — no new `test/` modules unless an executor discovers Elixir changes (not expected).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ExDoc TOC / slug | ACF-05 | ExDoc version quirks | Run `mix docs`, open new page from Introduction group, confirm title renders |

---

## Validation Sign-Off

- [ ] All tasks have grep or `mix docs` verification
- [ ] `nyquist_compliant: true` set in frontmatter after wave green

**Approval:** pending
