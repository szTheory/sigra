---
phase: 242
slug: close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-11
---

# Phase 242 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Phoenix LiveView test helpers; Playwright `@playwright/test` `^1.48.0` |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example && mix test test/example_web/live/app_live_test.exs` |
| **Full suite command** | `scripts/ci/hosted-session-interop-proof.sh --browser-only` |
| **Estimated runtime** | Focused command runtime measured during execution |

---

## Sampling Rate

- **After every task commit:** Run `cd test/example && mix test test/example_web/live/app_live_test.exs`
- **After every plan wave:** Run `scripts/ci/hosted-session-interop-proof.sh --browser-only`
- **Before `$gsd-verify-work`:** Run the full `scripts/ci/hosted-session-interop-proof.sh` from a clean exact-SHA worktree when receipt sealing is authorized
- **Max feedback latency:** One focused LiveView test run per task commit

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 242-01-01 | 01 | 1 | XW-01 | T-242-01 | Native POST form includes CSRF mechanics and no protocol-authority inputs | LiveView unit | `cd test/example && mix test test/example_web/live/app_live_test.exs` | ✅ | ⬜ pending |
| 242-01-02 | 01 | 1 | XW-01, XW-02 | T-242-02 / T-242-03 | Role-driven real-cookie journey preserves exact callback keys, no Referer, fixed `/app`, and non-disclosure | Browser integration | `scripts/ci/hosted-session-interop-proof.sh --browser-only` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Execution extends:

- `test/example/test/example_web/live/app_live_test.exs` with route, method, accessible-name, and no-LiveView-event contract assertions.
- `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` by replacing only the fabricated submission with a role-based click.
- The narrow planning source contract only if necessary to make the rendered boundary durable.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verification or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Existing test files cover all required references
- [ ] No watch-mode flags
- [ ] Feedback latency is measured and remains bounded by the focused suite
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
