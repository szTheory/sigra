---
phase: 127
slug: versioned-auth-data-export
status: audited
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 127 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs`; `config/test.exs` |
| **Quick run command** | `mix test test/sigra/data_export_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~5 seconds focused; full suite depends on Postgres-backed tests |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/data_export_test.exs --max-failures 1`
- **After every plan wave:** Run `mix test test/sigra/data_export_test.exs && mix format --check-formatted lib/sigra/data_export.ex test/sigra/data_export_test.exs`
- **Before `$gsd-verify-work`:** Full suite must be green with `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`
- **Max feedback latency:** 30 seconds for focused data export feedback

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 127-01-01 | 01 | 1 | EXP-01 | T-127-01 | Export includes version metadata, account lifecycle fields, and derived lifecycle status from `Sigra.Account.Deletion.status/1`. | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | yes | covered |
| 127-01-02 | 01 | 1 | EXP-01 | T-127-02 | Sessions, identities, audit rows, MFA credentials, passkeys, backup-code summary, and memberships serialize through curated safe maps. | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | yes | covered |
| 127-01-03 | 01 | 1 | EXP-01 | T-127-03 | Export output excludes `hashed_token`, `encrypted_access_token`, `encrypted_refresh_token`, `encrypted_secret`, `credential_id`, `public_key`, and `hashed_code`. | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | yes | covered |
| 127-01-04 | 01 | 1 | EXP-02 | T-127-04 | Missing optional schemas keep all section keys present with empty values and explicit omission notes. | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | yes | covered |

---

## Wave 0 Requirements

- [x] `test/sigra/data_export_test.exs` includes configured-schema serializer coverage for sessions, identities, audit, MFA credentials, passkeys, backup-code count, and memberships.
- [x] `test/sigra/data_export_test.exs` includes sensitive-field exclusion assertions for every credential-related section.
- [x] `test/sigra/data_export_test.exs` includes omission inventory assertions for every optional schema option.
- [x] `test/sigra/data_export_test.exs` includes lifecycle status assertion aligned with `Sigra.Account.Deletion.status/1`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | EXP-01, EXP-02 | All phase behaviors have automated verification. | N/A |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all missing references
- [x] No watch-mode flags
- [x] Feedback latency < 30 seconds for focused checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27

## Validation Audit 2026-05-27

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Focused verification passed after audit:

- `mix test test/sigra/data_export_test.exs --max-failures 1` - 7 tests, 0 failures.
- `mix format --check-formatted lib/sigra/data_export.ex test/sigra/data_export_test.exs` - passed.

Coverage evidence:

- Lifecycle status coverage asserts scheduled, deleted, and not-scheduled account states.
- Omission coverage asserts all seven optional schema omission entries.
- Configured-schema coverage asserts curated section maps for sessions, identities, audit rows, MFA credentials, passkeys, backup-code count, and memberships.
- Sensitive-field coverage refutes secret-bearing session, identity, MFA, passkey, and backup-code fields.
