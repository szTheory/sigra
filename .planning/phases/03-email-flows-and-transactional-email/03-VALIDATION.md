---
phase: 3
slug: email-flows-and-transactional-email
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | CONF-01 | T-3-01 / — | Confirmation token is single-use, SHA-256 hashed | unit | `mix test test/sigra/auth/confirmation_test.exs` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 1 | CONF-02 | — | 6-digit code hashed, rate-limited entry | unit | `mix test test/sigra/auth/confirmation_code_test.exs` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 1 | CONF-03 | — | Configurable unconfirmed access modes | unit | `mix test test/sigra/auth/unconfirmed_access_test.exs` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 1 | CONF-04 | — | Confirmation resend rate-limited 3/15min | unit | `mix test test/sigra/auth/confirmation_rate_limit_test.exs` | ❌ W0 | ⬜ pending |
| 3-01-05 | 01 | 1 | CONF-05 | T-3-02 / — | Expired token shows resend page, not dead end | integration | `mix test test/sigra/auth/confirmation_expiry_test.exs` | ❌ W0 | ⬜ pending |
| 3-01-06 | 01 | 1 | CONF-06 | — | Double-click shows "already confirmed" | integration | `mix test test/sigra/auth/confirmation_idempotent_test.exs` | ❌ W0 | ⬜ pending |
| 3-02-01 | 02 | 1 | RESET-01 | T-3-03 / — | Reset token single-use, 60min TTL | unit | `mix test test/sigra/auth/reset_password_test.exs` | ❌ W0 | ⬜ pending |
| 3-02-02 | 02 | 1 | RESET-02 | — | All sessions invalidated after reset | unit | `mix test test/sigra/auth/reset_session_invalidation_test.exs` | ❌ W0 | ⬜ pending |
| 3-02-03 | 02 | 1 | RESET-03 | T-3-04 / — | Enumeration-safe: identical response for known/unknown | unit | `mix test test/sigra/auth/reset_enumeration_test.exs` | ❌ W0 | ⬜ pending |
| 3-02-04 | 02 | 1 | RESET-04 | — | Expired reset link shows re-request page | integration | `mix test test/sigra/auth/reset_expiry_test.exs` | ❌ W0 | ⬜ pending |
| 3-02-05 | 02 | 1 | RESET-05 | — | OAuth-only users get guidance email | unit | `mix test test/sigra/auth/reset_oauth_user_test.exs` | ❌ W0 | ⬜ pending |
| 3-03-01 | 03 | 2 | EMAIL-01 | — | Swoosh email struct with multipart body | unit | `mix test test/sigra/mailer_test.exs` | ❌ W0 | ⬜ pending |
| 3-03-02 | 03 | 2 | EMAIL-02 | — | Oban async delivery with retry | unit | `mix test test/sigra/workers/email_delivery_test.exs` | ❌ W0 | ⬜ pending |
| 3-03-03 | 03 | 2 | EMAIL-03 | — | Inline fallback when Oban absent | unit | `mix test test/sigra/delivery_test.exs` | ❌ W0 | ⬜ pending |
| 3-03-04 | 03 | 2 | EMAIL-04 | — | HTML + text templates generated | integration | `mix test test/sigra/generator/email_templates_test.exs` | ❌ W0 | ⬜ pending |
| 3-03-05 | 03 | 2 | EMAIL-05 | — | Token cleanup worker runs daily | unit | `mix test test/sigra/workers/token_cleanup_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/auth/confirmation_test.exs` — stubs for CONF-01 through CONF-06
- [ ] `test/sigra/auth/reset_password_test.exs` — stubs for RESET-01 through RESET-05
- [ ] `test/sigra/workers/email_delivery_test.exs` — stubs for EMAIL-01 through EMAIL-05
- [ ] `test/support/fixtures/email_fixtures.ex` — shared test fixtures for email flows

*Existing ExUnit infrastructure covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Email renders correctly in Gmail/Outlook | EMAIL-04 | Requires visual email client inspection | Send test email via dev mailbox, open in multiple clients |
| Auto-submit on 6-digit code entry | CONF-02 | Requires browser JS execution | Enter 6 digits in LiveView form, verify auto-submission |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
