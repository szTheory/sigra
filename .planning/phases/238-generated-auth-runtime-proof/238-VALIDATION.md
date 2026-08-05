---
phase: 238
slug: generated-auth-runtime-proof
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-05
---

# Phase 238 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `@playwright/test` 1.59.1 with `@axe-core/playwright` |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://127.0.0.1:$PORT npx playwright test tests/generated-auth.spec.ts --project=generated-auth` |
| **Full suite command** | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh` |
| **Estimated runtime** | CI-bound; local PostgreSQL and browser prerequisites are currently unavailable |

## Sampling Rate

- **After every task commit:** Run the focused generated-auth Playwright target when its temporary host is available.
- **After every plan wave:** Run the fresh-host harness.
- **Before `$gsd-verify-work`:** Exact-commit CI evidence for the generated-host browser lane must be green.
- **Max feedback latency:** One focused Playwright target; never use watch mode or elapsed-time sleeps.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 238-01-01 | 01 | 0 | AUTH-02 | T-238-01 | Generated Google request/callback preserves state/PKCE through the local double and reaches collision handling. | browser integration | fresh-host harness focused probe | ❌ W0 | ⬜ pending |
| 238-01-02 | 01 | 1 | AUTH-01 | T-238-02 | Generated registration, confirmation, password, magic-link, reset, and logout flows complete in-browser. | browser integration | generated-auth Playwright target | ❌ W0 | ⬜ pending |
| 238-01-03 | 01 | 1 | AUTH-03 | T-238-03 | Every material auth render has scoped Axe, label/control, and duplicate-ID proof. | browser accessibility | generated-auth Playwright target | ❌ W0 | ⬜ pending |

## Wave 0 Requirements

- [ ] `scripts/ci/generated-auth-runtime-proof.sh` — fresh-host lifecycle, local provider-double configuration, and bounded cleanup.
- [ ] `test/example/priv/playwright/tests/generated-auth.spec.ts` — generated B2C browser assertions.
- [ ] `test/example/priv/playwright/fixtures/mailbox.ts` — no-sleep confirmation, magic, and reset-link readiness/extraction.
- [ ] Playwright project configuration and CI lane/artifacts for the isolated generated-host test.

## Manual-Only Verifications

All phase behaviors have automated verification. Missing local PostgreSQL/browser prerequisites require CI evidence, not human substitution.

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no three consecutive tasks without automated verification.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags or sleep-based browser synchronization.
- [ ] Exact-commit CI evidence is captured before setting `nyquist_compliant: true`.

**Approval:** pending
