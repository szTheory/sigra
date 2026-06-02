---
phase: 30
slug: audit-exploration-and-export
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix LiveViewTest + Playwright |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/admin/users_actions_test.exs test/sigra/admin/audit/query_test.exs --max-failures 1 && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example_web/live/admin_audit_index_live_test.exs test/example_web/live/admin_audit_user_live_test.exs test/example_web/controllers/admin/audit_export_controller_test.exs --max-failures 1` |
| **Browser smoke command** | `cd test/example && pnpm exec playwright test priv/playwright/tests/admin-audit.spec.ts --project=chromium` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && pnpm exec playwright test priv/playwright/tests/admin-audit.spec.ts --project=chromium` |
| **Estimated runtime** | ~20-40s targeted library/example slices, ~60-120s browser smoke, ~180-300s full combined gate |

---

## Sampling Rate

- **After every task commit:** Run the targeted command listed for that task row.
- **After every plan wave:** Run the full suite command for root, example app, and the Phase 30 Playwright spec.
- **Before `/gsd-verify-work`:** All targeted rows green, then the full suite command green.
- **Max feedback latency:** Keep task-level checks under ~40 seconds where possible; reserve the browser check for plan-wave gates or browser-touching tasks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | AUD-01, AUD-02 | T-30-01, T-30-02 | Admin support actions preserve canonical actor/effective-user/target attribution and query params fail closed | unit | `mix test test/sigra/admin/users_actions_test.exs test/sigra/admin/audit/query_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-01-02 | 01 | 1 | AUD-01, AUD-02 | T-30-01, T-30-02, T-30-03 | Shared admin audit query and query-param modules hold one normalized contract for explorer and export | unit | `mix test test/sigra/admin/users_actions_test.exs test/sigra/admin/audit/query_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-02-01 | 02 | 2 | AUD-02, AUD-03 | T-30-04, T-30-05 | Global and org explorer routes keep filters in the URL and label impersonation from canonical fields | liveview/component | `cd test/example && mix test test/example_web/live/admin_audit_index_live_test.exs test/example_web/admin_shell_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-02-02 | 02 | 2 | AUD-02, AUD-03 | T-30-04, T-30-05, T-30-06 | Generated/example route and shell wiring stays scope-safe and navigable | liveview/component | `cd test/example && mix test test/example_web/live/admin_audit_index_live_test.exs test/example_web/admin_shell_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-03-01 | 03 | 3 | AUD-02, AUD-03 | T-30-07, T-30-08 | Per-user explorer and preview alignment include `effective_user_id` rows and preserve return context | liveview | `cd test/example && mix test test/example_web/live/admin_audit_user_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-03-02 | 03 | 3 | AUD-02, AUD-03 | T-30-07, T-30-08, T-30-09 | Org-scoped per-user explorer intentionally includes the same user's global support rows while org-wide explorers stay org-only | liveview | `cd test/example && mix test test/example_web/live/admin_audit_user_live_test.exs test/example_web/live/admin_user_show_live_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-04-01 | 04 | 4 | AUD-04, AUD-02 | T-30-10, T-30-11, T-30-13 | Export controller keeps the same filter contract, scope, fixed metadata-free CSV schema, and formula-injection mitigation as the UI contract expects | controller | `cd test/example && mix test test/example_web/controllers/admin/audit_export_controller_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |
| 30-04-02 | 04 | 4 | AUD-04, AUD-02, AUD-03 | T-30-10, T-30-11, T-30-12, T-30-13 | Browser flow proves audit filtering, impersonation labeling, and CSV export work together in the operator path | browser | `cd test/example && pnpm exec playwright test priv/playwright/tests/admin-audit.spec.ts --project=chromium` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/admin/users_actions_test.exs` — admin support-action attribution coverage for AUD-01.
- [ ] `test/sigra/admin/audit/query_test.exs` — normalized audit query/filter/cursor contract for AUD-01 and AUD-02.
- [ ] `test/example/test/example_web/live/admin_audit_index_live_test.exs` — global and org explorer route/filter/nav coverage for AUD-02 and AUD-03.
- [ ] `test/example/test/example_web/live/admin_audit_user_live_test.exs` — per-user global/org explorer and preview alignment coverage for AUD-02 and AUD-03.
- [ ] `test/example/test/example_web/live/admin_user_show_live_test.exs` — user detail pivot into full audit plus preview alignment coverage.
- [ ] `test/example/test/example_web/controllers/admin/audit_export_controller_test.exs` — CSV scope, header order, metadata exclusion, dangerous-prefix escaping, and filter parity coverage for AUD-04.
- [ ] `test/example/priv/playwright/tests/admin-audit.spec.ts` — browser-visible investigation and export smoke for Phase 30.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CSV evidence readability for a real operator | AUD-04 | Automated checks can prove schema and download behavior, but a quick human read is still useful to confirm the fixed columns are understandable without raw metadata | Run the example app, filter the audit explorer to one representative impersonation slice, export CSV, and confirm the column set is readable without opening JSON blobs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency stays within the targeted slice budget
- [ ] `nyquist_compliant: true` set in frontmatter before execution closes

**Approval:** pending
