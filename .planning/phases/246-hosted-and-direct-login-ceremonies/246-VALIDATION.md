---
phase: 246
slug: hosted-and-direct-login-ceremonies
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-12
---

# Phase 246 — Validation Strategy

> Deterministic generator, PostgreSQL, and fresh-host route evidence for APP-01 through APP-03. Human UAT, sleeps, mocked locks, source-only runtime claims, and waived nonzero commands are not accepted.

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | ExUnit, `Sigra.Test.PostgresCase`, Ecto SQL Sandbox, generated Phoenix host HTTP probes |
| Database | Real PostgreSQL from `tmp/db.env`; isolated temporary database for fresh-host proof |
| Fast generator gate | `MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs --trace` |
| Fast library gate | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_direct_test.exs --trace` |
| Concurrency/fault gate | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_audit_cofate_test.exs test/sigra/app_login_direct_fault_test.exs test/sigra/app_login/concurrency_test.exs --trace` |
| Fresh-host gate | `bash scripts/ci/generated-app-login-runtime-proof.sh` |
| Repository diagnostic | `source tmp/db.env && MIX_ENV=test mix ci`; nonzero remains failure with durable attribution |

## Sampling and Determinism

- Every code-producing task starts with its named behavior test and records RED before GREEN.
- Expiry uses injected clocks or explicit timestamps at 60/300-second boundaries; elapsed-time sleeps are forbidden.
- Concurrency uses two Sandbox-allowed tasks, explicit `:ready`/`:go` messages, real `FOR UPDATE`, and bounded `Task.await/2` only as deadlock detection.
- Fault tests install deterministic constraints/triggers before the public call and remove them in `on_exit`; cleanup failure fails the test.
- Fresh-host readiness uses bounded health polling; protocol scheduling and expiry never use polling or sleeps.
- Evidence receipts are exact-SHA and written last, after install/rerun/migrate/compile/boot/route assertions succeed.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure behavior | Automated command |
|---|---:|---:|---|---|---|
| 246-01-01 | 01 | 1 | APP-02/03 | atomic consume + Phase 245 issue; rollback leaks nothing | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_session_test.exs --trace` |
| 246-02-01 | 02 | 2 | APP-02 | static profiles, exact callbacks, state, S256, explicit 60s continuation | config + app-login focused tests |
| 246-03-01 | 03 | 3 | APP-02 | two-caller hosted exchange serialization | hosted concurrency suite |
| 246-03-02 | 03 | 3 | APP-02 | audit-on/off and constraint rollback | app-login audit co-fate suite |
| 246-04-01 | 04 | 4 | APP-03 | password success parity, uniform failure, pre-auth browser-required | direct suite |
| 246-04-02 | 04 | 4 | APP-03 | digest-only profile/user-bound 300s MFA and atomic issue | direct + hosted equivalence suites |
| 246-05-01 | 05 | 5 | APP-03 | two-caller MFA serialization | combined concurrency suite |
| 246-05-02 | 05 | 5 | APP-03 | exact public failure equality and fault rollback | direct fault suite |
| 246-06-01 | 06 | 1 | APP-01 | complete independent option matrix | installer/app generator/Core tests |
| 246-07-01 | 07 | 2 | APP-01/02/03 | Phase 245 schemas/migration render | app generator test |
| 246-07-02 | 07 | 2 | APP-02/03 | digest-only attempt schema/indexes | app generator test |
| 246-07-03 | 07 | 2 | APP-01/02/03 | static profiles/delegates and direct gating | generator + Core isolation tests |
| 246-08-01 | 08 | 6 | APP-02/03 | real routes, strict inputs, no-referrer, rate limits | generated route test |
| 246-08-02 | 08 | 6 | APP-02 | explicit accessible approve/cancel | generated route render test |
| 246-08-03 | 08 | 6 | APP-02/03 | shared continuation through LiveView/controller MFA | route + existing MFA generator suites |
| 246-09-01 | 09 | 7 | APP-02 | fresh-host hosted real-route + FetchAppSession proof | planning contract + runtime script |
| 246-09-02 | 09 | 7 | APP-01/03 | direct parity, generator isolation, ownership fences | complete focused phase gate |

## Required Evidence Matrix

| Domain | Required assertions |
|---|---|
| Generator | defaults false; all four option combinations; invalid password-without-app selection; exact positive/negative files, injections, migrations, routes; install rerun |
| Hosted | exact profile/callback; scalar/state/S256 validation; login and MFA continuation; explicit approve/cancel; 60s boundary; replay; two callers; audit/persistence rollback |
| Direct | password success; MFA success; exact 300s boundary; replay; two callers; browser-required before auth; identical error status/body/header across all other failures |
| Issuance | hosted/direct persisted shapes equal; both accepted by `FetchAppSession`; raw credentials only after commit; no extra scopes/authority |
| Scope | no OAuth/OIDC server, Lockspire/Crosswake source, dynamic registration, wildcard callback, client secret, WebView, SDK/PWA/Electron runtime, or admin UI |

## Wave 0 Requirements

- [ ] Plan 01 creates `test/support/app_login_schemas.ex` and `test/sigra/app_login_test.exs` before production behavior.
- [ ] Plan 03 creates hosted audit/co-fate and concurrency suites before hardening changes.
- [ ] Plan 04 creates direct state-machine tests before direct implementation.
- [ ] Plan 05 creates direct fault/uniformity assertions before hardening changes.
- [ ] Plan 06 creates the exhaustive generator matrix before registering emitted artifacts.
- [ ] Plan 08 creates rendered-route contracts before modifying shared login/MFA templates.
- [ ] Plan 09 creates the fresh-host source/evidence contract before the runtime script/workflow.

## Sign-Off

- [ ] Every task's automated command passes.
- [ ] Both concurrency paths use explicit barriers and contain no sleeps.
- [ ] All expiry boundaries use injected time.
- [ ] Fresh LiveView and controller hosts pass install/rerun/migrate/compile/boot/real-route proof.
- [ ] The complete focused gate proves APP-01/02/03 and Phase 245 issuance/FetchAppSession compatibility.
- [ ] `mix ci` result is recorded honestly; no missing or failed evidence is marked passed.

**Approval:** pending execution evidence
