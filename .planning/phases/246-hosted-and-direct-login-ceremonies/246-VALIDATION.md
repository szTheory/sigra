---
phase: 246
slug: hosted-and-direct-login-ceremonies
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-12
last_audited: 2026-08-16
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
| Current-head audit gate | Phase-focused ExUnit matrix across installer, hosted/direct ceremonies, concurrency/faults, generated routes/MFA, evidence contracts, docs, and `FetchAppSession` — PASS (205 tests, 0 failures; 2026-08-16) |

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
| 246-07-01 | 07 | 3 | APP-01/02/03 | Phase 245 schemas/migration render | app generator test |
| 246-07-02 | 07 | 3 | APP-02/03 | digest-only attempt schema/indexes | app generator test |
| 246-07-03 | 07 | 3 | APP-01/02/03 | static profiles/delegates and direct gating | generator + Core isolation tests |
| 246-08-01 | 08 | 6 | APP-02/03 | real routes, strict inputs, no-referrer, rate limits | generated route test |
| 246-08-02 | 08 | 6 | APP-02 | explicit accessible approve/cancel | generated route render test |
| 246-09-01 | 09 | 7 | APP-02/03 | shared continuation through LiveView/controller MFA | focused continuation + existing MFA generator suites |
| 246-10-01 | 10 | 8 | APP-02 | fresh-host hosted real-route + FetchAppSession proof | planning contract + runtime script |
| 246-10-02 | 10 | 8 | APP-01/03 | direct parity, generator isolation, ownership fences | complete focused phase gate |
| 246-11-01 | 11 | 9 | APP-02 | typed hosted attempt; generated start, explicit approval, and single-use exchange | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace && bash scripts/ci/generated-app-login-runtime-proof.sh --hosted` |
| 246-11-02 | 11 | 9 | APP-02 | completed browser assurance only; MFA-pending preserves signed continuation and cannot approve | `MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_auth_continuation_test.exs --trace` |
| 246-12-01 | 12 | 10 | APP-03 | fixed TOTP/backup-code allowlist; malformed selectors retain uniform denial without dynamic atoms | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_generator_test.exs test/sigra/app_login_direct_test.exs test/sigra/app_login_direct_fault_test.exs --trace` |
| 246-12-02 | 12 | 10 | APP-03 | generated backup-code MFA consumes code/challenge once; unknown selector issues no family | `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace && bash scripts/ci/generated-app-login-runtime-proof.sh --direct` |
| 246-13-01 | 13 | 11 | APP-02/03 | both generated credentials authenticate through FetchAppSession; HTTP replays reject without duplicate families | `source tmp/db.env && MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/plug/fetch_app_session_test.exs --trace && bash scripts/ci/generated-app-login-runtime-proof.sh --all` |
| 246-13-02 | 13 | 11 | APP-02/03 | receipt-last per-transition evidence is source-bound, CI-validated, and absent on failure | `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace && bash -n scripts/ci/generated-app-login-runtime-proof.sh` |
| 246-14-01 | 14 | 12 | APP-02 | controller TOTP/backup success rotates the persisted pending session before hosted continuation | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs --only controller --trace` |
| 246-14-02 | 14 | 12 | APP-02 | LiveView factors cross the same controller-owned rotation seam and preserve only the signed continuation | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs test/sigra/install/app_sessions_auth_continuation_test.exs --trace` |
| 246-15-01 | 15 | 12 | APP-02 | one continuation nonce creates at most one committed hosted code | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs --trace` |
| 246-15-02 | 15 | 12 | APP-02 | approval consumption and hosted-code creation co-fate and remain retryable after rollback | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_audit_cofate_test.exs --trace` |
| 246-16-01 | 16 | 13 | APP-01/02 | generated hosts receive the stable unique approval-digest constraint without option drift | `MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/features/core_test.exs --trace` |
| 246-16-02 | 16 | 13 | APP-02 | two concurrent approvals serialize to one hosted code and one app session | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs --trace` |
| 246-17-01 | 17 | 14 | APP-01/02/03 | offline runtime-proof contract is causal, source-bound, fail-closed, and workflow-parseable | `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/planning/phase_246_runtime_evidence_contract_test.exs --trace && bash -n scripts/ci/generated-app-login-runtime-proof.sh && ruby -e 'require "yaml"; YAML.load_file(".github/workflows/generated-app-login-runtime-proof.yml")'` |
| 246-17-02 | 17 | 14 | APP-01/02/03 | retained receipt and provenance bind one successful dispatch to an immutable implementation SHA | `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/planning/phase_246_runtime_evidence_contract_test.exs --trace && jq -e '.status == "passed"' .planning/phases/246-hosted-and-direct-login-ceremonies/246-RUNTIME-PROOF.json && jq -e '.conclusion == "success" and .event == "workflow_dispatch" and .dispatch_attempts == 1' .planning/phases/246-hosted-and-direct-login-ceremonies/246-RUNTIME-PROOF-RUN.json` |
| 246-18-01 | 18 | 15 | APP-02 | generated controller proves current-user-bound pending-session authority before factor verification | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs test/sigra/install/app_sessions_auth_continuation_test.exs --trace` |
| 246-19-01 | 19 | 15 | APP-02 | durable cancellation terminally consumes copied continuations and rolls back safely on faults | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_audit_cofate_test.exs --trace` |
| 246-19-02 | 19 | 15 | APP-02 | generated cancellation storage/transport and approve-versus-cancel serialization are deterministic | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs test/sigra/app_login/concurrency_test.exs --trace` |

## Required Evidence Matrix

| Domain | Required assertions |
|---|---|
| Generator | defaults false; all four option combinations; invalid password-without-app selection; exact positive/negative files, injections, migrations, routes; install rerun |
| Hosted | exact profile/callback; scalar/state/S256 validation; login and MFA continuation; explicit approve/cancel; 60s boundary; replay; two callers; audit/persistence rollback |
| Direct | password success; MFA success; exact 300s boundary; replay; two callers; browser-required before auth; identical error status/body/header across all other failures |
| Issuance | hosted/direct persisted shapes equal; both accepted by `FetchAppSession`; raw credentials only after commit; no extra scopes/authority |
| Scope | no OAuth/OIDC server, Lockspire/Crosswake source, dynamic registration, wildcard callback, client secret, WebView, SDK/PWA/Electron runtime, or admin UI |

## Wave 0 Requirements

- [x] Plan 01 created `test/support/app_login_schemas.ex` and `test/sigra/app_login_test.exs` before production behavior.
- [x] Plan 03 created hosted audit/co-fate and concurrency suites before hardening changes.
- [x] Plan 04 created direct state-machine tests before direct implementation.
- [x] Plan 05 created direct fault/uniformity assertions before hardening changes.
- [x] Plan 06 created the exhaustive generator matrix before registering emitted artifacts.
- [x] Plan 08 created rendered-route contracts before app-route implementation.
- [x] Plan 09 created focused continuation contracts before modifying shared login/MFA templates.
- [x] Plan 10 created the fresh-host source/evidence contract before the runtime script/workflow.
- [x] Plan 11 started with hosted persistence/runtime and assurance-continuation regressions before repairing the generated hosted path.
- [x] Plan 12 started with factor-transport and generated backup-code runtime regressions before changing templates or harness behavior.
- [x] Plan 13 started with generated protected-route/replay and receipt-schema regressions before changing the runtime harness or workflow assertions.
- [x] Plans 14–19 added deterministic regressions for persisted MFA authority, atomic approval, generated uniqueness, source-bound runtime evidence, and durable cancellation before their corresponding repairs.

## Manual-Only Verification

None. Every phase requirement has deterministic automated verification.

## Sign-Off

- [x] Every task maps to a passing automated command.
- [x] Hosted exchange, hosted approval/cancellation, and direct-MFA concurrency use explicit barriers and contain no protocol sleeps.
- [x] Expiry boundaries use explicit timestamps/injected time.
- [x] Fresh LiveView and controller hosts have retained source-bound install/rerun/migrate/compile/boot/real-route proof.
- [x] The current-head focused gate proves APP-01/02/03 and Phase 245 issuance/`FetchAppSession` compatibility (205 tests, 0 failures).
- [x] Repository-wide diagnostics and retained runtime evidence are recorded without waiving nonzero or missing evidence.

**Approval:** validated 2026-08-16

## Validation Audit 2026-08-16

| Metric | Count |
|---|---:|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

The audit extended the task map from plan 13 through plan 19 and reran the phase-focused current-head suite. No missing or partial requirement coverage was found, so no additional test file was generated.
