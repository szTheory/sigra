---
status: issues_found
phase: 44
phase_name: mfa-account-api-atomic-batches
review_depth: standard
files_reviewed: 9
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
reviewed_at: "2026-04-20"
scope_note: "SUMMARY key-files across 44-01..44-05, post-filtered per workflow D-03 (.planning, SUMMARY, etc. excluded). Erroneous SUMMARY extractor lines (prose under key-decisions) dropped — only paths under lib/, test/, CHANGELOG.md kept."
files:
  - CHANGELOG.md
  - lib/sigra/account.ex
  - lib/sigra/api_token.ex
  - lib/sigra/audit.ex
  - lib/sigra/mfa.ex
  - test/sigra/account_audit_atomicity_test.exs
  - test/sigra/api_token_audit_atomic_test.exs
  - test/sigra/audit_multi_step_test.exs
  - test/sigra/mfa_audit_atomicity_test.exs
---

# Phase 44 — Code review

## Executive summary

Phase 44 wiring (**AUD-06/07**) keeps domain mutations and `Sigra.Audit.log_multi_safe/3` in shared `Ecto.Multi` transactions with Postgres-backed atomicity tests for enroll, verify, account flows, and API token revoke paths. **No critical security defects** were identified in the reviewed sources: audit metadata avoids bearer material, dual-step MFA telemetry lists match `:audit_multi_step` names, and targeted tests pass.

One **warning** remains: **`cleanup_mfa/6` assumes `repo.transaction/1` always returns `{:ok, changes}`**, so failures violate `@spec disable/4` and surface as **`MatchError`** instead of `{:error, _}`. Two **info** items cover tooling (SUMMARY extraction) and test coverage for disable + audit failure.

**Resolved since prior review:** `Sigra.APIToken.revoke/2` `@spec` now documents `{:error, Ecto.Changeset.t()}`.

Verification run:

`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit_multi_step_test.exs test/sigra/mfa_audit_atomicity_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/api_token_audit_atomic_test.exs` — **15 tests, 0 failures**.

---

## Findings

### WR-01 — `cleanup_mfa/6` force-matches a successful transaction

**Severity:** warning  
**File:** `lib/sigra/mfa.ex`  
**Location:** `cleanup_mfa/6` — `{:ok, changes} = repo.transaction(multi)` (~line 950)

**Observation:** `disable/4`, `disable!/4`, and other callers use `cleanup_mfa/6`, which pattern-matches only `{:ok, changes}`. If the `Multi` fails (audit insert rejected, `Trust.revoke_all/3` returning `{:error, _}`, or any other `{:error, failed, value, changes}`), **`repo.transaction/1` returns an error tuple and this line raises `MatchError`**.

**Risk:** Callers and documentation promise `{:ok, :disabled} | {:error, atom()}` for `disable/4`; audit/DB failures instead crash the calling process with an opaque `MatchError`. Rollback behavior is still correct, but error handling and observability are wrong.

**Recommendation:** Replace the force-match with an explicit `case repo.transaction(multi)` (or `with`): on `{:error, ...}`, return a tagged error (or re-raise as `RuntimeError` with context) so public APIs stay predictable. Add a Postgres atomicity test mirroring enroll/verify (CHECK rejecting `mfa.disable`) if you keep `disable/4` non-bang.

---

### IN-01 — GSD `code-review` SUMMARY path extraction + hyphenated keys

**Severity:** info  
**Files:** `.planning/phases/44-mfa-account-api-atomic-batches/44-*-SUMMARY.md` (workflow consumer)

YAML summaries use `key-decisions:` after `key-files.modified`. The workflow’s Node extractor clears `inSection` only for lines matching `^\s*\w+:` **before** the colon; **keys with hyphens** (e.g. `key-decisions:`) do not match, so `inSection` can stay `modified` and **bullet lines under `key-decisions` are mis-parsed as file paths**. Manual filtering fixes it for humans; fixing the workflow regex (or using a real YAML parser) would prevent bogus scope lines.

---

### IN-02 — No atomicity test for `mfa.disable` + audit failure

**Severity:** info  
**Files:** `test/sigra/mfa_audit_atomicity_test.exs`, `lib/sigra/mfa.ex`

Enroll / verify / backup paths have CHECK-constraint rollback tests. **`disable/4` / `disable!/4` audit integration is not covered** the same way; once WR-01 is fixed, a focused test would lock in rollback + error shape.

---

## Security checklist (spot)

- [x] No raw API token / TOTP secret / backup code plaintext in audit `metadata` for reviewed Multi paths  
- [x] Telemetry for Multi audits emitted only after successful `transaction` (`emit_telemetry_from_changes` on `{:ok, changes}`)  
- [x] `log_multi_safe` no-op without `:audit_schema` preserves host-app behavior  

---

## Suggested next steps

- Address **WR-01** before treating MFA disable as production-hardened under audit.  
- Optional: `/gsd-code-review-fix 44` after fixes if using the fix pipeline.  

---

## Report metadata

| Field            | Value        |
|------------------|-------------|
| Reviewer         | Cursor agent (orchestrator; `gsd-code-reviewer` Task type not in environment — review executed inline) |
| Depth            | standard    |
| Scope tier       | SUMMARY.md (corrected for extractor quirk) |
