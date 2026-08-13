---
phase: 245
slug: opaque-app-session-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-12
---

# Phase 245 — Validation Strategy

> Deterministic, PostgreSQL-backed execution contract for APP-04 and APP-05. All verification is automated; no human UAT or sleep-based concurrency evidence is accepted.

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit; `Sigra.Test.PostgresCase`; Ecto SQL Sandbox; Mox only for unchanged facade unit seams |
| **Config file** | `test/test_helper.exs`; PostgreSQL environment from `tmp/db.env` |
| **Quick run command** | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/plug/fetch_app_session_test.exs --trace` |
| **Lifecycle run command** | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs test/sigra/app_session_security_event_test.exs test/sigra/app_session_account_deletion_test.exs --trace` |
| **Full focused gate** | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/app_session_audit_cofate_test.exs test/sigra/app_session/concurrency_test.exs test/sigra/app_session_security_event_test.exs test/sigra/app_session_account_deletion_test.exs test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_scopes_test.exs test/sigra/auth_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --trace` |
| **Repository diagnostic** | `source tmp/db.env && MIX_ENV=test mix ci`; a nonzero exit remains a failure and must be classified, never converted into a pass |

## Sampling Rate

- After every RED commit, run the task's exact command and preserve the expected missing-behavior failure.
- After every GREEN/refactor commit, rerun the exact command; no task completes without a real PostgreSQL pass where persistence or locking is claimed.
- After Wave 3, run the full issue/auth/refresh/audit/concurrency set in audit-on and audit-off modes.
- After Wave 5, run the full focused gate once, including browser/PAT/JWT independence and all named APP-05 events.
- Before phase verification, run `mix ci` once as a repository diagnostic and preserve structured failure attribution if unrelated historical failures remain.
- Max feedback latency: focused unit/Plug tests should remain under 30 seconds; bounded PostgreSQL concurrency and full focused gates may take longer but never watch, retry-loop, or sleep.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Refs | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---|---:|---:|---|---|---|---|---|---|---|
| 245-01-01 | 01 | 1 | APP-04 | T-245-01..03 | exact TTLs, digest-only issue/auth, host-schema seam | PostgreSQL tracer/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` | Wave 0 create | pending |
| 245-02-01 | 02 | 2 | APP-04, APP-05 | T-245-04..07 | explicit Plug, live user, bounded private facts, redaction | Plug + PostgreSQL | `source tmp/db.env && MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs test/sigra/plug/fetch_api_token_test.exs test/sigra/plug/fetch_jwt_test.exs test/sigra/plug/require_scopes_test.exs --trace` | existing; update | pending |
| 245-03-01 | 03 | 2 | APP-04 | T-245-08..11 | locked rotate, idle/absolute expiry, committed reuse revoke | PostgreSQL lifecycle/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` | Wave 0 create | pending |
| 245-04-01 | 04 | 3 | APP-04 | T-245-12, T-245-14 | audit-on/off co-fate and constraint rollback | PostgreSQL fault injection/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_audit_cofate_test.exs --trace` | Wave 0 create | pending |
| 245-04-02 | 04 | 3 | APP-04 | T-245-13, T-245-15 | exactly one rotate plus one serialized reuse without sleeps | two-client PostgreSQL/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session/concurrency_test.exs --trace` | Wave 0 create | pending |
| 245-05-01 | 05 | 4 | APP-05 | T-245-16..19 | owner-bound one/all revoke, cross-user isolation, next-auth denial | PostgreSQL lifecycle/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs --trace` | Wave 0 create | pending |
| 245-06-01 | 06 | 5 | APP-05 | T-245-20, T-245-22..23 | password-reset transaction co-fate and rollback | PostgreSQL security-event/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_security_event_test.exs test/sigra/auth_test.exs --trace` | Wave 0 create | pending |
| 245-06-02 | 06 | 5 | APP-05 | T-245-21..23 | sign-out-all durable fanout with browser parity | PostgreSQL + facade/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_security_event_test.exs test/sigra/auth_test.exs --trace` | Wave 0 create | pending |
| 245-07-01 | 07 | 5 | APP-05 | T-245-24..27 | deletion-schedule co-fate, rollback, strategies, cascade | PostgreSQL security-event/TDD | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_account_deletion_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --trace` | Wave 0 create | pending |

## Wave 0 Requirements

- [ ] `test/support/app_session_schemas.ex` provides representative host-owned family/token Ecto schemas and test SQL with UUID/FK/unique digest/lifecycle indexes; it is test-only and does not preempt Phase 246 generation.
- [ ] `test/sigra/app_session_test.exs` covers defaults, digest-only persistence, issue/authenticate, expiry, rotation/reuse, and owner-bound one/all revoke.
- [ ] `test/sigra/app_session_audit_cofate_test.exs` covers audit-on/off and persistence/audit constraint rollback.
- [ ] `test/sigra/app_session/concurrency_test.exs` covers a two-task ready/go barrier with Sandbox clients and no sleeps.
- [ ] `test/sigra/app_session_security_event_test.exs` covers password reset and sign-out-all fanout/co-fate.
- [ ] `test/sigra/app_session_account_deletion_test.exs` covers scheduling, rollback, strategies, cross-user isolation, and representative cleanup/cascade.
- [ ] Existing `test/sigra/plug/fetch_app_session_test.exs` is converted from the Phase 243 inert baseline to valid/invalid/revoked/redacted explicit app-session behavior.

## Determinism and Evidence Rules

- Concurrency starts only after both tasks signal readiness and receive an explicit `:go`; assert result multisets and exact persisted state, not scheduling order.
- Use `Task.await/2` with a bounded timeout only as a deadlock failure bound, never as timing control.
- Fault-injection constraints are created before the call and removed in `after` blocks; absence or cleanup failure is test failure.
- Assertions count exact family/token/audit rows and check next-auth behavior through public APIs.
- No `Process.sleep/1`, shell `sleep`, watch flags, human approval, mocked row locks, error-suppressing fallbacks, or unclassified nonzero command is valid evidence.

## Manual-Only Verifications

None. Phase 245 is library/database work and is fully automatable.

## Validation Sign-Off

- [ ] All nine task IDs have a deterministic `<automated>` command.
- [ ] Every APP-04/APP-05 observable behavior maps to at least one PostgreSQL or Plug test.
- [ ] Audit-on, audit-off, rollback, reuse, and two-caller branches are all sampled.
- [ ] Password reset, account deletion, sign-out-all, explicit revoke, and refresh reuse each have next-auth denial proof.
- [ ] Existing browser, PAT, and JWT focused suites pass independently.
- [ ] No generated schema/migration/config/route/controller or ceremony appears in the Phase 245 diff.
- [ ] `nyquist_compliant: true` and `wave_0_complete: true` are set only after execution evidence exists.

**Approval:** pending execution evidence

## Multi-Source Coverage Audit

The CONTEXT bullets have no inline identifiers, so the plans enumerate them in source order as D-01 through D-13: digest-only credentials; dedicated family/token rows; exact TTLs; bounded server client reference; request-time state/user recheck; private metadata; locked transaction/post-commit response; every-use pair rotation; reuse-family revoke; barrier concurrency; owner-bound one/all revoke; five named invalidation triggers; and existing-transaction co-fate.

| SOURCE | ID | Feature / Constraint | Plans | Status |
|---|---|---|---|---|
| GOAL | — | Bounded, rotating, reliably revocable opaque first-party app credentials | 01–07 | COVERED |
| REQ | APP-04 | Digest-only issue, exact defaults, atomic rotation, consumed-token family revoke | 01, 03, 04 | COVERED |
| REQ | APP-05 | One/all revoke and reset/deletion/sign-out/explicit/reuse invalidation on next auth | 02, 05, 06, 07 | COVERED |
| CONTEXT | D-01..D-04 | Opaque storage model, dedicated rows, exact TTLs, bounded server reference | 01, 03 | COVERED |
| CONTEXT | D-05..D-06 | Authoritative explicit Plug recheck, normal Scope, bounded private facts | 01, 02 | COVERED |
| CONTEXT | D-07..D-10 | Locked transaction, pair rotation, committed reuse revoke, no-sleep concurrency | 03, 04 | COVERED |
| CONTEXT | D-11..D-13 | Owner one/all revoke, all events, existing-transaction co-fate | 05, 06, 07 | COVERED |
| RESEARCH | family/token architecture | Host-owned schemas with explicit FKs/digest/lifecycle indexes; no JWT JSON reuse | 01, 03 | COVERED |
| RESEARCH | audit and rollback | Same Multi in audit-on/off; telemetry/response after commit; fault injection | 04, 05 | COVERED |
| RESEARCH | credential boundary | Live-user lookup, family-state join, legacy browser/PAT/JWT independence | 01, 02, phase gate | COVERED |
| RESEARCH | security fanout | Reset/deletion co-fate and durable sign-out-all | 06, 07 | COVERED |
| RESEARCH | no new package | Existing Sigra/Ecto/PostgreSQL stack only | all | COVERED |

### Scope-Fence Result

Phase 246 owns all installer flags, generated schema/migration/config/delegate/controller/router artifacts, PKCE/hosted/direct password/MFA ceremonies, and issuance transport. Native SDK, PWA/offline/media, Crosswake, Electron, OAuth/OIDC authorization-server, Lockspire, and admin UI work are also excluded. Phase 245 creates only test-local representative schemas to prove the library-facing host seam. No source item is missing and no split is required.
