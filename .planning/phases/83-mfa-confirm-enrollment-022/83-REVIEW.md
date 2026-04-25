---
status: clean
depth: quick
---

# Phase 83 — code review (orchestrator quick pass)

**Scope:** `lib/sigra/mfa.ex`, `test/sigra/mfa_audit_atomicity_test.exs`

## Findings

None blocking. Invalid-code path correctly guards on **`mfa_audit_opts`** **`:audit_schema`**, delegates to existing **`commit_ad_hoc_mfa_audit/5`** (telemetry + constraint / changeset error handling already centralized), and preserves **`{:error, :invalid_code}`** for callers. Tests mirror existing CHECK-guard + telemetry patterns from **`api_token_audit_atomic_test.exs`**.

## Advisory

- Fault-injection test accepts **`:constraint_violation`** or **`:invalid_changeset`** on **`log_safe_error`** because Ecto may surface DB **`CHECK`** failures as changeset errors inside **`Repo.transaction/1`** — both match **`commit_ad_hoc_mfa_audit/5`** operator signals.
