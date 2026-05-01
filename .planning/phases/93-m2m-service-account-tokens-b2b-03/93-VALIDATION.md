---
phase: 93
slug: m2m-service-account-tokens-b2b-03
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-01
---

# Phase 93 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from `93-RESEARCH.md` `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/service_accounts_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~90–120 seconds (full suite incl. install golden + integration) |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the touched module (e.g. `mix test test/sigra/oauth/token_test.exs --max-failures 1`)
- **After every plan wave:** Run the per-wave aggregate
  `mix test test/sigra/service_accounts_test.exs test/sigra/service_accounts_audit_atomicity_test.exs test/sigra/oauth/token_test.exs test/sigra/jwt_test.exs test/sigra/plug/`
- **Before `/gsd-verify-work`:** Full suite green on Postgres, `mix credo --strict` clean, `mix dialyzer` clean
- **Max feedback latency:** ~20 seconds for the touched-module quick command

---

## Per-Task Verification Map

> Skeleton — populated by the planner per PLAN. Each plan must add rows for every `<task>` and link `automated:` to one of the commands below.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 93-01-01 | 01 | 0 | B2B-03 | T-93-05 | `Sigra.ServiceAccounts` module compiles; JWT + FetchBearer SA forks no longer raise undefined-module warnings | unit | `mix compile --warnings-as-errors && mix test test/sigra/service_accounts_test.exs --max-failures 1` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| B2B-03 | SA create/revoke/credential lifecycle + atomic audit | unit + atomicity | `mix test test/sigra/service_accounts_test.exs test/sigra/service_accounts_audit_atomicity_test.exs` | Wave 0 (NEW) |
| B2B-03 | JWT issued for SA via `/oauth/token` returns valid JWT (RFC 6749 §5.1 envelope) | integration | `mix test test/sigra/oauth/token_test.exs` | Wave 0 (NEW) |
| B2B-03 | JWT verify path forks on `actor_type` and applies SA epoch + credential checks | unit | `mix test test/sigra/jwt_test.exs` (extend) | Yes (extend) |
| B2B-03 | `Sigra.Plug.FetchBearer` SA fork builds `scope.actor_type == :service_account` correctly | unit | `mix test test/sigra/plug/fetch_bearer_test.exs` (extend) | Yes (extend) |
| B2B-03 | `RequireMembership` / `RequireOrgMfa` short-circuit on `actor_type == :service_account` | unit | `mix test test/sigra/plug/require_membership_test.exs test/sigra/plug/require_org_mfa_test.exs` | Yes (extend) |
| B2B-03 | Generator gating: SA artifacts emitted iff `--organizations` AND `--jwt` | install golden | `mix test test/sigra/install/golden_diff_test.exs` (extend) | Yes (extend) |
| B2B-03 | E2E: mint SA token, call protected endpoint, revoke, assert 401 (+ audit rows for both halves) | integration | `mix test --only integration test/example/test/example_web/integration/service_account_e2e_test.exs` | Wave 0 (NEW) |
| B2B-03 | Audit rows for `service_account.create / revoke / credential_create / credential_revoke / token_issued` and `api.token_verify.failure` (SA path) | integration | covered by E2E above; assertions on `audit_events` table | covered |

---

## Wave 0 Requirements

> Files that MUST exist before Wave 1 can ship — these are the validation prerequisites that unblock every downstream task.

- [ ] `lib/sigra/service_accounts.ex` — REQUIRED to restore compile (`mix compile --warnings-as-errors` is currently broken on main; JWT line 137 + FetchBearer line 188 reference undefined `Sigra.ServiceAccounts.append_token_issued_audit/4` and `commit_verify_failure_audit/3`).
- [ ] `Sigra.Config` `:service_accounts` keyword schema entry + `:jwt[:client_credentials_access_ttl]` sub-key (consumed by `Sigra.JWT.generate_service_account_tokens/3` line 120 and `verify_service_account_epoch/2` line 478).
- [ ] `priv/templates/sigra.install/core/scope.ex` — add `service_account_id: nil` to `defstruct` and a `def new(%{} = attrs)` clause that accepts the SA-shape map built by `FetchBearer.build_jwt_scope/3` line 122.
- [ ] `test/sigra/service_accounts_test.exs` — CRUD + revoke unit coverage.
- [ ] `test/sigra/service_accounts_audit_atomicity_test.exs` — co-fated rollback under CHECK fault injection (mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs`).
- [ ] `test/sigra/oauth/token_test.exs` — RFC 6749 envelope conformance (success + every error code: `invalid_request`, `invalid_client`, `invalid_grant`, `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`).
- [ ] `test/example/test/example_web/integration/service_account_e2e_test.exs` — generator-host E2E (ROADMAP SC #4).
- [ ] No new framework install needed; ExUnit + Postgres already in place per `CLAUDE.md`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| _(none)_ | — | Per D-93-24, this phase ships zero human UAT — all verification shifts to integration/E2E automation. | — |

*All phase behaviors have automated verification (per D-93-24 — zero human UAT preference).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (Pitfalls 1–3 from RESEARCH.md)
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s for quick command, < 120s for full suite
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
