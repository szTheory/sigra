---
phase: 127
slug: versioned-auth-data-export
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-27
verified: 2026-05-27
---

# Phase 127 - Security

Per-phase security contract for the versioned auth/account data export.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| generated schemas -> `Sigra.DataExport.export_auth_data/3` | Host-generated Ecto records can include token hashes, encrypted tokens, MFA secrets, passkey material, and backup-code hashes. | User auth/account records, including secret-bearing fields. |
| optional schema opts -> export payload | Missing schemas must be represented honestly so operators know which Sigra-owned sections are absent. | Export completeness metadata. |
| lifecycle fields -> account export section | Stored `deleted_at` and `scheduled_deletion_at` must be interpreted with account deletion semantics. | Account lifecycle state. |
| user-scoped export -> organization/host domain boundary | Per-user export must not overclaim enterprise, SCIM, BI, legal certification, hosted-control-plane, or host-domain data coverage. | User export payload and operator-facing expectations. |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-127-01 | Information Disclosure | `test/sigra/data_export_test.exs` safe serialization coverage | mitigate | Regression assertions refute exported `:hashed_token`, `:encrypted_access_token`, `:encrypted_refresh_token`, `:encrypted_secret`, `:credential_id`, `:public_key`, and `:hashed_code`. | closed |
| T-127-02 | Repudiation | `test/sigra/data_export_test.exs` omission coverage | mitigate | Exact structured omission maps cover all seven optional schema options. | closed |
| T-127-03 | Repudiation | `test/sigra/data_export_test.exs` lifecycle coverage | mitigate | Tests assert scheduled, deleted, and not-scheduled lifecycle states derived through production behavior. | closed |
| T-127-04 | Repudiation | `test/sigra/data_export_test.exs` enterprise/export boundary coverage | mitigate | Tests preserve enterprise exclusion and organization-scoped non-export reason. | closed |
| T-127-05 | Information Disclosure | `fetch_user_records/4`, `fetch_audit_records/3`, backup-code summary | mitigate | Production code uses per-section allowlists, Ecto map projection, normalized rows, and backup-code count-only summary. | closed |
| T-127-06 | Repudiation | `omissions/1` | mitigate | Production code returns structured omission maps for all optional schema options. | closed |
| T-127-07 | Repudiation | `lifecycle_status/1` | mitigate | Production code calls `Sigra.Account.Deletion.status/1` and serializes only scheduled, deleted, and not-scheduled states. | closed |
| T-127-08 | Repudiation | `enterprise` section and account export boundary | mitigate | Production code keeps enterprise `connections: []`, `exported: false`, and the organization-scoped non-export reason. | closed |
| T-127-09 | Denial of Service | optional schema querying | accept | Accepted risk: Phase 127 keeps bounded per-section queries by user id; broader pagination/streaming remains outside EXP-01/EXP-02 and ASVS L1 scope. | closed |

## Evidence

| Threat ID | Evidence |
|-----------|----------|
| T-127-01 | `test/sigra/data_export_test.exs:400`, `:417`, `:418`, `:453`, `:470`, `:471`, and `:474` refute forbidden credential fields. |
| T-127-02 | `test/sigra/data_export_test.exs:356` asserts exact structured omissions. |
| T-127-03 | `test/sigra/data_export_test.exs:303`, `:319`, and `:334` assert all lifecycle states. |
| T-127-04 | `test/sigra/data_export_test.exs:354` asserts enterprise non-export; `lib/sigra/data_export.ex:167` preserves the production boundary. |
| T-127-05 | `lib/sigra/data_export.ex:99`, `:111`, `:126`, `:138`, `:158`, `:190`, and `:244` use allowlists/projections; backup codes are summary-only at `:150`. |
| T-127-06 | `lib/sigra/data_export.ex:26` defines the optional section inventory; `:340` emits structured omission maps. |
| T-127-07 | `lib/sigra/data_export.ex:96`, `:303`, and `:309` include and derive lifecycle status through `Deletion.status/1`. |
| T-127-08 | `lib/sigra/data_export.ex:167` keeps enterprise connections empty, non-exported, and organization-scoped. |
| T-127-09 | Accepted risk documented below. |

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-127-01 | T-127-09 | Optional schema querying does not add pagination or streaming in Phase 127. Accepted for ASVS Level 1 because the export remains bounded to configured per-section user-id queries and broader pagination/streaming is outside EXP-01/EXP-02. | GSD security workflow | 2026-05-27 |

## Threat Flags

No unregistered flags. `127-02-SUMMARY.md` reports `## Threat Flags` as none.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-27 | 9 | 9 | 0 | Codex + gsd-security-auditor |

## Commands Run

```bash
mix test test/sigra/data_export_test.exs --max-failures 1
mix format --check-formatted lib/sigra/data_export.ex test/sigra/data_export_test.exs
! rg -n "hashed_token|encrypted_access_token|encrypted_refresh_token|encrypted_secret|credential_id|public_key|hashed_code" lib/sigra/data_export.ex
rg -n "Deletion\\.status|lifecycle_status|enterprise|omissions|fetch_user_records|fetch_audit_records|repo\\.aggregate" lib/sigra/data_export.ex test/sigra/data_export_test.exs
```

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-27
