---
phase: 188
slug: meta-components-groups-l2
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-15
---

# Phase 188 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Playwright |
| **Config file** | `mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` |
| **Full suite command** | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs && (cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark) && bash scripts/ci/quality-ledger-monotonic.sh --base HEAD` |
| **Estimated runtime** | ~180-300 seconds with the example app already running |

---

## Sampling Rate

- **After every task commit:** Run the quickest relevant command from the task's `<verify>` block.
- **After every plan wave:** Run `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` and the relevant Playwright project(s).
- **Before `$gsd-verify-work`:** Full suite command above must be green.
- **Max feedback latency:** 300 seconds for full wave validation; under 90 seconds for source-only/doc-only task checks.

---

## Per-Requirement Verification Map

| Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| GROUP-01 | T-188-01 | MG-1..MG-11 use the right component for each job, avoid card-in-card nesting, and pass scorecard assertions. | Playwright DOM + source assertions | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "board-mg"` | yes | pending |
| GROUP-02 | T-188-02 | Each MG board has documented zero, loading, and error states, or a source-commented impossibility rationale. | Playwright DOM + source assertions | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "state"` | yes | pending |
| GROUP-03 | T-188-03 | Desktop table and mobile card variants expose equivalent primary facts, status/outcome, secondary facts, identifiers, and navigation/actions without squished columns. | Playwright responsive assertions | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --grep "MG-5|MG-6|content-equivalent"` | yes | pending |
| GROUP-04 | T-188-04 | Reused groups render byte-coherently across pages except for named density/scope variants documented in board labels and ledger evidence. | Playwright DOM + ledger guard | `bash scripts/ci/quality-ledger-monotonic.sh --base HEAD` plus matching Playwright coherence assertions | yes | pending |

*Status: pending, green, red, flaky*

---

## Wave 0 Requirements

- [ ] Confirm the example app is running for Playwright with `SIGRA_EXAMPLE_URL=http://localhost:4011`.
- [ ] Confirm `test/example/priv/playwright/tests/admin-design.spec.ts` contains deterministic readiness gates and no sleeps.
- [ ] Confirm `scripts/ci/quality-ledger-monotonic.sh --base HEAD` is available before any ledger tier edits.
- [ ] Confirm all planned UI assertions use roles, stable hooks, and existing `sg-*` selectors.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Final L2 ledger tier claim per MG row | GROUP-01, GROUP-04 | Tier level depends on evidence quality produced during execution. | Review generated screenshots/evidence links before claiming tier 2 or higher; do not decrease any existing tier. |
| Visual rhythm and density judgment for state variants | GROUP-01, GROUP-02 | Automated assertions catch structure and states, but final rhythm still needs curated screenshot review. | Review light, dark, mobile, and desktop screenshots for MG-1..MG-11 after Playwright updates. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands or explicit manual-only rationale.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers missing prerequisites before UI implementation tasks.
- [ ] No watch-mode flags.
- [ ] Feedback latency under 300 seconds for wave validation.
- [ ] `nyquist_compliant: true` set in frontmatter after executable plans map final task IDs.

**Approval:** pending
