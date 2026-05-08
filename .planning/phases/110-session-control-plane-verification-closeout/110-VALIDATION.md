---
phase: 110
slug: session-control-plane-verification-closeout
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-08
---

# Phase 110 — Validation Strategy

> Per-phase validation contract for executing the Phase 110 plan set.
> Sourced from `110-CONTEXT.md`, `110-RESEARCH.md`, and `110-01..03-PLAN.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix.LiveViewTest, raw-template assertions, targeted docs grep, planning-file grep |
| **Config file** | `test/test_helper.exs`; `test/example/test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs test/sigra/templates/session_templates_test.exs --no-color` |
| **Wave merge smoke** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/live/admin_audit_user_live_test.exs\",\"test/example_web/user_auth_test.exs\",\"--no-color\"])")` |
| **Full suite command** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/live/admin_audit_user_live_test.exs\",\"test/example_web/user_auth_test.exs\",\"--no-color\"])") && rg -n "other sessions|revoke all|except the current session|current session" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md && rg -n "logout|revoke other|revoke all|security activity|timeout" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md && rg -n "SESS-02|SESS-03|SESS-04|SESS-05|108-VERIFICATION|109-VERIFICATION|v1.24-MILESTONE-AUDIT" .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.24-MILESTONE-AUDIT.md` |
| **Estimated runtime** | ~40-70s quick loop, ~120-220s focused phase gate |

---

## Sampling Rate

- **After every task commit:** run the task-level `<automated>` command from the touched plan.
- **After wave 1 (`110-01` and `110-02` in parallel):** rerun the focused Phase 108 and Phase 109 closeout lanes and verify both `108-VERIFICATION.md` and `109-VERIFICATION.md` shapes.
- **After wave 3 (`110-03`) / before `$gsd-verify-work`:** run the full suite command above plus the active-truth grep gate.
- **Max feedback latency:** ~70s for task-level loops, ~220s for the focused phase gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 110-01-01 | 01 | 1 | SESS-02 / SESS-04 / SESS-05 | current-head reruns settle preserve-current revoke, current-session truth, and doc parity without preserving stale blocker state | unit + LiveView + docs | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/user_auth_test.exs\",\"--no-color\"])") && rg -n "other sessions|revoke all|except the current session|current session" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md` | ✅ existing files | ⬜ pending |
| 110-01-02 | 01 | 1 | SESS-02 / SESS-04 / SESS-05 | `108-VERIFICATION.md` records implementation-vs-closeout truth, fresh rerun evidence, and blocker resolution in repaired-form structure | docs/grep | `bash -lc 'set -euo pipefail; file=.planning/phases/108-revoke-other-sessions-and-session-truth/108-VERIFICATION.md; test -f "$file"; rg -n "^phase: 108$|^status: passed$|^score: " "$file"; rg -n "^## Requirements$|^## Evidence$|^## Attestation$|^## Residuals$" "$file"; rg -n "implemented in Phase 108|authoritatively verified in Phase 110|Historical summary evidence|Fresh current-head rerun|20260507220000_add_webhook_replay_fields|resolved|still present|superseded" "$file"'` | ❌ new file created in task | ⬜ pending |
| 110-02-01 | 02 | 1 | SESS-03 / SESS-04 / SESS-05 | current-head reruns prove recent security activity, admin alignment, and docs truth on the shipped session-control surface | unit + LiveView + docs | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/security_activity_test.exs test/sigra/suspicious_login_test.exs test/sigra/templates/session_templates_test.exs --no-color && (cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/live/admin_audit_user_live_test.exs\",\"--no-color\"])") && rg -n "logout|revoke other|revoke all|security activity|timeout" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md` | ✅ existing files | ⬜ pending |
| 110-02-02 | 02 | 1 | SESS-03 / SESS-04 / SESS-05 | `109-VERIFICATION.md` records implementation-vs-closeout truth, fresh rerun evidence, and timeout-scope honesty in repaired-form structure | docs/grep | `bash -lc 'set -euo pipefail; file=.planning/phases/109-security-activity-and-session-history-truth/109-VERIFICATION.md; test -f "$file"; rg -n "^phase: 109$|^status: passed$|^score: " "$file"; rg -n "^## Requirements$|^## Evidence$|^## Attestation$|^## Residuals$" "$file"; rg -n "implemented in Phase 109|authoritatively verified in Phase 110|Historical summary evidence|Fresh current-head rerun|timeout history remains out of scope|timeout-history" "$file"'` | ❌ new file created in task | ⬜ pending |
| 110-03-01 | 03 | 3 | SESS-02 / SESS-03 / SESS-04 / SESS-05 | both validation files reconcile truth conditionally: green if verification passed, partial/blocked if verification did not pass | docs/grep | `bash -lc 'set -euo pipefail; v108=.planning/phases/108-revoke-other-sessions-and-session-truth/108-VERIFICATION.md; v109=.planning/phases/109-security-activity-and-session-history-truth/109-VERIFICATION.md; val108=.planning/phases/108-revoke-other-sessions-and-session-truth/108-VALIDATION.md; val109=.planning/phases/109-security-activity-and-session-history-truth/109-VALIDATION.md; if rg -q "^status: passed$" "$v108"; then rg -n "^status: (complete|passed|verified)$|^wave_0_complete: true$" "$val108"; else rg -n "^status: (planned|partial|blocked|failed|in_progress)" "$val108"; fi; if rg -q "^status: passed$" "$v109"; then rg -n "^status: (complete|passed|verified)$|^wave_0_complete: true$" "$val109"; else rg -n "^status: (planned|partial|blocked|failed|in_progress)" "$val109"; fi; rg -n "108-VERIFICATION|109-VERIFICATION" "$val108" "$val109"'` | ✅ existing files | ⬜ pending |
| 110-03-02 | 03 | 3 | SESS-02 / SESS-03 / SESS-04 / SESS-05 | active v1.24 planning files and live audit tell one coherent implementation-vs-closeout story and remove stale pre-planning wording | integration | `bash -lc 'set -euo pipefail; test -f .planning/v1.24-MILESTONE-AUDIT.md; rg -n "SESS-02|SESS-03|SESS-04|SESS-05|108-VERIFICATION|109-VERIFICATION|Phase 110" .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.24-MILESTONE-AUDIT.md; ! rg -n "plan Phase 108|Phase 108 planning is next|break the live requirements into phases starting at Phase 108" .planning/ROADMAP.md .planning/STATE.md'` | ✅ active files + ❌ new audit file | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Phase 110 should be fully automatable; this slice is proof and planning-truth closeout, not human-witness UI polish. | — |

---

## Validation Sign-Off

- [x] All plans have concrete automated verify commands
- [x] Example-app verification commands use the nested `test/example` execution path where applicable
- [x] Sampling continuity: no wave ends without an automated gate
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved for execution
