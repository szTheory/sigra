---
phase: "260"
slug: deterministic-output-before-catalog-and-png-park
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-15"
---

# Phase 260 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `260-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5); `node --test` (prohibitions); Bash `.test.sh` twins; Playwright (generated-host behavior) |
| **Config file** | `mix.exs` (`aliases`, `test_load_filters`), `test/test_helper.exs`, `test/example/test/test_helper.exs` (`exclude: [:example_app]`), `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `source tmp/db.env && mix test test/sigra/brand test/sigra/install/asset_parity_test.exs test/sigra/install/features/admin_test.exs` |
| **Full suite command** | `source tmp/db.env && MIX_ENV=test mix ci && (cd test/example && MIX_ENV=test mix test --include example_app) && MIX_ENV=test mix sigra.fixture.rebless_golden --check` |
| **Estimated runtime** | quick ~30 s; full several minutes |

---

## Sampling Rate

- **After every task commit:** quick run command
- **After every plan wave:** full suite command
- **Before `/gsd-verify-work`:** full suite green + `scripts/ci/admin-acceptance-smoke.sh --test all` green + privacy grep (with planted control)
- **Max feedback latency:** ~30 s per task (no scaffolds)

---

## Per-Task Verification Map

Populated by the planner per task. Requirement-level map:

| Requirement | Behavior | Test Type | Automated Command | File Exists |
|-------------|----------|-----------|-------------------|-------------|
| BGEN-01 | Every copied asset byte-identical or documented divergence; planted mismatch reported | unit | `mix test test/sigra/install/asset_parity_test.exs` | ❌ W0 |
| BGEN-02 | Two fresh installs equal after normalization | integration | `mix test test/sigra/install/double_install_test.exs` | ❌ W0 |
| BGEN-02 | Golden fixture matches installer under pinned phx_new 1.8.8 | integration | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | ✅ |
| BGEN-03 | Normalizer, manifest hashes, privacy scan, planted leak | unit | `mix test test/sigra/brand/catalog_test.exs` | ❌ W0 |
| BGEN-03 | Tier-2 pages render deterministically for seeded personas | integration | `cd test/example && mix test --include example_app test/example_web/catalog_test.exs` | ❌ W0 |
| BGEN-04 | Brand mark + explicit theme rules + version stamp in template/example/golden | unit | `mix test test/sigra/install/features/admin_test.exs` | ✅ (edit) |
| BGEN-04 | Real generated host: lockup swaps, explicit theme applies | browser | `GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test chrome` | ❌ assertions to add |
| BGEN-05 | CSS guards pass on real file, fail on planted defects | script self-test | `bash scripts/ci/admin-css-conformance.test.sh && bash scripts/ci/admin-css-conformance.sh && bash scripts/ci/admin-token-completeness.sh` | ✅ (extend) |
| BGEN-05 | Guards wired into `mix ci` | contract | ExUnit contract reading `mix.exs` alias | ❌ W0 |
| BGEN-06 | PR/push path never compares PNGs; dispatch + recapture do; canary unallowlisted | contract | `mix test test/sigra/planning/phase_260_png_park_contract_test.exs` | ❌ W0 |
| BGEN-06 | Enumeration guards still green | script/contract | `node --test scripts/ci/prohibitions/*.test.mjs && bash scripts/ci/ci-demotion-observer.test.sh` | ✅ |
| BGEN-07 | Identical dirs report none; planted change/removal reported | script via ExUnit | `mix test test/sigra/brand/catalog_diff_test.exs` | ❌ W0 |
| BGEN-08 | Gallery sections render, stay out of board registries | integration | `cd test/example && mix test --include example_app` | ❌ W0 |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/install/asset_parity_test.exs`
- [ ] `test/sigra/install/double_install_test.exs` (+ `ci.install_golden` alias entry)
- [ ] `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`, `test/example/test/example_web/catalog_test.exs`
- [ ] `test/fixtures/brand/before/` + `MANIFEST.json` + `.gitattributes -text` line
- [ ] `test/sigra/planning/phase_260_png_park_contract_test.exs`
- [ ] `scripts/brand/catalog-diff.sh` + `test/sigra/brand/catalog_diff_test.exs`
- [ ] Playwright assertions in `admin-generated.spec.ts` (generated-host L1 proof)

**Positive controls required** (each guard must be seen to fire once): parity table (planted byte), conformance guard (planted hex), PNG-compare flag (flag on + perturbed expectation fails), privacy scan (planted home path), `ci.install_golden` listing (deliberately failing assertion once), catalog normalizer (planted csrf/uuid/relative time).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Park PR merge approval | BGEN-06 | Owner decision #7: explicit approval to merge | Recorded as a plain-chat approval before merge |
| Wire-vs-retire of CSS guards | BGEN-05 | Owner decision #13 | Recorded approval at execution |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
