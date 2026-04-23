---
phase: 58
slug: oauth-ceremony-audit-smoke
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 58 — Validation Strategy

> Per-phase validation contract for OAuth ceremony + audit smoke (**OA-01**).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) |
| **Config file** | `test/test_helper.exs` (no default OAuth excludes) |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_ceremony_audit_test.exs test/sigra/oauth/oauth_audit_atomicity_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~60–120s for quick path (depends on host Postgres) |

---

## Sampling Rate

- **After every task commit:** Run **quick run command** above (ceremony + atomicity files).
- **After every plan wave:** Run **`mix test test/sigra/oauth/`** or full **`mix test`** if OAuth-adjacent lib touched.
- **Before `/gsd-verify-work`:** Full suite green on CI-equivalent env.
- **Max feedback latency:** ~180s for quick path (Postgres cold start variance).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 58-01-01 | 01 | 1 | OA-01 | T-58-01 | No tokens/PII in audit metadata | integration | `mix test test/sigra/oauth/oauth_ceremony_audit_test.exs` | ⬜ W0 | ⬜ pending |
| 58-01-02 | 01 | 1 | OA-01 | T-58-01 | Registration audit row persisted | integration | `mix test test/sigra/oauth/oauth_ceremony_audit_test.exs` | ⬜ W0 | ⬜ pending |
| 58-01-03 | 01 | 1 | OA-01 | T-58-01 | Authorize audit row persisted | integration | `mix test test/sigra/oauth/oauth_ceremony_audit_test.exs` | ⬜ W0 | ⬜ pending |
| 58-01-04 | 01 | 1 | OA-01 | T-58-02 | Atomicity file keeps rollback proofs only | integration | `mix test test/sigra/oauth/oauth_audit_atomicity_test.exs` | ✅ | ⬜ pending |
| 58-02-01 | 02 | 1 | OA-01 | T-58-02 | `library_tests` runs plain `mix test` | unit (contract) | `mix test test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **Existing infrastructure covers all phase requirements** — `PostgresRepo`, `Sigra.Test.AuditEvent`, DDL patterns from **`oauth_audit_atomicity_test.exs`**; optional extract **`test/support/oauth_audit_repo_case.ex`** only if duplication exceeds **58-CONTEXT** discretion threshold.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live IdP OAuth | OA-01 | Out of scope v1.6 | Do not add; use **`MockStrategy`** / in-process maps only |

*All merge-blocking behaviors are automated.*

---

## Validation Sign-Off

- [ ] All tasks have `<verify>` / `<acceptance_criteria>` with **`mix test`** or grep
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency acceptable on CI (**`library_tests`**)
- [ ] `nyquist_compliant: true` set in frontmatter after execution

**Approval:** pending
