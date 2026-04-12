---
phase: 12
slug: scope-session-foundation
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-11
updated: 2026-04-11
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from `12-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (library, Elixir 1.18+ / 1.19.5) + ExUnit in `test/example/` (generated app sub-project) |
| **Config file** | `test/test_helper.exs` (library) and `test/example/test/test_helper.exs` (example app) |
| **Quick run command** | `mix test test/sigra/session_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/install/features/core_test.exs test/sigra/install/scope_template_invariants_test.exs` |
| **Full suite command** | `mix test && cd test/example && mix compile --warnings-as-errors && mix test` |
| **Golden-diff command** | `mix test --only golden` (run separately — slow, ~300s, shells out to `mix phx.new`) |
| **Estimated quick runtime** | ~5–15 seconds |

---

## Sampling Rate

- **After every task commit:** Run the **Quick run command** above.
- **After every plan wave:** Run the **Full suite command** above.
- **Before `/gsd-verify-work`:** Full suite + golden-diff must be green; `cd test/example && mix compile --warnings-as-errors` must be clean (D-16).
- **Max feedback latency:** ~15 seconds for the quick path. The golden-diff (`mix test --only golden`) and the full example suite are intentionally slow gates run only at wave-merge time — see "Slow-Gate Acknowledgement" below.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | ORG-SCOPE-02 | T-12-01 | `%Sigra.Session{}` carries `active_organization_id` end-to-end through the struct + typespec | unit | `mix test test/sigra/session_test.exs` | ✅ (extend) | ⬜ pending |
| 12-01-02 | 01 | 1 | ORG-SCOPE-02 | T-12-02 | `Sigra.SessionStores.Ecto` round-trips the new column on `create/3` + `fetch/2` (no field leaks/drops) | unit (Mox) | `mix test test/sigra/session_stores/ecto_test.exs` | ✅ (extend) | ⬜ pending |
| 12-02-01 | 02 | 1 | ORG-SCOPE-02 | T-12-04 | New ALTER migration template renders dialect-agnostic, no user-controlled inputs | unit | `test -f priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs && mix run -e 'EEx.eval_file(...)'` | ❌ Wave 0 (created inline by task) | ⬜ pending |
| 12-02-02 | 02 | 1 | ORG-SCOPE-02 | T-12-05 | `Features.Core.migrations/1` returns 4 slots in canonical order; `base_files/1` inlines new migration immediately after `:primary` (deterministic STDOUT ordering) | unit | `mix test test/sigra/install/features/core_test.exs && mix test test/sigra/install/` | ✅ (extend counts + slot + sources sites) | ⬜ pending |
| 12-03-01 | 03 | 1 | ORG-SCOPE-01 | T-12-07 | Generated `Scope` template has 4-field defstruct with reserved `:impersonating_from` doc-commented | unit | `mix test test/sigra/install/scope_template_invariants_test.exs` (subset of file) | ❌ Wave 0 (created inline by task 12-03-02) | ⬜ pending |
| 12-03-02 | 03 | 1 | ORG-SCOPE-01 | T-12-08 / T-12-09 | Library-side invariant test (D-11): source-grep + compile-and-introspect both fire on removal of `:impersonating_from`; failure messages cite `UPGRADE-v1.2.md` | unit | `mix test test/sigra/install/scope_template_invariants_test.exs` | ❌ Wave 0 (created inline) | ⬜ pending |
| 12-04-01 | 04 | 2 | ORG-SCOPE-01 / ORG-SCOPE-02 | T-12-13 | `test/example` app mirrors template changes; `mix compile --warnings-as-errors` is clean (D-16); new migration applies cleanly via `mix ecto.reset` | integration | `cd test/example && mix compile --warnings-as-errors && mix ecto.reset --quiet && mix test` | ✅ (extend example app) | ⬜ pending |
| 12-04-02 | 04 | 2 | ORG-SCOPE-01 / ORG-SCOPE-02 | T-12-10 | Golden-diff fixture rebased: exactly ONE new file + ONE new STDOUT line; ZERO collateral changes to Phase 11 fixture files (D-15 byte-identity) | integration (slow) | `mix test --only golden` | ✅ (rebase) | ⬜ pending |
| 12-04-03 | 04 | 2 | ORG-SCOPE-02 | T-12-11 / T-12-12 | D-14 clarified: DB round-trip survives write/read; default-nil works; Plug pipeline survives login (`:user_token` cookie unchanged); `active_organization_id` does NOT leak into Plug cookie session | integration | `cd test/example && mix test test/example_web/smoke/session_active_org_round_trip_test.exs && mix test` | ❌ Wave 0 (created inline) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All Wave 0 gaps from RESEARCH.md §Validation Architecture are satisfied **inline by the tasks that need them** — no separate Wave 0 plan is required because each new test file's creation is the first step of the task that consumes it.

- [x] `test/sigra/install/scope_template_invariants_test.exs` — covers ORG-SCOPE-01 reserved-field discipline (D-11). **Created inline by Plan 12-03 Task 2.**
- [x] `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs` — covers ORG-SCOPE-02 end-to-end DB round-trip + Plug pipeline survival (D-14 clarified). **Created inline by Plan 12-04 Task 3.**
- [x] `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` — new EEx template the tests rely on. **Created inline by Plan 12-02 Task 1.**
- [x] No framework install needed — ExUnit is built in; the `test/example/` Mix project is already configured by Phase 10.1.1.

---

## Slow-Gate Acknowledgement

Plan 04 Tasks 1 and 2 intentionally use slow commands. This is **not a plan bug** — Plan 04 IS the integration wave for Phase 12, so it has to pay the slow-gate cost once at the end:

| Slow Command | Why It's Slow | Why It Lives in Plan 04 |
|--------------|---------------|-------------------------|
| `mix test --only golden` | Shells out to `mix phx.new` and runs the full installer; 300s timeout per `golden_diff_test.exs`. | Plan 04 IS the golden-diff rebase (D-15). The other plans' faster verifications already cover their slices; the golden-diff is the final cross-slice integration check. |
| `cd test/example && mix compile --warnings-as-errors && mix ecto.reset --quiet && mix test` | Boots a real Postgres-backed Phoenix app, runs migrations, runs the full example suite. | D-16 mandates the example app compiles warning-free with the new defstruct fields; the round-trip test (Task 3) needs the example app's real DB. This is the integration gate. |

These slow gates are **not** sampled per-task in plans 01–03 — only at wave-2 merge and at phase-gate. Plans 01–03 use the fast quick-run command for sampling continuity.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|

*All Phase 12 behaviors have automated verification. No manual-only steps.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (every task above has a concrete `mix test ...` command)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has one)
- [x] Wave 0 covers all MISSING references (the three new files are created inline by their consuming tasks)
- [x] No watch-mode flags
- [x] Feedback latency < 15s for the per-task quick command
- [x] `nyquist_compliant: true` set in frontmatter
- [x] `wave_0_complete: true` set in frontmatter (inline-creation policy satisfies the gap)

**Approval:** approved 2026-04-11
