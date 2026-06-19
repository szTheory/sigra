---
phase: 190
slug: flows-fixture-data-l4
status: ratified
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-17
---

# Phase 190 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Playwright (chromium behavior lane) + ExUnit (seed/Elixir) |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example/priv/playwright && npx playwright test --project=chromium admin-flow-<persona>` |
| **Full suite command** | `cd test/example/priv/playwright && npx playwright test --project=chromium` (behavior lane) + `mix test` (seed/Elixir) |
| **Estimated runtime** | ~60–120 seconds (chromium behavior lane) |

---

## Sampling Rate

- **After every task commit:** Run the per-persona flow spec just authored (`--project=chromium admin-flow-<persona>`)
- **After every plan wave:** Run the full chromium behavior lane + the example admin/seed ExUnit tests
- **Before `/gsd:verify-work`:** Full chromium behavior lane green + `mix run priv/repo/seeds.exs` reproduces all three cases per flow
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

> Populated by Plan 05 Task 2 (190-05). Each FLOW/DATA requirement is verified by deterministic Playwright behavior assertions and seed reproducibility — no manual UAT (zero-human UAT doctrine).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 | 190-01 | 1 | FLOW-02 | T-190-01, T-190-02, T-190-03 | WR-01: [data-sg-confirm-cancel] selector; WR-02: body sentinel focus fallback; WR-03: Escape stopImmediatePropagation; byte-parity both hooks | e2e + bash | `md5sum priv/templates/sigra.install/admin/admin_hooks.js test/example/assets/js/admin_hooks.js \| awk '{print $1}' \| sort -u \| wc -l` returns 1 (commit 4217a702); `npx playwright test admin-modal-interaction --project=chromium` | ✅ shipped | ✅ green |
| 01-T2 | 190-01 | 1 | FLOW-01 | T-190-01 | WR-04: branding_live error_message/1 maps Ecto.Changeset to human copy via traverse_errors/2; no inspect/1 leak | unit | `mix test test/sigra/admin/live/branding_live_test.exs` — 11 tests, 0 failures (commit adc54cac) | ✅ shipped | ✅ green |
| 02-T1 | 190-02 | 1 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-05 | ADMIN_BEHAVIOR_SPECS regex `/(admin-user-operations\|admin-audit\|admin-theme\|impersonation\|admin-flow-).*\.spec\.ts/` excludes admin-flow-* from mobile project; chromium-only lane | config | `cd test/example/priv/playwright && npx playwright test --list --project=mobile 2>&1 \| grep -c admin-flow \| grep "^0$"` — confirmed 0 (commit 447f0d48, regex fixed again in 4ffcf22a) | ✅ shipped | ✅ green |
| 02-T2 | 190-02 | 1 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-04 | Shared helpers: 12 exports (4 constants + 8 functions); loginDemoUser + waitForLiveViewReady canonical; no sleeps, no per-page emulateMedia after goto | static | `grep -c 'export' test/example/priv/playwright/helpers/adminFlows.ts` returns 12 (commit 792127e0); esbuild-validated at first `npx playwright test` run | ✅ shipped | ✅ green |
| 03-T1 | 190-03 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-07, T-190-08, T-190-09 | Platform admin JTBD: happy (alice) + main-error (dave locked) + boundary (frank + empty filter); keyboard APG; reducedMotion at context level; theme across nav + reload + system | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-platform-admin --project=chromium` — 6 tests, 0 failed (commit 4ffcf22a) | ✅ shipped | ✅ green |
| 04-T1 | 190-04 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-07 | Investigator: find→audit→impersonate alice→banner persistent→stop→return to /admin/users?q=; no impersonation internals re-tested; theme across journey + reload; 5 tests | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-support-investigator --project=chromium` — 5 tests, 0 failed (commit 1d547ece) | ✅ shipped | ✅ green |
| 04-T2 | 190-04 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-10, T-190-11, T-190-12 | Org admin: tenant-bounded 200 /admin/organizations/acme-corp; 403 /admin with anti-enumeration body (no email/org in error); date-range filter 2020 yields .sg-empty-state "No audit events match this view"; theme + reload | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-org-admin --project=chromium` — 5 tests, 0 failed (commit dea4e480) | ✅ shipped | ✅ green |
| 05-T1 | 190-05 | 3 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-14, T-190-15 | 3 L4 ledger rows appended (flow-platform-admin, flow-support-investigator, flow-org-admin); quality-ledger-monotonic.sh PASS (34 cells, 0 violations); tier is bare integer 1 in column 4 | bash | `bash scripts/ci/quality-ledger-monotonic.sh` — PASS 34 cells checked vs HEAD (commit d8dfbbb4) | ✅ shipped | ✅ green |
| 05-T2 | 190-05 | 3 | DATA-01 | T-190-16 | `mix run priv/repo/seeds.exs` exits 0; idempotent ON CONFLICT DO NOTHING upserts throughout; morgan has 0 audit events (natural boundary — session.create events from test runs are excluded by date-range filter in flow spec); no enrichment added | integration | `cd test/example && mix run priv/repo/seeds.exs` — exits 0, all upserts succeed, audit count threshold guard no-ops when rows already present | ✅ shipped | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/example/priv/playwright/helpers/adminFlows.ts` — shared login / navigation / theme / keyboard / LiveView-readiness utilities for the flow specs (Plan 02 Task 2) — commit 792127e0
- [x] `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` — FLOW-01/02/03 + DATA-01 for platform-admin journey (Plan 03) — commit 4ffcf22a
- [x] `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` — investigator-posture journey (Plan 04 Task 1) — commit 1d547ece
- [x] `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` — tenant-bounded journey + permission-denied + empty-audit boundary (Plan 04 Task 2) — commit dea4e480
- [x] `ADMIN_BEHAVIOR_SPECS` regex updated in `playwright.config.ts` to `admin-flow-.*` so `admin-flow-*.spec.ts` runs on chromium only — Plan 02 Task 1 + Plan 03 deviation fix (commits 447f0d48, 4ffcf22a)
- [x] WR-01/02/03 `admin_hooks.js` hardening (both mirrors byte-identical, MD5 `b80ebb47e1c9ac9ccba07361514fafdf`) — Plan 01 Task 1 — commit 4217a702
- [x] `data-sg-confirm-cancel` attribute on cancel buttons in `user_show_live.ex` + `branding_live.ex` — Plan 01 Task 1 — commit 4217a702
- [x] WR-04 `branding_live.ex` `error_message/1` Ecto.Changeset clause with traverse_errors/2 — Plan 01 Task 2 — commit adc54cac

*Existing seed fixture (`Example.Demo.Seeds.run/0`) covers the data cases — no enrichment needed per RESEARCH (morgan's zero audit events is the natural empty/no-data boundary). Verified: `mix run priv/repo/seeds.exs` exits 0 idempotently.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

*All phase behaviors have automated verification (zero-human UAT).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — all 8 items complete
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** RATIFIED — Plan 05 Task 2 complete (2026-06-17). All FLOW-01/02/03 and DATA-01 requirements satisfied. Per-task verification map fully populated with no TBD cells. Seed exits 0 idempotently. Quality ledger has 3 L4 rows at Tier 1 passing monotonic guard. All 3 flow specs pass on chromium (16 tests total, 0 failures).
