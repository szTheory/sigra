---
phase: 47
slug: phase-43-verification-aud0405
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 47 — Validation Strategy

> Closure validation for **`43-VERIFICATION.md`**, **`43-VALIDATION.md`** refresh, and **AUD-04 / AUD-05** traceability in `REQUIREMENTS.md` + `ROADMAP.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `config/test.exs`, `MIX_ENV=test` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile` |
| **Merge gate (AUD-05 proof)** | Scoped `mix test` on the four auth audit atomicity modules (see per-task map) |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | Scoped: ~1–3 min; full suite: ~2–8 min (local Postgres per `CLAUDE.md`) |

---

## Sampling Rate

- **After every doc-edit task:** Grep-based acceptance from PLAN.md tasks.
- **After wave 1 (plan 01):** Run merge-gate compound `mix test` at least once; record in `43-VERIFICATION.md`.
- **Before flipping AUD-04/05 in REQUIREMENTS.md:** Merge-gate green; optional full suite for release attestation row.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | AUD-04/05 | T-47-01 | Validation map matches merged tests | doc + grep | `rg "register_audit_atomicity" .planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md` | ✅ | ⬜ pending |
| 47-01-02 | 01 | 1 | AUD-04/05 | T-47-02 | Verification snapshot lists verbatim commands | doc review | (manual compare to PLAN) | ✅ | ⬜ pending |
| 47-01-03 | 01 | 1 | AUD-05 | T-47-03 | DB-backed atomicity tests pass | integration | compound `mix test` (4 paths) | ✅ | ⬜ pending |
| 47-02-01 | 02 | 2 | AUD-04/05 | T-47-04 | REQ checkboxes match verification presence | grep | `grep "AUD-04" .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] ExUnit + Postgres patterns from phase **43** — no new framework.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inventory row review | AUD-04 | Maintainer judgment | Spot-check `43-AUD-04-INVENTORY.md` vs `43-VERIFICATION.md` Must-haves |

---

## Validation Sign-Off

- [ ] All plan tasks have `<acceptance_criteria>` with grep or command checks
- [ ] `43-VERIFICATION.md` exists before AUD checkbox flips
- [ ] No watch-mode flags in documented commands
- [ ] `nyquist_compliant` on **43** validation **not** upgraded without phase **50** decision

**Approval:** pending
