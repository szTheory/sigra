---
phase: 57
slug: nyquist-41-44-posture-matrix
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-22
---

# Phase 57 — Validation Strategy

> Maintainer documentation: canonical **41–44** Nyquist posture matrix + `MAINTAINING.md` index. No runtime auth code.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`MIX_ENV=test`) + static markdown checks |
| **Config file** | Root `mix.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/planning/ --warnings-as-errors` (when Plan 02 adds tests) |
| **Estimated runtime** | &lt; 30 seconds for planning tests |

---

## Sampling Rate

- **After every task commit:** Run quick **`phase_50`** doc contract (preserves **50-01-05** MAINTAINING anchors).
- **After Plan 02 (if executed):** Run **`mix test`** on new **`phase_57_*`** module.
- **Before sign-off:** `mix compile --warnings-as-errors` at repo root.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 57-01-01 | 01 | 1 | NYQ-01, NYQ-02 | T-57-01 | Matrix does not over-claim vs `*-VALIDATION.md` | grep + read | `rg '^## Nyquist policy \\(phases 41-44\\)' MAINTAINING.md` | ✅ | ⬜ pending |
| 57-02-01 | 02 | 2 | NYQ-01 (optional tighten) | T-57-01 | Contract catches dropped rows / blank disposition | ExUnit | `mix test test/sigra/planning/phase_57_nyquist_matrix_contract_test.exs` | ⬜ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**Existing infrastructure covers all phase requirements** — no new Wave 0 stubs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Human read of matrix vs phase prose | NYQ-02 | Tone / honesty beyond grep | Spot-check each **41–44** row against `41-44` `*-VALIDATION.md` waiver narrative |

---

## Validation Sign-Off

- [ ] Canonical matrix file under `.planning/` with `ref:` block and four disposition rows
- [ ] `MAINTAINING.md` links to matrix; heading **`## Nyquist policy (phases 41-44)`** preserved for **50-01-05** unless test updated same commit
- [ ] `mix compile --warnings-as-errors` green
- [ ] `phase_50_nyquist_docs_contract_test.exs` green
- [ ] `nyquist_compliant: true` in frontmatter only if team elevates this phase’s Nyquist posture (default remains **false** for doc waiver work)

**Approval:** pending
