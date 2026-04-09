---
phase: 9
slug: audit-logging
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir ~> 1.18) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --stale` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | TBD after Wave 0 smoke |

---

## Sampling Rate

- **After every task commit:** Run `mix test --stale`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

*To be populated by the planner in Step 8. One row per task. The planner MUST include an `<automated>` verify command for each task, or declare a Wave 0 dependency.*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 9-01-01 | 01 | 1 | AUDIT-01..04 | T-9-01 | TBD | unit | `mix test test/sigra/audit_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

From RESEARCH.md §8 Validation Architecture — pre-implementation test scaffolding:

- [ ] `test/sigra/audit_test.exs` — unit stubs for changeset validators (action regex, reserved prefix, metadata size, forbidden keys)
- [ ] `test/sigra/audit/cursor_test.exs` — cursor encode/decode roundtrip stubs
- [ ] `test/sigra/audit/query_test.exs` — filter composition stubs (each filter in D-12)
- [ ] `test/sigra/audit_integration_test.exs` — `log/3` single-txn + `log_multi/3` business-op rollback stubs
- [ ] `test/sigra/audit_property_test.exs` — cursor monotonicity, forbidden-keys property, action-prefix correctness (add `stream_data` if not present)
- [ ] `test/sigra/audit_observability_test.exs` — telemetry fires once on commit, never on rollback
- [ ] `test/sigra/audit_sensitive_data_test.exs` — parameterized test over all D-26 operations: no forbidden keys in emitted metadata
- [ ] `test/sigra/audit_security_test.exs` — reserved-prefix rejection at public API, internal `__log_internal__` not exported
- [ ] Cross-database check: confirm existing test infra runs against PG + SQLite in CI (Wave 0 smoke); flag if MySQL adapter missing
- [ ] Cursor row-comparison portability smoke test (per RESEARCH.md A3) — confirm `or`-expanded tuple comparison query plan on PG + SQLite before committing to the pattern

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Oban-absent inline fallback for `Sigra.Audit.cleanup/1` | D-10 (retention) | Requires toggling optional Oban dep; CI typically runs with Oban present | Temporarily remove `:oban` from `mix.exs` deps, run `mix compile` and `Sigra.Audit.cleanup(retention_days: 30)` — confirm inline path works and startup warning logs |
| Performance budget: login p99 overhead < 2ms from audit write | Non-functional (RESEARCH §8) | Requires benchmarking harness outside unit tests | Run `mix run bench/audit_login_overhead.exs` (to be added in Wave 0 if budget enforcement required); compare baseline vs audit-enabled |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
