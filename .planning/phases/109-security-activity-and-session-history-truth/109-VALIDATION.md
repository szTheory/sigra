---
phase: 109
slug: security-activity-and-session-history-truth
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-08
---

# Phase 109 — Validation Strategy

> Per-phase validation contract for executing the Phase 109 plan set.
> Sourced from `109-CONTEXT.md`, `109-RESEARCH.md`, and `109-01..03-PLAN.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix.LiveViewTest, Phoenix.ConnTest, raw-template assertions, targeted docs grep |
| **Config file** | `test/test_helper.exs`; `test/example/test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/sigra/security_activity_test.exs --no-color` |
| **Wave merge smoke** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/sigra/security_activity_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/live/admin_audit_user_live_test.exs --no-color)` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/sigra/security_activity_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs test/example_web/live/admin_audit_user_live_test.exs --no-color) && MIX_ENV=test mix compile --warnings-as-errors && rg -n \"logout|revoke other|revoke all|security activity|timeout\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md` |
| **Estimated runtime** | ~25-45s quick loop, ~100-160s focused phase gate |

---

## Sampling Rate

- **After every task commit:** run the task-level `<automated>` command from the touched plan.
- **After wave 1 (`109-01`):** run the root library quick suite plus compile.
- **After wave 2 (`109-02`):** run template parity and the example user-session LiveView suite from inside `test/example`.
- **After wave 3 (`109-03`) / before `$gsd-verify-work`:** run the full suite command above plus docs grep.
- **Max feedback latency:** ~45s for task-level loops, ~160s for the focused phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 109-01-01 | 01 | 1 | SESS-03 / SESS-05 | recent activity is selected from persisted subject-user truth with deterministic ordering and normalized shared semantics | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs --no-color` | ✅ file created in task | ✅ verified via `109-VERIFICATION.md` |
| 109-01-02 | 01 | 1 | SESS-03 | owner-initiated logout persists `auth.logout`, MFA completion persists distinct activity truth, and no timeout-history rows are introduced | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/security_activity_test.exs --no-color` | ✅ existing auth test + created security activity test | ✅ verified via `109-VERIFICATION.md` |
| 109-02-01 | 02 | 2 | SESS-03 / SESS-04 / SESS-05 | sessions page renders recent activity from the library seam and preserves current-session / present-state truth after the new section is added | LiveView | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs --no-color)` | ✅ existing file to extend | ✅ verified via `109-VERIFICATION.md` |
| 109-02-02 | 02 | 2 | SESS-05 | example app and install templates stay in parity for recent-activity helpers, logout wiring, and user-visible copy | template | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/session_templates_test.exs --no-color` | ✅ existing file to extend | ✅ verified via `109-VERIFICATION.md` |
| 109-03-01 | 03 | 3 | SESS-03 / SESS-04 / SESS-05 | admin preview/explorer align with shared activity semantics while retaining truthful current-session / present-state labels and excluding timeout history | LiveView | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/admin_user_show_live_test.exs test/example_web/live/admin_audit_user_live_test.exs --no-color)` | ✅ existing files to extend | ✅ verified via `109-VERIFICATION.md` |
| 109-03-02 | 03 | 3 | SESS-03 / SESS-05 | docs distinguish `auth.logout`, revoke-other, revoke-all, suspicious-login visibility, and explicitly avoid timeout-history claims | docs/grep | `rg -n \"logout|revoke other|revoke all|security activity|timeout\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md` | ✅ existing files to extend | ✅ verified via `109-VERIFICATION.md` |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| SESS-03 | recent security activity is rendered from persisted Sigra-owned truth with stable ordering and bounded metadata | unit + LiveView | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/security_activity_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs --no-color)` | library test created in wave 1; LiveView test exists |
| SESS-04 | touched user/admin session surfaces retain truthful current-session and already-owned present-state labels after the activity feed lands | LiveView | `(cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs test/example_web/live/admin_user_show_live_test.exs --no-color)` | ✅ existing files to extend |
| SESS-05 | generated wrappers stay thin, template parity holds, and docs remain aligned with library-owned semantics | template + docs | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/session_templates_test.exs --no-color && rg -n \"logout|revoke other|revoke all|security activity|timeout\" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md` | ✅ existing files |

---

## Wave 0 Requirements

- [x] Create `test/sigra/security_activity_test.exs` for deterministic ordering, normalized semantics, and bounded row payloads.
- [x] Extend `test/sigra/auth_test.exs` with explicit `auth.logout` and MFA-completion activity coverage.
- [x] Extend `test/example/test/example_web/live/auth/session_live_test.exs` with recent-activity rendering plus explicit non-regression assertions for current-session and present-state labels.
- [x] Extend `test/example/test/example_web/live/admin_user_show_live_test.exs` and `test/example/test/example_web/live/admin_audit_user_live_test.exs` with overlapping semantic alignment and `SESS-04` non-regression coverage.
- [x] Extend `test/sigra/templates/session_templates_test.exs` with recent-activity helper/copy and logout-wrapper parity assertions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 109 should be fully automatable; this slice is audit/session truth plus generated/admin/docs parity, not human-witness UI polish. | — |

---

## Validation Sign-Off

- [x] All plans have concrete automated verify commands
- [x] Example-app verification commands use the nested `test/example` execution path where applicable
- [x] Sampling continuity: no wave ends without an automated gate
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** Phase 109 is now execution-complete and authoritatively verified by `109-VERIFICATION.md`.
