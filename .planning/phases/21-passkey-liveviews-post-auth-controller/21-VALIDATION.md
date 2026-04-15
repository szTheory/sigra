---
phase: 21
slug: passkey-liveviews-post-auth-controller
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for library and example app, Playwright for browser smoke |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/require_sudo_test.exs test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys_test.exs test/sigra/passkeys/authentication_test.exs test/sigra/install/features/passkeys_js_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test) && (cd test/example/priv/playwright && npm test -- --grep passkeys)` |
| **Estimated runtime** | ~240 seconds |

---

## Sampling Rate

- **After every task commit:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys_test.exs test/sigra/passkeys/authentication_test.exs test/sigra/install/features/passkeys_js_test.exs`
- **After every plan wave:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test)`
- **Before `$gsd-verify-work`:** Full suite must be green and passkey-specific Playwright coverage added
- **Max feedback latency:** 240 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-01 | 01 | 1 | PK-UX-01, PK-UX-04 | T-21-01 | Enrollment and delete reject stale sudo and only proceed after fresh reverification | integration | `cd test/example && mix test test/example/test/example_web/live/passkey_settings_live_test.exs -x` | ❌ W0 | ⬜ pending |
| 21-01-02 | 01 | 1 | PK-UX-02, PK-UX-03, PK-UX-09 | T-21-02 / T-21-04 | Registration emits notification, resolves friendly labels, and remaps duplicate credentials to user-safe copy | integration | `cd test/example && mix test test/example/test/example_web/live/passkey_settings_live_test.exs -x` | ❌ W0 | ⬜ pending |
| 21-02-01 | 02 | 1 | PK-UX-05, PK-UX-12 | T-21-05 | MFA challenge stays passkey-first with visible fallback and neutral abort recovery | liveview + browser | `cd test/example && mix test test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs -x` and `cd test/example/priv/playwright && npm test -- --grep passkey` | ❌ W0 / ✅ partial | ⬜ pending |
| 21-03-01 | 03 | 2 | PK-UX-06, PK-UX-07, PK-UX-08, PK-UX-11 | T-21-03 | Primary login remains identifier-first, preserves recovery, and finishes through controller POST session renewal | controller + browser | `cd test/example && mix test test/example/test/example_web/controllers/passkey_session_controller_test.exs -x` and `cd test/example/priv/playwright && npm test -- --grep passkey` | ❌ W0 / ✅ partial | ⬜ pending |
| 21-04-01 | 04 | 2 | PK-UX-10 | T-21-05 | Generated app still uses Phase 20 hook contract instead of custom JS plumbing | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs -x` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/test/example_web/live/passkey_settings_live_test.exs` — settings-page enrollment/list/rename/delete/recovery coverage
- [ ] `test/example/test/example_web/live/passkey_mfa_challenge_live_test.exs` — passkey-first MFA fallback matrix
- [ ] `test/example/test/example_web/controllers/passkey_session_controller_test.exs` — controller POST completion and session renewal
- [ ] `test/example/test/example_web/emails/passkey_registration_email_test.exs` or suspicious-login email extension test — registration email content
- [ ] Extend `test/example/priv/playwright/tests/passkeys-hooks.spec.ts` or add `passkeys-auth-flow.spec.ts` — browser-level passkey UX coverage

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Conditional UI / autofill discoverability in supported browsers | PK-UX-08 | Browser autofill affordances are partly environment-specific and flaky to assert visually | In a supported browser, load the passkey-primary login page, confirm the email field remains visible, and verify the browser can offer passkey autofill without hiding password or magic-link fallbacks |
| Last-passkey delete warning strength | PK-UX-04, PK-UX-07 | Copy severity and account-recovery posture need human judgment beyond string presence | Seed a user with one passkey in passkey-primary mode, enter the delete flow after sudo, and confirm the warning explicitly calls out remaining recovery methods |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 240s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
