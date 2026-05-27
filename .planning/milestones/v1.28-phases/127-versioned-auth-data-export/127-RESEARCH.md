# Phase 127: Versioned Auth Data Export - Research

**Researched:** 2026-05-27  
**Domain:** Elixir/Phoenix library auth-data export contract  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Public Contract Boundary
- **D-01:** Keep the stable payload contract in library code through `Sigra.DataExport.export_auth_data/3`.
- **D-02:** Generated-host code should only provide configured schemas or thin wrappers around the library contract; it must not become the owner of the export payload shape.

### Payload Shape
- **D-03:** Preserve the current structured, versioned map shape rather than flattening or renaming sections.
- **D-04:** The export should keep stable top-level sections for version metadata, account lifecycle, sessions, identities, audit, MFA, organizations, explicit enterprise/non-user-owned exclusions, and omissions.

### Lifecycle Truth
- **D-05:** Account export lifecycle truth should include both raw lifecycle fields and a derived lifecycle state aligned with `Sigra.Account.Deletion.status/1`.
- **D-06:** Keep lifecycle data bounded to Sigra-owned account fields; do not infer host retention policy or host-owned domain deletion semantics.

### Optional Schema Degradation
- **D-07:** Missing optional schemas must produce present-but-empty section values plus explicit omission notes.
- **D-08:** Omission notes should cover every optional Sigra-owned section that can be unavailable, not only audit, membership, and MFA credentials.
- **D-09:** Missing optional schemas should not raise and should not remove keys from the export payload.

### Sensitive Auth Material
- **D-10:** Export credential-related records as curated Sigra-owned summaries or safe field subsets, not raw generated structs.
- **D-11:** Do not export replay-relevant or secret-bearing material such as session token hashes, encrypted OAuth tokens, encrypted TOTP secrets, passkey credential/public-key blobs, or backup-code hashes.
- **D-12:** Backup codes remain summary-only: count and explicit non-export reason.

### the agent's Discretion
- Exact field names inside curated section items, provided they are stable, documented by tests, and avoid secret material.
- Whether omission notes are strings or structured maps, as long as the operator-facing export remains explicit and tests pin the behavior.
- Exact test helper modules and fixture shape for configured-schema coverage.

### Claude's Discretion
- Exact field names inside curated section items, provided they are stable, documented by tests, and avoid secret material.
- Whether omission notes are strings or structured maps, as long as the operator-facing export remains explicit and tests pin the behavior.
- Exact test helper modules and fixture shape for configured-schema coverage.

### Deferred Ideas (OUT OF SCOPE)
None — analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXP-01 | Operator can export a versioned Sigra-owned auth/account payload that includes account lifecycle fields, sessions, identities, audit rows, MFA credentials, passkey records, backup-code summary, and organization memberships when the generated schemas are available. | Implement in `Sigra.DataExport.export_auth_data/3`; serialize configured schema rows into curated maps instead of returning raw structs. [VERIFIED: `.planning/REQUIREMENTS.md`, `lib/sigra/data_export.ex`, generated schema templates] |
| EXP-02 | Operator can inspect explicit omission notes when optional export schemas are not configured, so partial exports are truthful instead of silent. | Keep every optional section key present with an empty value and emit omission entries for `session_schema`, `identity_schema`, `audit_schema`, `mfa_credential_schema`, `user_passkey_schema`, `backup_code_schema`, and `membership_schema`. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md`, `lib/sigra/data_export.ex`] |
</phase_requirements>

## Summary

Phase 127 is a library-contract stabilization phase, not a generated-host expansion. `Sigra.DataExport.export_auth_data/3` already returns a versioned map with the intended top-level sections, but current implementation returns raw Ecto schema records for optional sections and only records omissions for audit, organization memberships, and MFA credentials. [VERIFIED: `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`]

The planner should keep `schema_version: 1`, add `account.lifecycle_status` derived from `Sigra.Account.Deletion.status/1`, and replace raw-record returns with explicit section serializers that include only safe fields. Generated templates show which fields are secret-bearing and must not be exported: session `hashed_token`, OAuth encrypted tokens, TOTP `encrypted_secret`, backup-code `hashed_code`, passkey `credential_id`, and passkey `public_key`. [VERIFIED: `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md`, `lib/sigra/account/deletion.ex`, `priv/templates/sigra.install/core/user_session.ex`, `priv/templates/sigra.gen.oauth/user_identity.ex`, `priv/templates/sigra.install/core/user_mfa_credential.ex`, `priv/templates/sigra.install/core/user_backup_code.ex`, `priv/templates/sigra.install/passkeys/user_passkey.ex`]

**Primary recommendation:** Implement curated per-section serializers inside `Sigra.DataExport`, use Ecto `select: map(record, ^fields)` or post-query safe mapping for configured schemas, and extend `test/sigra/data_export_test.exs` to prove stable keys, omission completeness, lifecycle status, and sensitive-field exclusion. [VERIFIED: Context7 `/websites/hexdocs_pm_ecto`, `test/sigra/data_export_test.exs`]

## Project Constraints (from CLAUDE.md)

- Target Phoenix 1.8+ and Ecto 3.x as the blessed path. [VERIFIED: `CLAUDE.md`]
- PostgreSQL is primary; MySQL/SQLite support matters through portable library behavior and conditional migrations. [VERIFIED: `CLAUDE.md`]
- Security-sensitive code stays in the library, while generated host code owns schemas, routes, wrappers, and presentation. [VERIFIED: `CLAUDE.md`]
- Keep dependencies minimal; prefer copy-paste over adding dependencies when code is small and stable. [VERIFIED: `CLAUDE.md`]
- Tests should cover happy path, main error cases, and boundary conditions using flat, self-contained AAA-style tests. [VERIFIED: `CLAUDE.md`]
- `mix test` requires a live PostgreSQL service at `localhost:5432` with `postgres`/`postgres`; the current local service is accepting connections. [VERIFIED: `CLAUDE.md`, `pg_isready`]
- GSD workflow enforcement says direct repo edits should happen through a GSD command unless explicitly bypassed; this file is produced by the requested research workflow. [VERIFIED: `CLAUDE.md`, user objective]
- No project-local skills were found under `.claude/skills` or `.agents/skills`. [VERIFIED: filesystem scan]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Versioned auth export contract | API / Backend library | Generated-host wrappers | `Sigra.DataExport.export_auth_data/3` is the locked owner of the payload shape; generated hosts only pass schemas or thin wrappers. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Account lifecycle truth | API / Backend library | Database / Storage | `Sigra.Account.Deletion.status/1` owns lifecycle interpretation from stored user fields. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Optional-schema degradation | API / Backend library | Generated-host config | Missing schema modules are represented as empty present sections plus omission notes; generated-host code may omit optional schemas. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Safe auth-record serialization | API / Backend library | Database / Storage | The library must curate rows because generated schemas include secret-bearing columns. [VERIFIED: generated schema templates] |
| Export proof | Test suite | — | Existing proof target is `test/sigra/data_export_test.exs`; focused ExUnit is enough for this library contract. [VERIFIED: `127-CONTEXT.md`, `test/sigra/data_export_test.exs`, `mix test test/sigra/data_export_test.exs`] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix / ExUnit | 1.19.5 local | Runtime, build, focused unit tests | Project uses Mix and ExUnit; `mix test` is the CI library-test command. [VERIFIED: `elixir --version`, `mix help test`, `.github/workflows/ci.yml`] |
| Ecto | locked 3.13.5; current Hex line 3.14.0 | Query DSL and schema metadata | Existing implementation imports `Ecto.Query`; Context7 confirms `map/2`, `field/2`, dynamic select maps, and `Repo.aggregate/3` are supported patterns. [VERIFIED: `mix.lock`, `mix hex.info ecto`, Context7 `/websites/hexdocs_pm_ecto`] |
| Ecto SQL | locked 3.13.5; current Hex line 3.14.0 | SQL adapter integration and Postgres test repo | `Sigra.Test.PostgresRepo` uses `Ecto.Adapters.Postgres`; CI library tests run with Postgres. [VERIFIED: `mix.lock`, `mix hex.info ecto_sql`, `test/support/postgres_test_repo.ex`, `.github/workflows/ci.yml`] |
| Postgrex | locked 0.22.0; latest patch 0.22.2 | Postgres adapter for tests | Postgres-backed integration tests rely on `postgrex` in test deps. [VERIFIED: `mix.lock`, `mix hex.info postgrex`, `mix.exs`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Mox | locked 1.2.0 | Behaviour mocks | Existing tests define Mox mocks in `test/test_helper.exs`; Phase 127 likely does not need new Mox mocks unless planners choose a repo behaviour seam. [VERIFIED: `mix.lock`, `test/test_helper.exs`] |
| Credo | 1.7.17 local | Static analysis | Use for optional quality checks after implementation if the touched code grows beyond a narrow test update. [VERIFIED: `mix credo --version`, `mix.exs`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Curated serializers in `Sigra.DataExport` | Raw Ecto structs | Raw structs expose secret-bearing fields and unstable generated schema internals. [VERIFIED: current `fetch_records/3`, generated schema templates, `127-CONTEXT.md`] |
| Focused ExUnit tests | Generated-app smoke or Playwright | Phase 127 changes library payload shape only; generator parity is Phase 129. [VERIFIED: `.planning/ROADMAP.md`, `127-CONTEXT.md`] |
| Ecto select maps | Manual post-query `Map.take/2` only | Ecto `select: map(record, ^fields)` avoids loading unneeded secret columns when a real repo is used; manual mapping remains useful for stubbed repo tests. [CITED: https://hexdocs.pm/ecto/3.14.0/Ecto.Query.API.html#map/2] |

**Installation:** no new packages are required for Phase 127. [VERIFIED: `mix.exs`, current implementation]

**Version verification:** `mix hex.info ecto`, `mix hex.info ecto_sql`, `mix hex.info postgrex`, and `mix hex.info mox` were run on 2026-05-27; locked versions are documented above. [VERIFIED: Hex CLI]

## Architecture Patterns

### System Architecture Diagram

```text
Operator / generated host wrapper
  -> Sigra.DataExport.export_auth_data(repo, user, opts)
     -> version metadata
     -> account serializer
        -> raw user lifecycle fields
        -> Sigra.Account.Deletion.status(user)
     -> optional schema sections
        -> schema present and usable?
           -> query records by user-owned fields
           -> curated safe serializer per section
        -> schema missing or unsupported?
           -> empty present section
           -> omission note
     -> explicit exclusions
        -> backup-code non-export reason
        -> enterprise organization-scoped non-export reason
  -> {:ok, stable versioned map}
```

Data enters through `export_auth_data/3`, is transformed by library-owned serializers, branches on optional schema availability, and exits as a stable map that does not claim host-domain completeness. [VERIFIED: `lib/sigra/data_export.ex`, `127-CONTEXT.md`]

### Recommended Project Structure

```text
lib/sigra/
├── data_export.ex                 # Keep public contract and serializers here for Phase 127
└── account/deletion.ex            # Existing lifecycle status source of truth

test/sigra/
└── data_export_test.exs           # Focused payload shape, omission, and safe-field tests
```

This phase is narrow enough to avoid new modules unless `data_export.ex` becomes hard to scan after serializers are added. [VERIFIED: current file size and phase scope]

### Pattern 1: Curated Section Serializer

**What:** Query or receive optional rows, then return maps containing only documented safe fields. [VERIFIED: generated schema templates]  
**When to use:** Every optional section that can contain auth material. [VERIFIED: `127-CONTEXT.md`]

```elixir
# Source: https://hexdocs.pm/ecto/3.14.0/Ecto.Query.API.html#map/2
safe_fields = [:id, :type, :ip, :user_agent, :last_active_at, :sudo_at, :inserted_at]

from(record in session_schema,
  where: field(record, ^:user_id) == ^user_id,
  select: map(record, ^safe_fields)
)
```

### Pattern 2: Lifecycle State from Existing Deletion Semantics

**What:** Add a derived lifecycle state without reimplementing deletion logic. [VERIFIED: `lib/sigra/account/deletion.ex`]  
**When to use:** In the `account` section of `export_auth_data/3`. [VERIFIED: `127-CONTEXT.md`]

```elixir
# Source: lib/sigra/account/deletion.ex
case Sigra.Account.Deletion.status(user) do
  {:scheduled, days_remaining} -> %{state: :scheduled, days_remaining: days_remaining}
  :deleted -> %{state: :deleted}
  :not_scheduled -> %{state: :not_scheduled}
end
```

### Pattern 3: Explicit Omission Truth

**What:** Keep keys present and add structured or string omission notes for every unavailable optional schema. [VERIFIED: `127-CONTEXT.md`, `.planning/REQUIREMENTS.md`]  
**When to use:** For `session_schema`, `identity_schema`, `audit_schema`, `mfa_credential_schema`, `user_passkey_schema`, `backup_code_schema`, and `membership_schema`. [VERIFIED: `lib/sigra/data_export.ex`, generated schema templates]

```elixir
# Source: lib/sigra/data_export.ex current omissions pattern
[]
|> maybe_add_omission(missing?(:session_schema, opts), "Sessions are omitted because no session schema was provided.")
|> maybe_add_omission(missing?(:identity_schema, opts), "OAuth identities are omitted because no identity schema was provided.")
```

### Anti-Patterns to Avoid

- **Raw struct export:** Returning `repo.all/1` results directly can expose `hashed_token`, encrypted token fields, TOTP secrets, passkey credential material, or backup-code hashes. [VERIFIED: `lib/sigra/data_export.ex`, generated schema templates]
- **Silent optional degradation:** Empty arrays without omission notes violate EXP-02. [VERIFIED: `.planning/REQUIREMENTS.md`, `127-CONTEXT.md`]
- **Schema-key removal:** Removing top-level or nested keys when schemas are missing violates D-07 and D-09. [VERIFIED: `127-CONTEXT.md`]
- **Host policy inference:** Lifecycle output must not claim legal deletion, regulatory completeness, or host-domain data deletion. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `127-CONTEXT.md`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Lifecycle interpretation | New deletion-status logic | `Sigra.Account.Deletion.status/1` | Existing function defines `{:scheduled, days}`, `:deleted`, and `:not_scheduled`. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Query field projection | String SQL or custom SQL builders | Ecto Query `field/2`, `dynamic/2`, and `map/2` | Existing code already uses Ecto Query; docs support dynamic fields and selected maps. [VERIFIED: `lib/sigra/data_export.ex`; CITED: https://hexdocs.pm/ecto/3.14.0/Ecto.Query.html] |
| Backup-code export | Raw backup code or hash export | Count plus non-export reason | Context locks backup codes as summary-only. [VERIFIED: `127-CONTEXT.md`, `priv/templates/sigra.install/core/user_backup_code.ex`] |
| Passkey export | Public-key / credential blob dump | Non-secret passkey metadata summary | Generated passkey schema stores credential material in `credential_id` and encrypted `public_key`. [VERIFIED: `priv/templates/sigra.install/passkeys/user_passkey.ex`] |
| OAuth identity export | Token dump | Provider/account metadata without encrypted tokens | Generated identity schema stores encrypted access and refresh tokens. [VERIFIED: `priv/templates/sigra.gen.oauth/user_identity.ex`] |

**Key insight:** Phase 127's hard part is not querying records; it is preventing the export contract from leaking storage internals or pretending omitted optional schemas were never part of the Sigra-owned surface. [VERIFIED: `127-CONTEXT.md`, generated schema templates]

## Common Pitfalls

### Pitfall 1: Raw Ecto Structs Leak Sensitive Fields
**What goes wrong:** `fetch_records/3` returns full structs for sessions, identities, MFA credentials, passkeys, and memberships. [VERIFIED: `lib/sigra/data_export.ex`]  
**Why it happens:** A generic helper cannot know which fields are safe for each schema. [VERIFIED: generated schema templates]  
**How to avoid:** Replace generic raw fetches with per-section safe serializers. [VERIFIED: `127-CONTEXT.md`]  
**Warning signs:** Tests assert only key presence and do not reject `:hashed_token`, `:encrypted_secret`, `:encrypted_access_token`, `:encrypted_refresh_token`, `:credential_id`, `:public_key`, or `:hashed_code`. [VERIFIED: `test/sigra/data_export_test.exs`, generated schema templates]

### Pitfall 2: Omission Notes Cover Only Some Optional Schemas
**What goes wrong:** Current omissions mention audit, memberships, and MFA credentials only. [VERIFIED: `lib/sigra/data_export.ex`]  
**Why it happens:** Sessions, identities, passkeys, and backup-code schemas already degrade to empty values, so the missing truth surface is easy to miss. [VERIFIED: `lib/sigra/data_export.ex`]  
**How to avoid:** Define a single optional-section inventory and test the exact omitted section names. [VERIFIED: `127-CONTEXT.md`]  
**Warning signs:** `DataExport.export_auth_data(nil, user, [])` returns fewer omission entries than optional schema options. [VERIFIED: `lib/sigra/data_export.ex`]

### Pitfall 3: Lifecycle Status Drift
**What goes wrong:** Export code independently derives scheduled/deleted state and diverges from deletion operations later. [VERIFIED: `127-CONTEXT.md`]  
**Why it happens:** The raw fields are simple enough to invite local conditional duplication. [VERIFIED: `lib/sigra/account/deletion.ex`]  
**How to avoid:** Call `Sigra.Account.Deletion.status/1` and serialize its result. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/account/deletion.ex`]  
**Warning signs:** Data export tests construct lifecycle states without asserting parity with `Deletion.status/1`. [VERIFIED: current `test/sigra/data_export_test.exs`]

### Pitfall 4: Tests Need Configured-Schema Proof, Not Only Nil-Schema Proof
**What goes wrong:** Existing tests cover nil-schema degradation but not configured optional schemas with returned rows. [VERIFIED: `test/sigra/data_export_test.exs`]  
**Why it happens:** Current tests use `repo=nil`, so query paths are not exercised. [VERIFIED: `test/sigra/data_export_test.exs`]  
**How to avoid:** Add in-test Ecto schemas plus a fake repo that records/returns rows, or use `Sigra.Test.PostgresRepo` if query compilation against real Ecto schemas matters. [VERIFIED: `test/support/postgres_test_repo.ex`, `test/test_helper.exs`]  
**Warning signs:** Payload-shape tests pass even if configured schemas still return raw structs. [VERIFIED: current `fetch_records/3` behavior]

## Code Examples

### Safe Field Filtering

```elixir
# Source: https://hexdocs.pm/ecto/3.14.0/Ecto.Query.API.html#map/2
defp fetch_user_maps(repo, schema, user_id, fields) do
  if usable_user_schema?(schema) do
    repo.all(
      from(record in schema,
        where: field(record, ^:user_id) == ^user_id,
        select: map(record, ^fields)
      )
    )
  else
    []
  end
end
```

### Sensitive Field Regression Assertion

```elixir
# Source: generated schema templates listed in 127-CONTEXT.md
refute Map.has_key?(session, :hashed_token)
refute Map.has_key?(identity, :encrypted_access_token)
refute Map.has_key?(identity, :encrypted_refresh_token)
refute Map.has_key?(credential, :encrypted_secret)
refute Map.has_key?(passkey, :credential_id)
refute Map.has_key?(passkey, :public_key)
```

### Omission Inventory Test Shape

```elixir
# Source: .planning/REQUIREMENTS.md EXP-02 and 127-CONTEXT D-07..D-09
assert data.sessions == []
assert data.identities == []
assert data.audit == []
assert data.mfa.credentials == []
assert data.mfa.passkeys == []
assert data.mfa.backup_codes.count == 0
assert data.organizations.memberships == []

for section <- [:sessions, :identities, :audit, :mfa_credentials, :passkeys, :backup_codes, :memberships] do
  assert Enum.any?(data.omissions, &match?(%{section: ^section}, &1))
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw `repo.all/1` records in export sections | Curated, stable section maps | Phase 127 target | Prevents secret-bearing storage fields from becoming public contract. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Partial omission notes | Omission note per unavailable optional Sigra-owned schema | Phase 127 target | Makes partial exports explicit and testable. [VERIFIED: `.planning/REQUIREMENTS.md`, `127-CONTEXT.md`] |
| Raw lifecycle fields only | Raw lifecycle fields plus derived status from `Deletion.status/1` | Phase 127 target | Keeps export truth aligned with account deletion semantics. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/account/deletion.ex`] |

**Deprecated/outdated:**
- Generic `fetch_records/3` as a public-section data source is outdated for credential-related sections because it returns raw structs. [VERIFIED: `lib/sigra/data_export.ex`, generated schema templates]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|

All claims in this research were verified or cited; no user confirmation is needed before planning. [VERIFIED: source list below]

## Open Questions (RESOLVED)

1. **Should omissions be strings or structured maps?**
   - What we know: CONTEXT leaves this to the agent as long as output is explicit and tests pin behavior. [VERIFIED: `127-CONTEXT.md`]
   - What's unclear: Existing implementation uses strings, while structured maps would be easier to test and consume. [VERIFIED: `lib/sigra/data_export.ex`]
   - Recommendation: Use structured maps like `%{section: :sessions, reason: "..."}` unless backward compatibility with string omissions is intentionally preserved. [VERIFIED: current phase discretion]
   - **RESOLVED:** Use structured omission maps with `:section`, `:schema_option`, and `:reason` keys. Phase 127 is a stabilization phase before downstream host parity, and no current tests or documented public examples require string-only omissions. [VERIFIED: `127-01-PLAN.md`, `127-02-PLAN.md`]

2. **Should configured-schema tests use fake repo rows or real Postgres?**
   - What we know: Focused nil-schema tests pass today, and a Postgres test repo is available when needed. [VERIFIED: `mix test test/sigra/data_export_test.exs`, `test/support/postgres_test_repo.ex`]
   - What's unclear: The planner may prefer fake repo tests for speed or Postgres tests for query compilation proof. [VERIFIED: current test suite patterns]
   - Recommendation: Use focused unit tests with in-test schemas and a fake repo for serializer output, plus one Postgres-backed test only if Ecto `select: map/2` query shape needs runtime proof. [VERIFIED: `mix help test`, `test/support/postgres_test_repo.ex`]
   - **RESOLVED:** Use deterministic in-test Ecto schemas plus a fake repo for configured-schema serializer coverage in Phase 127. This keeps the proof focused on payload shape, safe-field allowlists, and omission truth; the full Postgres suite remains the phase-level safety check before verification. [VERIFIED: `127-01-PLAN.md`, `127-VALIDATION.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Build and tests | Yes | 1.19.5 / OTP 28 | None needed. [VERIFIED: `elixir --version`] |
| Mix | Build and tests | Yes | 1.19.5 | None needed. [VERIFIED: `mix --version`] |
| PostgreSQL service | Full root `mix test` and Postgres-backed tests | Yes | Server accepting at `localhost:5432`; `psql` client 14.17 | Focused non-DB `test/sigra/data_export_test.exs` currently runs without DB. [VERIFIED: `pg_isready`, `psql --version`, `mix test test/sigra/data_export_test.exs`] |
| Docker | Postgres fallback startup | Yes | 29.5.2 | Existing local Postgres is already available. [VERIFIED: `docker --version`, `pg_isready`] |
| Context7 CLI fallback | Library documentation lookup | Yes | `ctx7@latest` via `npx` | Official HexDocs pages if CLI fails. [VERIFIED: `npx --yes ctx7@latest library ecto`] |

**Missing dependencies with no fallback:** None found. [VERIFIED: environment audit]

**Missing dependencies with fallback:** None found. [VERIFIED: environment audit]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix 1.19.5. [VERIFIED: `mix help test`, `mix --version`] |
| Config file | `test/test_helper.exs` starts ExUnit; `config/test.exs` configures test Argon2 and mailer settings. [VERIFIED: `test/test_helper.exs`, `config/test.exs`] |
| Quick run command | `mix test test/sigra/data_export_test.exs` [VERIFIED: command run: 4 tests, 0 failures] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: `CLAUDE.md`, `.github/workflows/ci.yml`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| EXP-01 | Configured schemas produce versioned account/auth sections with curated safe fields and lifecycle status. | unit / optional integration | `mix test test/sigra/data_export_test.exs --max-failures 1` | Yes, extend existing file. [VERIFIED: `test/sigra/data_export_test.exs`] |
| EXP-02 | Missing optional schemas leave present empty sections and explicit omission notes for every unavailable optional section. | unit | `mix test test/sigra/data_export_test.exs --max-failures 1` | Yes, extend existing file. [VERIFIED: `test/sigra/data_export_test.exs`] |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/data_export_test.exs --max-failures 1` [VERIFIED: focused command]
- **Per wave merge:** `mix test test/sigra/data_export_test.exs && mix format --check-formatted lib/sigra/data_export.ex test/sigra/data_export_test.exs` [VERIFIED: focused command, formatter command]
- **Phase gate:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` before `/gsd-verify-work`. [VERIFIED: `CLAUDE.md`, `.github/workflows/ci.yml`]

### Wave 0 Gaps

- [ ] Extend `test/sigra/data_export_test.exs` with configured-schema serializer coverage for sessions, identities, audit, MFA credentials, passkeys, backup-code count, and memberships. [VERIFIED: current test file lacks configured-schema row assertions]
- [ ] Add explicit sensitive-field exclusion assertions for each credential-related section. [VERIFIED: generated schema templates]
- [ ] Add omission inventory assertion covering every optional schema option. [VERIFIED: `127-CONTEXT.md`, current omissions helper]
- [ ] Add lifecycle status assertion aligned with `Sigra.Account.Deletion.status/1`. [VERIFIED: `lib/sigra/account/deletion.ex`, current account test]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | Yes | Do not export authentication secrets or replay material. [VERIFIED: generated auth schemas, `127-CONTEXT.md`] |
| V3 Session Management | Yes | Export session metadata only; exclude `hashed_token`. [VERIFIED: `priv/templates/sigra.install/core/user_session.ex`] |
| V4 Access Control | Yes | Keep generated host as thin caller; library owns bounded Sigra export contract. [VERIFIED: `127-CONTEXT.md`] |
| V5 Input Validation | Yes | Validate optional schema usability with `Code.ensure_loaded?`, `function_exported?`, and field checks before querying. [VERIFIED: current `fetch_records/3` pattern] |
| V6 Cryptography | Yes | Never decrypt or export encrypted OAuth, TOTP, or passkey material. [VERIFIED: generated schema templates, `127-CONTEXT.md`] |

### Known Threat Patterns for Sigra Export

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret disclosure through raw struct export | Information Disclosure | Per-section allowlist serializers and tests that reject secret fields. [VERIFIED: generated schema templates] |
| Misleading partial export | Repudiation | Present empty sections plus explicit omission notes for missing schemas. [VERIFIED: EXP-02, `127-CONTEXT.md`] |
| Lifecycle misrepresentation | Repudiation | Derive lifecycle status from `Sigra.Account.Deletion.status/1`. [VERIFIED: `lib/sigra/account/deletion.ex`] |
| Host-domain overclaim | Repudiation | State only Sigra-owned auth/account data; exclude generic BI, SCIM, legal certification, and host-domain data. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/127-versioned-auth-data-export/127-CONTEXT.md` - locked implementation decisions, scope boundary, and canonical references. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - EXP-01 and EXP-02. [VERIFIED: file read]
- `.planning/ROADMAP.md` - Phase 127 goal and success criteria. [VERIFIED: file read]
- `.planning/STATE.md` - active milestone state and planning instruction. [VERIFIED: file read]
- `CLAUDE.md` - project constraints and local test requirements. [VERIFIED: file read]
- `lib/sigra/data_export.ex` - current export contract and omissions implementation. [VERIFIED: file read]
- `test/sigra/data_export_test.exs` - current proof surface. [VERIFIED: file read and focused test run]
- `lib/sigra/account/deletion.ex` - lifecycle status source of truth. [VERIFIED: file read]
- Generated schema templates under `priv/templates/sigra.install` and `priv/templates/sigra.gen.oauth` - safe/secret field inventory. [VERIFIED: file reads]
- Context7 `/websites/hexdocs_pm_ecto` - Ecto `map/2`, dynamic select maps, and `Repo.aggregate/3`. [CITED: https://hexdocs.pm/ecto/3.14.0/Ecto.Query.API.html#map/2]

### Secondary (MEDIUM confidence)

- Hex CLI package metadata for Ecto, Ecto SQL, Postgrex, and Mox versions. [VERIFIED: `mix hex.info`]
- CI workflow commands and Postgres service setup. [VERIFIED: `.github/workflows/ci.yml`]

### Tertiary (LOW confidence)

- None. [VERIFIED: source audit]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Versions and local availability were verified via `mix.lock`, Hex CLI, and local tool probes. [VERIFIED: commands]
- Architecture: HIGH - Phase decisions and current code point to a single implementation target. [VERIFIED: `127-CONTEXT.md`, `lib/sigra/data_export.ex`]
- Pitfalls: HIGH - Pitfalls are directly observable in current code and generated schema fields. [VERIFIED: codebase reads]

**Research date:** 2026-05-27  
**Valid until:** 2026-06-26 for codebase-local findings; re-check HexDocs/Hex versions after 30 days. [VERIFIED: current date and fast-moving dependency cadence]
