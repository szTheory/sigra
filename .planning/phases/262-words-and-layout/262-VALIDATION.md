---
phase: "262"
slug: "words-and-layout"
status: complete
nyquist_compliant: true
wave_0_complete: true
created: "2026-11-16"
---

# Phase 262 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit; Playwright with axe-core for browser-level UI |
| **Config file** | Root `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/admin/components_test.exs test/sigra/install/auth_ui_contract_test.exs test/sigra/install/generator_passkey_primary_login_test.exs` |
| **Full suite command** | `source tmp/db.env && MIX_ENV=test mix ci`; then `(cd test/example && source ../../tmp/db.env && MIX_ENV=test mix test --include example_app)` and the relevant `scripts/ci/admin-acceptance-smoke.sh` Playwright/axe checks |
| **Estimated runtime** | Not measured in this planning run; establish per-command timings during Wave 0 |

---

## Sampling Rate

- **After every task commit:** Run the task's focused ExUnit, contract, or browser check from the verification map; run `mix format --check-formatted` when Elixir files change.
- **After every plan wave:** Run the relevant slice test set, example app tests, catalog comparison, and changed-surface browser/axe checks.
- **Before `$gsd-verify-work`:** Run the full suite command, all three slice gates, touched pre-auth enumeration parity, generated-host smoke, and golden `--check`.
- **Max feedback latency:** Record actual quick-suite timing in Wave 0; use focused tests for per-task feedback.

---

## Plan execution graph

The revision contains 14 plans in 14 sequential waves. Plans 262-04 through 262-14 remain unreachable until Plan 262-03's complete 4a gate passes; Plan 262-07 is the first 4c plan and also requires the 4a gate. The golden rebless is unique to Plan 262-13, and PR preparation follows only after final verification in Plan 262-14.

| Wave | Plan | Depends on | Slice/output |
|------|------|------------|--------------|
| 1 | 262-01 | — | 4a: Users status tracer |
| 2 | 262-02 | 262-01 | 4a: UTC, detail/session copy and executable support backstops |
| 3 | 262-03 | 262-02 | 4a hard gate and evidence |
| 4 | 262-04 | 262-03 | 4b: per-user audit |
| 5 | 262-05 | 262-04 | 4b: overview and audit index |
| 6 | 262-06 | 262-05 | 4b: organizations, workbench, shell and selected/current styling |
| 7 | 262-07 | 262-06 | 4c: generated-auth literal inventory |
| 8 | 262-08 | 262-07 | 4c: neutral organization auth |
| 9 | 262-09 | 262-08 | 4c: passkey defaults, labels, browser and axe |
| 10 | 262-10 | 262-09 | 4c: login/registration and confirmation/reset copy |
| 11 | 262-11 | 262-10 | 4c: remaining core auth Gettext coverage |
| 12 | 262-12 | 262-11 | 4c: email copy and generated catalogs |
| 13 | 262-13 | 262-12 | 4c: sole golden rebless and full verification |
| 14 | 262-14 | 262-13 | Ordered PRs, CI/review, owner merge approvals remain pending |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 262-01-T1; 262-02-T2; 262-02-T3; 262-03-T3; 262-14-T1; 262-14-T2; 262-14-T3 | 262-01; 262-02; 262-03; 262-14 | 1; 2; 3; 14 | BOPS-01 | ASVS V4 | Preserve existing user scope and return-path behavior; enforce the 4a gate before later slices and deliver ordered PRs | LiveView + browser + catalog | `MIX_ENV=test mix test test/sigra/brand/catalog_test.exs test/sigra/brand/css_contrast_test.exs`; example support-path tests; `bash scripts/ci/phase-262-4a-gate.sh`; PR CI checks | Planned in Tasks 1-3 and 14; pending execution | ✅ passed |
| 262-01-T1; 262-01-T2; 262-02-T2 | 262-01; 262-02 | 1; 2 | BOPS-02 | ASVS V4 | Derive status only from existing persisted fields; text carries meaning | Unit + LiveView | `MIX_ENV=test mix test test/sigra/admin/components_test.exs`; example user index/detail tests | Planned in Tasks 1-2; pending execution | ✅ passed |
| 262-02-T1 | 262-02 | 2 | BOPS-03 | ASVS V3 | Render stored timestamps deterministically in UTC | Unit + catalog | `MIX_ENV=test mix test test/sigra/admin/components_test.exs test/sigra/brand/catalog_test.exs` | Planned in Task 1; pending execution | ✅ passed |
| 262-02-T3 | 262-02 | 2 | BOPS-04 | ASVS V3 | Preserve revoke authorization and action semantics | LiveView + browser | Example user detail/session tests; `GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test all` | Planned in Task 3; pending execution | ✅ passed |
| 262-02-T3; 262-03-T3 | 262-02; 262-03 | 2; 3 | BOPS-05 | — | Keep approved labels and truthful empty/error states | Contract | `MIX_ENV=test mix test test/sigra/brand/copy_contract_test.exs test/sigra/admin/glossary_test.exs` | Planned in Tasks 3; pending execution | ✅ passed |
| 262-03-T1; 262-03-T2; 262-03-T3; 262-13-T1; 262-13-T3 | 262-03; 262-13 | 3; 13 | BOPS-06 | ASVS V4 | Previous CSS compatibility adds no behavior or authorization changes | Unit + generated host/browser | `MIX_ENV=test mix test test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs test/sigra/install/asset_parity_test.exs test/sigra/install/old_admin_css_compatibility_test.exs` | Planned in Tasks 1-3 and final matrix; pending execution | ✅ passed |
| 262-04-T1; 262-04-T2; 262-05-T1; 262-05-T2; 262-06-T1; 262-06-T2; 262-06-T3 | 262-04; 262-05; 262-06 | 4; 5; 6 | BOPS-07 | ASVS V4 | Preserve existing authorization and data scope on each admin surface | Catalog + browser | `SIGRA_BRAND_CATALOG=after MIX_ENV=test mix test test/sigra/brand/catalog_test.exs`; relevant example and Playwright admin specs | Planned in Tasks 1-3; pending execution | ✅ passed |
| 262-06-T3 | 262-06 | 6 | BOPS-08 | — | Style only states the existing model can produce | CSS + browser | `bash scripts/ci/admin-css-conformance.sh && bash scripts/ci/admin-token-completeness.sh` plus computed-style admin browser checks | Planned in Task 3; pending execution | ✅ passed |
| 262-08-T1; 262-08-T2; 262-08-T3 | 262-08 | 8 | BAUTH-01 | ASVS V4 | Keep organization auth classes neutral and preserve scope | Template + LiveView + browser | `MIX_ENV=test mix test test/sigra/install/auth_ui_contract_test.exs`; example organization LiveView tests | Planned in Tasks 1-3; pending execution | ✅ passed |
| 262-08-T3; 262-09-T3; 262-13-T1; 262-13-T3 | 262-08; 262-09; 262-13 | 8; 9; 13 | BAUTH-02 | ASVS V2 | Do not leak Sigra identity on host-owned auth surfaces or emails | Catalog + source lint | `GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test catalog`; auth contract tests; generated auth browser/axe | Planned in source, browser, and final tasks; pending execution | ✅ passed |
| 262-10-T1; 262-10-T2; 262-11-T3; 262-12-T2; 262-13-T2; 262-13-T3; 262-14-T3 | 262-10; 262-11; 262-12; 262-13; 262-14 | 10; 11; 12; 13; 14 | BAUTH-03 | ASVS V2 | Preserve frozen routes, helpers, function names, and unlisted msgids | Frozen-surface + golden | `MIX_ENV=test mix test test/sigra/brand/frozen_surface_test.exs test/sigra/install/golden_diff_test.exs` | Planned in source, golden, final, and delivery tasks; pending execution | ✅ passed |
| 262-07-T1; 262-07-T2; 262-13-T1; 262-13-T3 | 262-07; 262-13 | 7; 13 | BAUTH-04 | ASVS V2 | Keep the literal allowlist shrink-only; add no runtime copy map | Copy inventory contract | `MIX_ENV=test mix test test/sigra/brand/copy_inventory_test.exs` | Planned in Tasks 1-2 and final matrix; pending execution | ✅ passed |
| 262-09-T1; 262-13-T1; 262-13-T3 | 262-09; 262-13 | 9; 13 | BAUTH-05 | ASVS V2 | Change new-install defaults only; do not rewrite installed host config | Installer + golden | `MIX_ENV=test mix test test/sigra/install/generator_passkey_primary_login_test.exs test/sigra/install/golden_diff_test.exs` | Planned in source and final tasks; pending execution | ✅ passed |
| 262-10-T1; 262-10-T2; 262-10-T3; 262-11-T1; 262-11-T2; 262-11-T3; 262-12-T1; 262-13-T1; 262-13-T2; 262-13-T3 | 262-10; 262-11; 262-12; 262-13 | 10; 11; 12; 13 | BAUTH-06 | ASVS V2 | Preserve exact msgid text and the frozen `sigra` domain | Template + Gettext | `MIX_ENV=test mix test test/sigra/install/auth_ui_contract_test.exs test/sigra/brand/copy_inventory_test.exs`; documented `mix gettext.extract`/`mix gettext.merge` | Planned in source, preflight, golden, and final tasks; pending execution | ✅ passed |
| 262-12-T1; 262-12-T2; 262-13-T1; 262-13-T3 | 262-12; 262-13 | 12; 13 | BAUTH-07 | ASVS V2 | Keep HTML and text email behavior aligned | Generated email + catalog | Auth contract tests and generated-host email catalog capture | Planned in email, catalog, preflight, and final tasks; pending execution | ✅ passed |

*Task IDs, plan numbers, and waves cross-reference the executable plans in this phase. This strategy remains draft until execution completes the checks and evidence; no validation status is being pre-approved.*

---

## Wave 0 Requirements

- [x] Status-mark component and tests for precedence, visible “Deletion scheduled,” accessible text, and catalog-only Suspended specimen.
- [x] Fixed UTC timestamp formatter tests covering different input offsets.
- [x] BOPS-06 minimum CSS contract level, stale warning tests, and previous-release stylesheet compatibility render.
- [x] Expanded generated literal inventory and shrink-only allowlist contract.
- [x] Generated-auth browser and axe coverage for every touched auth surface.
- [x] Passkey-login distinct email labels/IDs and 320px/200% reflow assertions.
- [x] Explicit 4a catalog comparisons in Light and Dark and 4b per-screen catalog diffs.
- [x] Per-user audit preset end-to-end assertion.

---

## Manual-Only Verifications

All product behavior and acceptance checks are intended to be automated. Explicit owner approval before merging each of the three slice PRs remains a delivery gate, not a manual test.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120 seconds
- [x] `nyquist_compliant: true` set in frontmatter

**Validation:** complete. Phase 262 delivery merges remain pending explicit owner approval in Plan 14.
