---
phase: 49
slug: phase-45-verification-aud08-c1
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-21
---

# Phase 49 — Validation Strategy

> Documentation + traceability closure for **AUD-08** and **Phase 9 C-1**. No new `lib/` product scope.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `mix.exs`, `config/test.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile` |
| **Full merge gate** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.audit_45` (after **49-01** adds alias) |
| **Estimated runtime** | ~1–4 minutes (Postgres-dependent) |

---

## Sampling Rate

- After **49-01** Task 3: run merge gate once; record output in **`45-VERIFICATION.md`**.
- After **49-02** Task 1: grep **`45-VERIFICATION.md`** `status: passed` before **`REQUIREMENTS.md`** edits.
- Before treating phase **49** as done: both plan waves’ acceptance greps pass.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 49-01-01 | 01 | 1 | AUD-08 | T-49-01 | Honest verification file | grep + mix | `mix ci.audit_45` after alias | ✅ | ⬜ pending |
| 49-01-02 | 01 | 1 | AUD-08 | T-49-02 | No secrets in verification | grep | `grep -iE "client_secret|Bearer [A-Za-z0-9_-]{20,}" .planning/phases/45-oauth-ops-c1-signoff/45-VERIFICATION.md` → exit 1 | ✅ | ⬜ pending |
| 49-02-01 | 02 | 2 | AUD-08 | T-49-03 | REQ flip only after proof | grep | `grep -E "^status: passed" .planning/phases/45-oauth-ops-c1-signoff/45-VERIFICATION.md` | ✅ | ⬜ pending |
| 49-02-02 | 02 | 2 | AUD-08 | — | C-1 exhaustive | grep | `grep -F "### C-1 — Phase 43 inventory" .planning/phases/09-audit-logging/09-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] ExUnit + Postgres from prior phases; no new Wave 0 install.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| External OAuth HTTP | AUD-08 | Assent / provider I/O | Optional harness — not claimed in **AUD-08** merge gate |

---

## Validation Sign-Off

- [ ] All **49-01** / **49-02** tasks have concrete `<acceptance_criteria>` satisfied
- [ ] `nyquist_compliant: false` remains until **phase 50** (or `nyquist_escalation_authorized` in **STATE.md**)
- [ ] No watch-mode flags in documented commands

**Approval:** pending
