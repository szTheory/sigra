---
phase: 190
slug: flows-fixture-data-l4
status: planned
nyquist_compliant: false
wave_0_complete: false
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

> Populated by the planner. Each FLOW/DATA requirement is verified by deterministic Playwright behavior assertions and seed reproducibility — no manual UAT (zero-human UAT doctrine).

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-T1 | 190-01 | 1 | FLOW-02 | T-190-01, T-190-02, T-190-03 | WR-01: [data-sg-confirm-cancel] selector; WR-02: body sentinel focus fallback; WR-03: Escape stopImmediatePropagation; byte-parity both hooks | e2e + bash | `md5sum priv/templates/sigra.install/admin/admin_hooks.js test/example/assets/js/admin_hooks.js \| awk '{print $1}' \| sort -u \| wc -l` returns 1; `npx playwright test admin-modal-interaction --project=chromium` | ❌ W0 | ⬜ pending |
| 01-T2 | 190-01 | 1 | FLOW-01 | T-190-01 | WR-04: branding_live error_message/1 maps Ecto.Changeset to human copy; no inspect/1 leak | unit | `mix test test/sigra/admin/live/branding_live_test.exs` | ❌ W0 | ⬜ pending |
| 02-T1 | 190-02 | 1 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-05 | ADMIN_BEHAVIOR_SPECS regex excludes admin-flow-* from mobile project; chromium-only lane | config | `cd test/example/priv/playwright && npx playwright test --list --project=mobile 2>&1 \| grep -c admin-flow \| grep "^0$"` | ❌ W0 | ⬜ pending |
| 02-T2 | 190-02 | 1 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-04 | Shared helpers export 6+ functions; loginDemoUser + waitForLiveViewReady canonical; no sleeps, no per-page emulateMedia | static | `cd test/example/priv/playwright && npx tsc --noEmit helpers/adminFlows.ts` | ❌ W0 | ⬜ pending |
| 03-T1 | 190-03 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-07, T-190-08, T-190-09 | Platform admin JTBD: happy (alice) + main-error (dave locked) + boundary (frank + empty filter); keyboard APG; reducedMotion at context level; theme across nav + reload + system | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-platform-admin --project=chromium` | ❌ W0 | ⬜ pending |
| 04-T1 | 190-04 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-07 | Investigator: find→audit→impersonate alice→banner persistent→stop→return to /admin/users?q=; no impersonation internals re-tested; theme across journey + reload | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-support-investigator --project=chromium` | ❌ W0 | ⬜ pending |
| 04-T2 | 190-04 | 2 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-10, T-190-11, T-190-12 | Org admin: tenant-bounded 200 /admin/organizations/acme-corp; 403 /admin with anti-enumeration body; morgan empty audit .sg-empty-state; theme + reload | e2e | `cd test/example/priv/playwright && npx playwright test admin-flow-org-admin --project=chromium` | ❌ W0 | ⬜ pending |
| 05-T1 | 190-05 | 3 | FLOW-01, FLOW-02, FLOW-03, DATA-01 | T-190-14, T-190-15 | 3 L4 ledger rows appended; quality-ledger-monotonic.sh parses rows without error; tier is bare integer 1 | bash | `bash scripts/ci/quality-ledger-monotonic.sh` | ✅ existing | ⬜ pending |
| 05-T2 | 190-05 | 3 | DATA-01 | T-190-16 | mix run priv/repo/seeds.exs idempotent; morgan has 0 audit events (natural boundary); no enrichment added | integration | `mix run priv/repo/seeds.exs` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/priv/playwright/helpers/adminFlows.ts` — shared login / navigation / theme / keyboard / LiveView-readiness utilities for the flow specs (Plan 02 Task 2)
- [ ] `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` — FLOW-01/02/03 + DATA-01 for platform-admin journey (Plan 03)
- [ ] `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` — investigator-posture journey (Plan 04 Task 1)
- [ ] `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` — tenant-bounded journey + permission-denied + empty-audit boundary (Plan 04 Task 2)
- [ ] `ADMIN_BEHAVIOR_SPECS` regex update in `playwright.config.ts` so `admin-flow-*` runs on chromium only — Plan 02 Task 1 (RESEARCH confirmed blocking gap)
- [ ] WR-01/02/03 `admin_hooks.js` hardening (both mirrors byte-identical) — Plan 01 Task 1
- [ ] `data-sg-confirm-cancel` attribute on cancel buttons in `user_show_live.ex` + `branding_live.ex` — Plan 01 Task 1
- [ ] WR-04 `branding_live.ex` `error_message/1` Ecto.Changeset clause — Plan 01 Task 2

*Existing seed fixture (`Example.Demo.Seeds.run/0`) covers the data cases — no enrichment needed per RESEARCH (morgan's zero audit events is the natural empty/no-data boundary).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| — | — | — | — |

*All phase behaviors have automated verification (zero-human UAT).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending (to be set after Plan 05 Task 2 completes)
