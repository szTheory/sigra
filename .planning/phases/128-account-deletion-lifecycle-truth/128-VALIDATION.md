---
phase: 128
slug: account-deletion-lifecycle-truth
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 128 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit / Mix |
| **Config file** | `mix.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15-60 seconds, depending on Postgres availability |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds for focused lifecycle tests

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 128-01-01 | 01 | 1 | LIFE-01 | T-128-01 | Scheduled deletion jobs are enqueued only with explicit worker context and safe no-op degradation remains non-failing. | unit | `mix test test/sigra/account/deletion_test.exs` | ✅ | ✅ green |
| 128-01-02 | 01 | 1 | LIFE-02 | T-128-02 | Cancel and execute reject users that are not actively scheduled instead of mutating finalized users. | unit | `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` | ✅ | ✅ green |
| 128-01-03 | 01 | 1 | LIFE-03 | T-128-03 | Soft-delete finalization preserves the user row while clearing scheduled and email-staging fields. | unit | `mix test test/sigra/account/deletion_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Audit 2026-05-27

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Auditor result: all Phase 128 requirements have automated ExUnit coverage. Focused command `mix test test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs` passed with 35 tests, 0 failures.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s for focused lifecycle tests
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27
