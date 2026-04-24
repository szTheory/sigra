---
phase: 82
slug: jwt-refresh-persistence-audit-cofate
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-24
---

# Phase 82 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir **~> 1.18**) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` (via host **`Example.Repo`** patterns in atomic tests) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs test/sigra/api_token_audit_atomic_test.exs` |
| **Estimated runtime** | ~30–90 seconds (Postgres-bound) |

---

## Sampling Rate

- **After every task commit:** Run **quick run command** for the file touched by that plan wave.
- **After every plan wave:** Run **full suite command** above.
- **Before `/gsd-verify-work`:** Root **`mix test`** (per **CLAUDE.md**) must be green.
- **Max feedback latency:** ~120s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 82-01-01 | 01 | 1 | AUD-19-01, AUD-19-02 | T-82-01 | Co-fate txn: no persisted refresh without audit when `:audit_schema` | compile + integration | `MIX_ENV=test mix compile --warnings-as-errors` then cofate module after 02 | ⬜ W0 | ⬜ pending |
| 82-02-01 | 02 | 2 | AUD-19-03 | T-82-01 | Tests prove rollback + audit-off + reuse | integration | `mix test test/sigra/jwt_refresh_audit_cofate_test.exs` | ❌ until 02 | ⬜ pending |
| 82-03-01 | 03 | 3 | AUD-19-04 | — | Planning rows + CHANGELOG align | grep + manual read | `grep` rows per plan 03 | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing **`test/sigra/api_token_audit_atomic_test.exs`** + Postgres test repo patterns cover audit-only JWT helpers (Phase **81**).
- [x] **`mix test`** at repo root documented in **CLAUDE.md** — no new framework install.

*Wave 0 satisfied by existing Sigra test harness.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Maintainer merge | AUD-19-04 | Human judgment on doc tone | PR review + **`82-VERIFICATION.md`** sign-off row |

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` or equivalent automated command
- [ ] Sampling continuity: plan **02** runs after **01** lands
- [ ] No watch-mode flags in CI instructions
- [ ] Feedback latency acceptable on developer laptop
- [ ] `nyquist_compliant: true` set in frontmatter after merge gate

**Approval:** pending
