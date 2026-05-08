# Phase 110: Session control plane verification closeout - Research

## Summary

Phase 110 should be planned as a repaired-form verification closeout for the completed v1.24 session-control slices, not as more product work. Phase 108 and Phase 109 together already cover `SESS-02..05`, but neither phase has an authoritative `VERIFICATION.md`, both validation files still read as pending/planned, and the active planning files still describe `SESS-CTRL` as an undecomposed live milestone. The repo already has a strong closeout pattern from Phases 106 and 107: write one authoritative verification artifact per implemented phase, rerun a bounded current-head proof lane, then reconcile only the active truth set. Phase 110 should reuse that exact pattern for 108/109.

## Key Findings

- **D-110-01 — This is a proof gap, not a feature gap.** `108-01..03-SUMMARY.md` and `109-01..03-SUMMARY.md` show the work is shipped; the missing piece is authoritative verification plus active-truth reconciliation. [VERIFIED: `.planning/phases/108-revoke-other-sessions-and-session-truth/*SUMMARY.md`] [VERIFIED: `.planning/phases/109-security-activity-and-session-history-truth/*SUMMARY.md`]
- **D-110-02 — Phase 108's old example-app blocker should be treated as stale until rerun.** The summaries record a replay-migration failure in `20260507220000_add_webhook_replay_fields`, but current repo state now uses `add_if_not_exists` and additional `IF NOT EXISTS` helper SQL in `test/example`, so Phase 110 should re-run the focused example suites instead of carrying forward the old red state blindly. [VERIFIED: `.planning/phases/108-revoke-other-sessions-and-session-truth/108-02-SUMMARY.md`] [VERIFIED: `.planning/phases/108-revoke-other-sessions-and-session-truth/108-03-SUMMARY.md`] [VERIFIED: `test/example/priv/repo/migrations/20260507220000_add_webhook_replay_fields.exs`] [VERIFIED: `test/example/test/support/webhook_admin_live_fixtures.ex`]
- **D-110-03 — The repo already has the exact closeout precedent needed.** Phase 106 wrote a missing `104-VERIFICATION.md` then reconciled active truth; Phase 107 did the same for `105-VERIFICATION.md` plus validation truth. [VERIFIED: `.planning/phases/106-replay-verification-closeout/106-01-PLAN.md`] [VERIFIED: `.planning/phases/106-replay-verification-closeout/106-02-PLAN.md`] [VERIFIED: `.planning/phases/107-webhook-policy-operator-truth/107-03-PLAN.md`]
- **D-110-04 — Active v1.24 truth is still stale.** `REQUIREMENTS.md` still lists `SESS-02..05` as unchecked, `STATE.md` still talks like Phase 108 planning is next, and `ROADMAP.md` still says the next planning step is to break `SESS-CTRL` into phases starting at 108. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/STATE.md`] [VERIFIED: `.planning/ROADMAP.md`]
- **D-110-05 — The right decomposition is two verification plans plus one reconciliation plan.** One plan should close 108, one should close 109, and a third should update `108/109-VALIDATION.md` plus the active v1.24 truth set and live audit. [VERIFIED: repo synthesis from 106/107 pattern]

## Requirement Coverage

| Req | Current Implemented State | Remaining Closeout Need |
|---|---|---|
| `SESS-02` | Implemented in Phase 108 library and generated-host flows. [VERIFIED: `108-01/02-SUMMARY.md`] | `108-VERIFICATION.md` plus validation reconciliation. |
| `SESS-03` | Implemented in Phase 109 library, generated-host, admin, and docs work. [VERIFIED: `109-01/02/03-SUMMARY.md`] | `109-VERIFICATION.md` plus validation reconciliation. |
| `SESS-04` | Split across 108 and 109; current-session truth and present-state alignment are already in delivered summaries. [VERIFIED: `108-02/03-SUMMARY.md`] [VERIFIED: `109-02/03-SUMMARY.md`] | Closeout wording must keep the split explicit instead of attributing all of `SESS-04` to one phase. |
| `SESS-05` | Thin-host/library-owned seams already landed across both phases. [VERIFIED: `108-01/02/03-SUMMARY.md`] [VERIFIED: `109-01/02/03-SUMMARY.md`] | Verification and active truth must preserve the implementation-vs-closeout story. |

## Recommended Plan Shape

### Plan 110-01

Write `108-VERIFICATION.md` from the shipped 108 summary chain and a fresh focused rerun of the Phase 108 validation lane. The rerun must explicitly settle the old example-app migration blocker on current HEAD instead of quoting the stale blocked result from the summary.

### Plan 110-02

Write `109-VERIFICATION.md` from the shipped 109 summary chain and a fresh focused rerun of the Phase 109 validation lane. This plan should stay bounded to recent security activity, admin alignment, and docs truth; it should not widen into new activity features.

### Plan 110-03

Update `108-VALIDATION.md` and `109-VALIDATION.md` to completed/verified truth once the new proof artifacts exist, then reconcile only the active v1.24 truth files and create `v1.24-MILESTONE-AUDIT.md` if missing.

## Focused Verification Commands

### Phase 108

- `MIX_ENV=test mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/templates/session_templates_test.exs --no-color`
- `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/user_auth_test.exs\",\"--no-color\"])"`  
- `rg -n "other sessions|revoke all|except the current session|current session" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md`

### Phase 109

- `MIX_ENV=test mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/sigra/security_activity_test.exs test/sigra/templates/session_templates_test.exs --no-color`
- `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix run -e "Mix.Tasks.Test.run([\"test/example_web/live/auth/session_live_test.exs\",\"test/example_web/live/admin_user_show_live_test.exs\",\"test/example_web/live/admin_audit_user_live_test.exs\",\"--no-color\"])"`  
- `rg -n "logout|revoke other|revoke all|security activity|timeout" guides/flows/login-and-logout.md guides/flows/account-lifecycle.md guides/flows/audit-logging.md`

## Risk Notes

- The biggest closeout risk is overstating status in active truth files before the reruns prove current HEAD still matches the shipped summaries.
- The second risk is collapsing 108/109 history into one vague v1.24 claim; the verification artifacts and active truth should preserve which phase implemented what.
- The phase should not expand into milestone archive cleanup unless the active truth set genuinely depends on it.

## Recommendation

Plan Phase 110 as a three-plan repaired-form closeout:

1. verify and write `108-VERIFICATION.md`
2. verify and write `109-VERIFICATION.md`
3. reconcile `108/109-VALIDATION.md` plus the active v1.24 truth set and live milestone audit

That is the lowest-risk way to turn the already-shipped session-control work into milestone-authoritative proof without reopening scope.
