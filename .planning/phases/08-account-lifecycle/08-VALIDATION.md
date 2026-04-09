---
phase: 8
slug: account-lifecycle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/account_lifecycle` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/account_lifecycle`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | ACCT-01 | T-8-01 / — | Email change requires re-verification | unit | `mix test test/sigra/account/email_change_test.exs` | ❌ W0 | ⬜ pending |
| 8-01-02 | 01 | 1 | ACCT-02 | T-8-02 / — | Password change invalidates sessions | unit | `mix test test/sigra/account/password_change_test.exs` | ❌ W0 | ⬜ pending |
| 8-01-03 | 01 | 1 | ACCT-03 | T-8-03 / — | Account deletion configurable strategy | unit | `mix test test/sigra/account/deletion_test.exs` | ❌ W0 | ⬜ pending |
| 8-01-04 | 01 | 1 | ACCT-04 | T-8-04 / — | Profile hooks run in transaction | unit | `mix test test/sigra/account/profile_hooks_test.exs` | ❌ W0 | ⬜ pending |
| 8-01-05 | 01 | 1 | SESS-09 | T-8-05 / — | Sudo mode re-auth before sensitive ops | unit | `mix test test/sigra/account/sudo_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/account/email_change_test.exs` — stubs for ACCT-01
- [ ] `test/sigra/account/password_change_test.exs` — stubs for ACCT-02
- [ ] `test/sigra/account/deletion_test.exs` — stubs for ACCT-03
- [ ] `test/sigra/account/profile_hooks_test.exs` — stubs for ACCT-04
- [ ] `test/sigra/account/sudo_test.exs` — stubs for SESS-09

*Existing infrastructure covers test framework — ExUnit is built-in.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Email delivery content | ACCT-01 | Email body rendering requires visual inspection | Send test email, verify both confirmation and notification emails contain correct links |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
