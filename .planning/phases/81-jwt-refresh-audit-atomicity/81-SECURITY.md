---
phase: 81
slug: jwt-refresh-audit-atomicity
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-24
---

# Phase 81 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Host JWT refresh flow → `Sigra.APIToken` | Application calls `audit_jwt_refresh/2` / `audit_jwt_refresh_reuse/2` after JWT logic; audit is optional via `:audit_schema`. | User id, scope-derived audit fields, action strings (`api.jwt_refresh*`), metadata for reuse detection. |
| `Sigra.APIToken` → database | Audit-only `Ecto.Multi` inside `Repo.transaction/1` persists `audit_events` when audit is enabled. | Audit row payloads; failures surface as telemetry, not as error tuples to callers. |

---

## Threat Register

Threats are taken from `<threat_model>` tables in `81-01-PLAN.md`, `81-02-PLAN.md`, and `81-03-PLAN.md`. Plan 81 reuses some IDs across plans; **Component** disambiguates.

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-81-01 | Repudiation | `audit_jwt_refresh*` / `commit_api_token_jwt_audit/3` | mitigate | When `:audit_schema` is set, audit rows use `Repo.transaction/1` + `Multi` + `Audit.log_multi_safe/3`; success telemetry via `emit_telemetry_from_changes/2`. | closed |
| T-81-02 | Tampering | `commit_api_token_jwt_audit/3` (81-01) | mitigate | Unexpected `{:error, failed, reason, _}` raises; `rescue` only `verify_failure_audit_rescue?/1` for constraint-class errors → `log_safe_error` `:constraint_violation`; invalid changeset on audit step → `jwt_audit_emit_invalid_changeset/2`. | closed |
| T-81-03 | Information disclosure | `audit_jwt_refresh/2`, `audit_jwt_refresh_reuse/2` `@doc` (81-01) | mitigate | `@doc` states `:ok` does not prove persistence; operators monitor `[:sigra, :audit, :log_safe_error]`. | closed |
| T-81-02 | Repudiation | `test/sigra/api_token_audit_atomic_test.exs` (81-02) | mitigate | Named tests for happy path, `:audit_schema` absent, and CHECK constraint fault injection with `assert_receive` on `log_safe_error` per action. | closed |
| T-81-03 | Elevation of privilege | Telemetry attach in JWT fault tests (81-02) | mitigate | Unique `:telemetry.attach` ids `{__MODULE__, :jwt_refresh_guard}` and `{__MODULE__, :jwt_reuse_guard}` so handlers do not collide across tests. | closed |
| T-81-03 | Repudiation | Planning inventories / 09 C-1 (81-03) | mitigate | `44-AUD-04-INVENTORY.md` / `45-AUD-04-INVENTORY.md` / `09-VERIFICATION.md` rows AUD-04-048 / 049 describe `Repo.transaction/1` + `Multi` + `log_multi_safe`; **AUD-08** remains explicitly deferred. | closed |
| T-81-04 | Information disclosure | `CHANGELOG.md` [Unreleased] (81-03) | mitigate | Bullet scopes **audit-row atomicity only** and names **AUD-08** as out of scope for refresh-token persistence co-fate. | closed |

*Status: open · closed*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

### Summary threat flags

`81-0{1,2,3}-SUMMARY.md` files do not define a `## Threat Flags` section; no additional flags beyond the plan threat models.

---

## Accepted Risks Log

No accepted risks.

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-24 | 7 | 7 | 0 | Cursor agent / gsd-secure-phase (inline verification; `gsd-security-auditor` subagent type not available in this runtime) |

### Evidence notes (2026-04-24)

- **Implementation:** `lib/sigra/api_token.ex` — `commit_api_token_jwt_audit/3` (lines ~245–283), public wrappers and `@doc` (~470–532).
- **Tests:** `test/sigra/api_token_audit_atomic_test.exs` — JWT refresh/reuse happy, audit-off, fault injection blocks (~313–451).
- **Docs / truth:** `CHANGELOG.md` [Unreleased]; `44-AUD-04-INVENTORY.md` rows AUD-04-048 / 049.

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-24 (automated secure-phase pass)
