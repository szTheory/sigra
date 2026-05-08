---
phase: 108
slug: revoke-other-sessions-and-session-truth
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 108 — Validation Strategy

> Per-phase validation contract for executing the Phase 108 plan set.
> Sourced from `108-CONTEXT.md`, `108-RESEARCH.md`, and `108-01..03-PLAN.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix.LiveViewTest, Phoenix.ConnTest, raw-template assertions, targeted docs grep |
| **Config file** | `test/test_helper.exs`; `test/example/test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs --no-color` |
| **Wave merge smoke** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/user_auth_test.exs --no-color)` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/user_auth_test.exs --no-color) && MIX_ENV=test mix compile --warnings-as-errors && rg -n \"other sessions|revoke all|except the current session|current session\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md` |
| **Estimated runtime** | ~20-40s quick loop, ~90-150s focused phase gate |

---

## Sampling Rate

- **After every task commit:** run the task-level `<automated>` command from the touched plan.
- **After wave 1 (`108-01`):** run the root library quick suite plus compile.
- **After wave 2 (`108-02`):** run template parity and the example user-session LiveView suite from inside `test/example`.
- **After wave 3 (`108-03`) / before `$gsd-verify-work`:** run the full suite command above plus docs grep.
- **Max feedback latency:** ~40s for task-level loops, ~150s for the focused phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 108-01-01 | 01 | 1 | SESS-02 / SESS-05 | preserve-current revoke deletes sibling sessions only, fails closed when current-session proof is missing, and emits distinct preserve-current audit semantics | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs --no-color` | ✅ existing files to extend | ✅ verified via `108-VERIFICATION.md` |
| 108-02-01 | 02 | 2 | SESS-02 / SESS-04 / SESS-05 | generated user session surface derives the authoritative current hashed token, revokes sibling sessions only, and keeps the initiator signed in | LiveView | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs --no-color)` | ✅ file created in task | ✅ verified via `108-VERIFICATION.md` |
| 108-02-02 | 02 | 2 | SESS-05 | example app and install templates stay in parity for helper names and preserve-current copy | template | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/session_templates_test.exs --no-color` | ✅ existing file to extend | ✅ verified via `108-VERIFICATION.md` |
| 108-03-01 | 03 | 3 | SESS-04 / SESS-05 | admin self-view can mark the current session only from authoritative current-session identity and non-self-view does not guess | LiveView + unit | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/admin_user_show_live_test.exs test/example_web/user_auth_test.exs --no-color)` | ✅ existing files to extend | ✅ verified via `108-VERIFICATION.md` |
| 108-03-02 | 03 | 3 | SESS-05 | public docs distinguish preserve-current revoke from revoke-all and stay honest about scope | docs/grep | `rg -n \"other sessions|revoke all|except the current session|current session\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md` | ✅ existing files to extend | ✅ verified via `108-VERIFICATION.md` |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SESS-02 | preserve-current revoke deletes sibling sessions only and never silently degrades to revoke-all | unit + LiveView | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs --no-color)` | library files exist; user LiveView test created in wave 2 |
| SESS-04 | user/admin surfaces clearly identify the current session and only show coarse truthful state | LiveView + unit | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/user_auth_test.exs --no-color)` | admin/user_auth files exist; user session LiveView test created in wave 2 |
| SESS-05 | generated wrappers remain thin and template/doc parity stay aligned with library truth | template + docs | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/session_templates_test.exs --no-color && rg -n \"other sessions|revoke all|except the current session|current session\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md` | ✅ existing files |

---

## Wave 0 Requirements

- [x] Create `test/example/test/example_web/live/auth/session_live_test.exs` for preserve-current revoke and current-session truth.
- [x] Extend `test/sigra/auth_test.exs` with explicit preserve-current audit/result semantics.
- [x] Extend `test/example/test/example_web/live/admin_user_show_live_test.exs` with authoritative self-view current-session labeling and non-self-view restraint.
- [x] Extend `test/sigra/templates/session_templates_test.exs` with preserve-current helper/copy assertions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 108 should be fully automatable; this slice is library/session truth plus generated/admin/docs parity, not human-witness UI polish. | — |

---

## Validation Sign-Off

- [x] All plans have concrete automated verify commands
- [x] Example-app verification commands use the nested `test/example` execution path where applicable
- [x] Sampling continuity: no wave ends without an automated gate
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Phase 108 is now execution-complete and authoritatively verified by `108-VERIFICATION.md`.
