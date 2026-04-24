---
phase: 75
slug: upgrade-continuity-triage-polish
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-23
---

# Phase 75 — Validation Strategy

> Per-phase validation contract for **documentation + planning** edits (no `lib/` feature work).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExDoc + Mix (library root) |
| **Config file** | `mix.exs` → `docs/0` |
| **Quick run command** | `MIX_ENV=test mix compile --warnings-as-errors` |
| **Full suite command** | `mix docs --warnings-as-errors` |
| **Estimated runtime** | ~30–120 seconds (docs build) |

---

## Sampling Rate

- **After every task commit:** `MIX_ENV=test mix compile --warnings-as-errors`
- **After every plan wave:** `mix docs --warnings-as-errors`
- **Before `/gsd-verify-work`:** Both commands above exit **0**
- **Max feedback latency:** ~120s (docs)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 75-01-01 | 01 | 1 | TRN-01 | T-75-01 | No relative `.planning/` in hex-facing upgrade stub for canonical indexes | docs | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 75-01-02 | 01 | 1 | TRN-01 | T-75-02 | Extras ordering + conditional skip only when required | docs | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 75-02-01 | 02 | 2 | TRN-02 | T-75-03 | Stable upgrade cross-links | docs | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 75-02-02 | 02 | 2 | TRN-02 | T-75-03 | Maintainer/CHANGELOG bullets without matrix fork | docs | `mix docs --warnings-as-errors` | ✅ | ⬜ pending |
| 75-03-01 | 03 | 1 | TRN-03 | — | Append-only triage reconciliation | manual+grep | `grep -nF 'v1.12 reconciliation' .planning/v1.11-TRIAGE.md` | ✅ | ⬜ pending |
| 75-03-02 | 03 | 1 | TRN-03 | — | Verification file echoes triage | grep | `grep -nF 'v1.11-TRIAGE' .planning/phases/75-upgrade-continuity-triage-polish/75-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- **Existing infrastructure covers all phase requirements** — no new test stubs; CI already runs `mix docs --warnings-as-errors`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| HexDocs reader path | TRN-01 | Local HTML is not identical to hexdocs layout | Open `doc/getting-started.html` (after `mix docs`) and confirm **Faster path** contains **v1.12** upgrade link. |
| Blob link liveness | TRN-01 | External GitHub | Click each `https://github.com/sztheory/sigra/blob/main/.planning/...` link from rendered page; expect **200** on `main`. |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or grep-based acceptance
- [ ] Sampling continuity: docs command after each wave
- [ ] No watch-mode flags
- [ ] `nyquist_compliant: true` set in frontmatter when approved

**Approval:** pending
