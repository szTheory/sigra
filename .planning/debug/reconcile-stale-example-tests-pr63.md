---
status: awaiting_human_verify
trigger: "reconcile 6 failing example-app tests blocking PR #63 v1.42 integration merge - stale 209 admin UI copy/IA drift vs real bugs"
created: 2026-07-02T00:00:00Z
updated: 2026-07-02T00:00:00Z
---

## Current Focus

hypothesis: 5/6 STALE (fixed); #5 (morgan 403) is a design-intent divergence flagged for human decision
test: Done — each classified by library-source comparison + git provenance
expecting: 5 reconciled; #5 needs a human ruling (403 library-default contract vs example-app redirect-to-/app UX)
next_action: AWAIT human decision on #5. Commits: e263e514 #1, d0ea0c8e #2, ac3c8d69 #3+#4, 44e049fa #6

## Symptoms

expected: All 6 example-app tests pass (they were GREEN on old ship 208.1)
actual: 6 tests fail on full v1.42 backlog PR #63 (CI run 28608594941)
errors: |
  1. admin_shell_test.exs:13 - assert id="overview-metric-total-users" (line 55)
  2. admin-user-operations.spec.ts:73 - revoke-session confirm prompt not visible
  3. admin-flow-platform-admin.spec.ts:148 - user detail audit code.sg-code hidden
  4. admin-flow-platform-admin.spec.ts:248 - keyboard Tab->revoke->Enter dialog, trigger not found
  5. admin-flow-org-admin.spec.ts:154 - morgan /admin 403 generic copy non-disclosure
  6. admin-flow-org-admin.spec.ts:212 - org audit empty-state date filter, date input not found
reproduction: PR/ship CI Example unit smoke + Example Playwright smoke admin_behavior step
started: Phase 209 admin UI copy/IA polish; tests never reconciled

## Eliminated

## Evidence

- timestamp: 2026-07-02
  checked: lib/sigra/admin/live/index_live.ex:82-102 render + git show f5d8fb84
  found: Commit f5d8fb84 "fix(209-03)" intentionally removed the duplicated total-users chip (overview-metric-total-users). Current render has only overview-metric-new-users + overview-metric-active-users. Reproduced ExUnit failure at line 55.
  implication: Test #1 lines 55-56 are STALE. Reconcile by removing them. Users-List strip is the single owner of total-users per commit message. FIXED + verified ExUnit passes.

- timestamp: 2026-07-02
  checked: lib/sigra/admin/live/user_sessions_live.ex:204-210 + git show 869f1997
  found: Commit 869f1997 "fix(209-04)" intentionally rewrote revoke_session_copy/1 to remove "They can sign in again." reassurance and add security-remediation framing. New copy: "The user will be signed out of this session immediately. If this session was compromised, they must sign in again with verified credentials to re-establish access." Spec admin-user-operations.spec.ts:133-135 asserts OLD copy.
  implication: Test #2 STALE. Reconcile confirmPrompt string to new copy. FIXED.

- timestamp: 2026-07-02
  checked: lib/sigra/admin/components.ex audit_table_row/1 (755-791) + audit_row/1 (702-717) + audit_user_live.ex (174-202) + git show 3fe5e584
  found: Phase 202-01 (commit 3fe5e584, in v1.42 backlog) moved the raw action code.sg-code into a native collapsed <details>"Event codes" disclosure inside the desktop table Event <td> (line 773). Pre-202 it was directly visible (line 206 of old file). The mobile copy (audit_row show_codes, line 714) lives in a sg-show-mobile container (display:none on desktop chromium viewport). So on desktop both action code.sg-code nodes are non-visible: one collapsed in <details>, one in mobile-hidden container.
  implication: Test #3 (platform-admin:186-187) STALE — asserts raw code visible, but Phase 202 hid it behind a <details> disclosure. Reconcile: expand the "Event codes" disclosure before asserting, OR assert against the visible action_label pill. Choose expand-details to preserve intent (verify raw forensic codes present). This is copy/IA drift, NOT a runtime bug. FIXED.

- timestamp: 2026-07-02
  checked: lib/sigra/admin/live/user_show_live.ex (only "Manage sessions" link @83, NO revoke trigger) vs user_sessions_live.ex (Revoke all sessions @121, Revoke session @152, #user-session-confirm-overlay @167). Cross-ref test #2 comment lines 115-118 (Phase 200/D-04 moved revoke off detail page onto UserSessionsLive at /admin/users/:id/sessions).
  found: Test #4 (platform-admin:248 keyboard) navigates only to /admin/users/:id (detail page) and expects "Revoke all sessions"/"Revoke session" trigger there — but Phase 200 moved that flow to the /sessions sub-page. Detail page is now read-only identity surface. The test's own overlay selector #user-session-confirm-overlay (line 312) is defined ONLY on user_sessions_live.ex, confirming intent was to test the sessions-page dialog. Test omits the "Manage sessions" link-out navigation.
  implication: Test #4 STALE — FLOW-01 spec written against pre-200 detail-page layout. Reconcile: click "Manage sessions" to reach /admin/users/:id/sessions before locating the revoke trigger. Copy/IA drift, NOT a runtime bug. FIXED.

- timestamp: 2026-07-02
  checked: test/example/lib/example_web/auth_error_handler.ex:41-62 (insufficient_scope) vs lib/sigra/install/features/admin.ex:115-144 (library generated default) + git log (only ceba947a rebrand touched the example file, NOT Phase 209)
  found: Test #5 (org-admin:154) asserts morgan hitting /admin => HTTP 403 + body "Access denied. You do not have access to this admin scope." The COPY is correct/unchanged (matches library default + example line 59). BUT the example app's insufficient_scope handler was HAND-CUSTOMIZED (lines 47-61) to branch: if current_scope.user is present (authenticated) => redirect to /app (302), else => hard 403. Morgan is AUTHENTICATED (org-scoped), so morgan gets a 302 redirect to /app, NOT 403. The LIBRARY GENERATED DEFAULT (admin.ex:122-130) is an UNCONDITIONAL hard 403 — the spec matches the library default; the example diverged. This divergence predates Phase 209 (comment at :43-46 frames it as intentional demo UX "shouldn't dead-end on a raw 403 — send them home"). The security property (no org/email disclosure) HOLDS under both branches — a redirect to /app also discloses neither org nor email.
  implication: Test #5 is AMBIGUOUS — NOT a stale-copy fix and NOT clearly a runtime bug. The 403-vs-redirect is a UX-contract mismatch between the spec's D-04/D-13 intent (hard 403) and the example app's intentional authenticated-user redirect. Reconciling the test to accept the redirect would silently DROP the 403 security-contract the spec exists to prove. FLAG for human decision: either (a) the example app should match the library default (unconditional 403) — a code fix, or (b) the spec's 403 assertion is intentionally relaxed to accept the redirect-to-/app UX while KEEPING the non-disclosure refutes. Do NOT fix-to-pass. See separate flagged report.

- timestamp: 2026-07-02
  checked: lib/sigra/admin/live/audit_index_live.ex:83-130 + git show e664e7f1
  found: Test #6 (org-admin:212) fills input[name="from"]/[name="to"] then clicks "Apply filters". All these selectors + the empty-state title "No audit events match this view" EXIST and match (lines 122/127/133/182). BUT Phase 202-03 (commit e664e7f1, in v1.42 backlog) wrapped the from/to date inputs inside a collapsed <details><summary>More filters</summary> disclosure (line 83-84). page.fill() on a hidden input (collapsed details) times out waiting for actionability. Pre-202 the filter form was flat.
  implication: Test #6 STALE — must expand the "More filters" disclosure before filling the date inputs. Copy/IA drift, NOT a runtime bug.

## Resolution

root_cause: |
  5 of 6 failures are STALE example-app test assertions written against pre-v1.42 admin UI. Phase 202/209 (backlog) intentionally changed the library admin LiveViews; the FLOW-01 specs (newly wired in 212-02) + 2 pre-existing specs assert the old copy/structure. #5 is NOT stale copy: it surfaces a pre-existing example-app divergence from the library default 403 handler (authenticated users are redirected to /app instead of 403), which conflicts with the spec's D-04/D-13 403 contract — a design-intent question, not a Phase-209 regression.
fix: |
  #1 admin_shell_test.exs — removed stale total-users chip assertions (assert->refute), matching f5d8fb84 dedup.
  #2 admin-user-operations.spec.ts — updated revoke confirm copy to security-remediation framing (869f1997).
  #3 admin-flow-platform-admin.spec.ts — expand each "Event codes" <details> before asserting raw action codes (hidden by 3fe5e584/202-01).
  #4 admin-flow-platform-admin.spec.ts — navigate via "Manage sessions" to /sessions sub-page before locating revoke trigger (moved off detail page by Phase 200/D-04).
  #6 admin-flow-org-admin.spec.ts — expand "More filters" <details> before filling from/to date inputs (hidden by e664e7f1/202-03).
  #5 admin-flow-org-admin.spec.ts — NOT modified. Flagged for human decision (403-contract vs redirect-UX).
verification: |
  #1: ExUnit repro before/after — full admin_shell_test.exs 14 tests pass.
  #2,#3,#4,#6: verified by direct library-source comparison + git provenance of the exact 202/209 commits + `playwright test --list` confirms all 3 specs parse cleanly. App not booted (compile-time PORT gotcha; code-inspection sufficient for copy/IA drift per task).
  #5: proven from source (example auth_error_handler.ex redirect branch vs library default 403) — booting cannot resolve the intent question.
files_changed:
  - test/example/test/example_web/admin_shell_test.exs
  - test/example/priv/playwright/tests/admin-user-operations.spec.ts
  - test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts
  - test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts
