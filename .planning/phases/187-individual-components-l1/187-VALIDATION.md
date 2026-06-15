---
phase: 187
slug: individual-components-l1
status: ratified
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-14
---

# Phase 187 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Playwright + axe-core |
| **Config file** | `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs` |
| **Full suite command** | `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs && (cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark)` |
| **Estimated runtime** | Quick command: 0.74s wall-clock. Full command: 246.38s wall-clock (~4m06s) with the example server already running on `SIGRA_EXAMPLE_URL=http://localhost:4011`. |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs`
- **After every plan wave:** Run the full suite command above, plus `bash scripts/ci/quality-ledger-monotonic.sh --base HEAD`
- **Before `$gsd-verify-work`:** Full suite, snapshot canary/recapture gates as needed, install goldens, component goldens, and ledger monotonic must be green
- **Max feedback latency:** ~4m06s for the full ExUnit + admin-design chromium/mobile/dark lane; 0.74s for the quick ExUnit lane.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 187-W0-01 | 187-01 | 0 | COMP-01, COMP-04 | T-187-01 | Gallery evidence remains example-only and does not leak into generated hosts | Playwright board inventory + axe | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "notice_link\|overflow\|help"` | yes, 13 L1 boards including `board-notice_link` | green |
| 187-W0-02 | 187-01 | 0 | COMP-05 | T-187-02 | Component boards do not overflow, clip, or squish at required widths | Playwright viewport assertions | `RESPONSIVE_WIDTHS = [320, 375, 768, 1024, 1440] as const` plus focused overflow assertion | yes | green |
| 187-W0-03 | 187-01 | 0 | COMP-03, COMP-04 | T-187-03 | Help/tooltip states remain keyboard reachable, escapable, and non-trapping | Playwright DOM/behavior assertions | Deterministic open attrs for `field_help` and `summary_chip`; Escape-close assertions pass | yes | green |
| 187-W0-04 | 187-02 | 0 | COMP-01, COMP-02, COMP-03 | T-187-04 | Post-migration shipped component CSS lives in canonical `sigra_admin.css`, migrated selectors are removed from example `app.css`, and example CSS cannot mask missing shipped rules | Shipped-CSS migration, duplicate-removal grep/script, install parity tests, and admin-design matrix | Duplicate-selector check against `test/example/priv/static/assets/css/app.css`, canonical `@layer sg-components` selector script, CSS parity `cmp`, `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs`, and `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark` | yes | green |
| 187-PHASE | 187-07 | final | COMP-01, COMP-02, COMP-03, COMP-04, COMP-05, COMP-06 | T-187-01..21 | HEEx escaping preserved, disabled states inert, loading semantics are correct, and accessibility gates are clean | ExUnit + Playwright + axe + ledger | Final full suite command passed: ExUnit 63/0 plus admin-design 75/0, snapshot canary guard passed with 0 changed slugs, allowlists empty, and `quality-ledger-monotonic.sh --base HEAD` passed | yes | green |

*Status: pending | green | red | flaky*

---

## Wave 0 Requirements

- [x] Inventory exact component `sg-*` CSS blocks currently in `test/example/priv/static/assets/css/app.css` and map them to the 13 canonical components before migration. This inventory alone does not green `187-W0-04`; that row turns green only after the Plan 02 shipped-CSS migration, duplicate removal, and parity checks pass.
- [x] Decide and implement the evidence shape for `notice_link`: add `board-notice_link` or document why embedded coverage in `board-notice` satisfies COMP-01 and COMP-04.
- [x] Add deterministic overflow/clip/squish assertions for component boards at 320, 375, 768, 1024, and 1440 pixels.
- [x] Add or expose deterministic open states for `field_help` and summary-chip help so COMP-03 and COMP-04 are testable.
- [x] Measure the quick and full validation command runtimes and replace the placeholder timing fields above.

187-W0-04 greened after Plan 02 completed shipped-CSS migration, duplicate removal from `app.css`, canonical/example/golden CSS parity, install/golden tests, and the chromium/mobile/dark admin-design matrix.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Component state matrix copy serves the job-to-be-done and follows Rail Accent voice | COMP-06 | Copy quality is not fully machine-verifiable | Review `empty_state`, `notice`, and `field_help` board text against `guides/reference/admin-design-contract.md` before raising ledger rows |
| Visual distinctness reaches Ratified or Award-grade | COMP-01, COMP-03 | Automated screenshots detect drift, not design quality | Inspect recaptured board screenshots in light, dark, and mobile and record intended deltas before updating baselines |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency measured and bounded
- [x] `nyquist_compliant: true` set in frontmatter after plans include these checks

**Approval:** approved 2026-06-15 after Phase 187 final gates passed
