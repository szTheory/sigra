---
phase: 15
slug: audit-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source of truth for dimensions: `15-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.18+) |
| **Config file** | `test/test_helper.exs`, `config/test.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Credo command** | `mix credo --strict` |
| **Migration check** | `MIX_ENV=test mix ecto.migrate && mix ecto.rollback --all` |
| **Estimated runtime** | ~45s quick / ~3min full |

---

## Sampling Rate

- **After every task commit:** `mix test --stale` (plus targeted file run for the edited module)
- **After every plan wave:** `mix test` full suite + `mix credo --strict`
- **Before `/gsd-verify-work`:** Full suite + Credo green; migration up/down dry-run green
- **Max feedback latency:** 60 seconds for `mix test --stale`

---

## Per-Task Verification Map

> Planner fills this in during step 8. Each PLAN.md task must have a row here or a Wave 0 dependency.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-XX | 01 | — | AUD-01..05 | — | (to be filled by planner) | — | — | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Derived from 15-RESEARCH.md §Validation Architecture. The planner must confirm or extend:

- [ ] `test/support/audit_test_event.ex` — add `:organization_id :binary_id` + `:effective_user_id :binary_id` fields before any sweep tests run
- [ ] `test/sigra/audit/log_safe_scope_test.exs` — new file stubbing `Sigra.Audit.log_safe/3` contract (nil scope, full scope, duck-typed scope, caller-opts-win)
- [ ] `test/sigra/audit/query_filters_test.exs` — new file stubbing `:organization_id`, `:effective_user_id`, `:organization_scope` filter cases AND unknown-key raise
- [ ] `test/sigra/audit/query_index_test.exs` — Postgres-only EXPLAIN-based index hit-count test for `(organization_id, inserted_at)`
- [ ] `test/sigra/scope/build_test.exs` — new file covering `Sigra.Scope.build/3` minimal/full/impersonating-from-nil shapes
- [ ] `test/sigra/workers/behaviour_test.exs` — new file covering `Sigra.Workers.new/3` enqueue validator fail-fast on missing keys
- [ ] `test/sigra/workers/account_deletion_test.exs` — existing file, gains scope/audit assertions
- [ ] `test/sigra/credo/no_log_safe2_in_lib_test.exs` — new file, uses `Credo.Test.Case` to verify check fires on arity-2 call in `lib/sigra/` and stays silent on the shim + tests
- [ ] `test/sigra/testing/assert_audit_logged_test.exs` — new file covering the new helper happy + mismatch paths
- [ ] `test/fixtures/install_golden/` — regen after generator template update
- [ ] `test/example/` — regen after generator template update

---

## Validation Dimensions (Nyquist)

Per 15-RESEARCH.md §Validation Architecture:

1. **Unit — audit helper:** `scope_fields/1` duck-typing, caller-opts-win merge, explicit nils
2. **Unit — scope builder:** `Sigra.Scope.build/3` shape correctness
3. **Unit — query filters:** each new filter + unknown-key raise (breaking change)
4. **Unit — workers behaviour:** `new/3` validator fail-fast + perform-time `Map.fetch!`
5. **Unit — Credo check:** custom check fires on arity-2, silent on shim/tests
6. **Integration — 79-site sweep:** `assert_audit_logged/2` one assertion per migrated call site (or representative subset with grep-based structural check)
7. **Integration — session.create ordering fix:** first audit of a login carries real `organization_id`
8. **Integration — worker audit emission:** `Sigra.Workers.AccountDeletion.perform/1` emits `account.deletion_executed` with reconstructed scope
9. **Migration safety — adapter branches:** Postgres concurrent index + `up/0`+`down/0`; SQLite/MySQL plain `change/0`; up+down round-trip clean
10. **Index-use proof:** EXPLAIN shows `(organization_id, inserted_at)` index hit under Postgres
11. **Generator install path:** install-golden fixture regen passes `mix test test/sigra/install/golden_diff_test.exs`
12. **Breaking-change verification:** CHANGELOG entries exist for (a) `session.create` reorder and (b) unknown-filter-key raise

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| One-line v1.2 impersonation diff in `scope_fields/1` | D-04 (CONTEXT.md) | Forward-looking design property, not testable today | Reviewer inspects `scope_fields/1` and confirms the short-circuit shape permits a single-line change for `impersonating_from` |
| Dashboard-level parallel between web and worker call sites | "Specific Ideas" (CONTEXT.md) | Readability check, not automatable | Reviewer opens `lib/sigra/auth.ex` and `lib/sigra/workers/account_deletion.ex` side by side; call shape is visually identical |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
