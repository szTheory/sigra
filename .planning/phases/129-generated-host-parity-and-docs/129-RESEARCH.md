# Phase 129: Generated Host Parity And Docs - Research

**Researched:** 2026-05-27 [VERIFIED: system date]
**Domain:** Elixir/Phoenix generated host parity, install golden fixtures, and public documentation alignment for Sigra data lifecycle [VERIFIED: `.planning/ROADMAP.md`, `.planning/phases/129-generated-host-parity-and-docs/129-CONTEXT.md`]
**Confidence:** HIGH [VERIFIED: repo code, phase context, Phase 127/128 verification artifacts, Hex package metadata]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Generated Lifecycle Parity
- **D-01:** Generated context wrappers, the example app, and install golden should keep account deletion as thin calls into `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, and `Sigra.Account.deletion_status/1`.
- **D-02:** Generated host code should continue to supply host-specific repo, schema, scope, audit, token, and session context while the library owns enqueue, active-scheduled, stale-worker, and finalization truth.
- **D-03:** Lifecycle UI and copy in generated templates, example app, and golden fixtures must not over-claim hard deletion or permanent removal when the configured strategy is `:soft_delete`.

### Generated Export Boundary
- **D-04:** Phase 129 should add or align only thin generated/example/golden seams for `Sigra.DataExport.export_auth_data/3`, passing repo, user, and configured generated schemas without recreating payload shape in host code.
- **D-05:** The generated export seam must preserve Phase 127 semantics: versioned library-owned payload, stable top-level sections, curated sensitive-field serialization, explicit enterprise exclusion truth, and omission notes for missing optional Sigra-owned schemas.
- **D-06:** Generated host documentation and examples should position `Sigra.DataExport.export_auth_data/3` as Sigra-owned auth/account export that host apps may combine with their own host-domain export, not as a complete application data export.

### Install Golden Contract
- **D-07:** Treat the install golden fixture as generated-host contract evidence that must be updated after template and example parity changes, not as an independent source of behavior.
- **D-08:** Golden output should mirror the current generated wrappers, lifecycle copy, data-export seam, and controller/context naming produced by `mix sigra.install`.

### Documentation Truth Claims
- **D-09:** Docs should explicitly distinguish Sigra-owned auth/account data from host-owned domain data.
- **D-10:** Docs should document omission behavior for optional schemas so operators understand partial exports are explicit rather than silently complete.
- **D-11:** Docs should explain deletion strategy consequences: `:hard_delete` removes the user row subject to host constraints, `:soft_delete` preserves the row and PII while finalizing lifecycle state, and `:anonymize` preserves the row while clearing Sigra-owned PII.
- **D-12:** Docs and generated copy should soften broad phrases such as "all associated data" and unconditional "permanently removed" unless they are scoped to the configured strategy and Sigra-owned data.

### the agent's Discretion
- Exact generated wrapper name and placement, provided it matches existing context style and stays thin over `Sigra.DataExport.export_auth_data/3`.
- Exact documentation structure, provided account lifecycle, audit/auth export, and testing docs cover the required boundary and omission truth.
- Exact tests that pin golden parity, as long as template, example app, and install golden behavior are all represented.

### Folded Todos
None.

### Claude's Discretion
- Exact generated wrapper name and placement, provided it matches existing context style and stays thin over `Sigra.DataExport.export_auth_data/3`.
- Exact documentation structure, provided account lifecycle, audit/auth export, and testing docs cover the required boundary and omission truth.
- Exact tests that pin golden parity, as long as template, example app, and install golden behavior are all represented.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None - analysis stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOST-01 | Generated host templates, example app, and install golden fixture preserve the same export and lifecycle semantics as the library code. [VERIFIED: `.planning/REQUIREMENTS.md`] | Existing lifecycle wrappers already call `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, and `Sigra.Account.deletion_status/1`; planning should add a thin `Sigra.DataExport.export_auth_data/3` wrapper and update generated/example/golden copy that overstates permanent deletion. [VERIFIED: `priv/templates/sigra.install/core/auth.ex`, `test/example/lib/example/accounts.ex`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex`, `lib/sigra/data_export.ex`] |
| DOC-01 | Account lifecycle, audit export, and testing docs explain Sigra-owned data boundaries, host-owned data boundaries, omission behavior, and deletion strategy consequences. [VERIFIED: `.planning/REQUIREMENTS.md`] | `guides/flows/account-lifecycle.md` already lists strategy consequences but docs do not yet explain auth-data export omission behavior or the host-domain boundary; `guides/recipes/testing.md` still says `assert_account_deleted/3` means row gone or anonymized. [VERIFIED: `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`, `guides/recipes/testing.md`] |
</phase_requirements>

## Summary

Phase 129 should be planned as a parity-and-truth pass over generated host surfaces, the example app, the install golden fixture, and docs; it should not change the library-owned export payload or lifecycle semantics. [VERIFIED: `129-CONTEXT.md`, `.planning/ROADMAP.md`, `.planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md`, `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`]

The core lifecycle adapters are already thin in the generated template, example app, and golden fixture: they call `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, and `Sigra.Account.deletion_status/1`. [VERIFIED: `priv/templates/sigra.install/core/auth.ex`, `test/example/lib/example/accounts.ex`, `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex`] The missing generated-host parity is the auth data export seam: no generated/example/golden wrapper currently calls `Sigra.DataExport.export_auth_data/3`. [VERIFIED: `rg -n "export_auth_data|DataExport"` across `priv/templates`, `test/example`, and `test/fixtures/install_golden/tree`]

**Primary recommendation:** Add one thin `export_auth_data(user, opts \\ [])` wrapper to generated `Accounts/Auth` context and mirror it in the example app and install golden, then update deletion/export docs and generated UI/email copy to describe Sigra-owned auth/account data, host-owned domain data, optional-schema omissions, and strategy-specific finalization truth. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`, `guides/flows/account-lifecycle.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Auth/account export payload shape | API / Backend library | Database / Storage | `Sigra.DataExport.export_auth_data/3` owns the versioned payload, safe serializers, omissions, and enterprise exclusion. [VERIFIED: `lib/sigra/data_export.ex`, `.planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md`] |
| Generated export wrapper | API / Backend generated host | API / Backend library | Generated host should pass repo, user, and configured schema modules to `Sigra.DataExport.export_auth_data/3` without rebuilding the payload. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Account deletion schedule/cancel/status | API / Backend library | API / Backend generated host | Library APIs own enqueue, active-scheduled, stale-worker, and finalization truth while generated wrappers provide host config/context. [VERIFIED: `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`, `lib/sigra/auth.ex`, `priv/templates/sigra.install/core/auth.ex`] |
| Generated lifecycle UI/copy | Browser / Client via Phoenix LiveView | API / Backend generated host | LiveViews present lifecycle state and call generated context wrappers; they must phrase deletion truth according to strategy without owning backend semantics. [VERIFIED: `priv/templates/sigra.install/core/settings_live.ex`, `priv/templates/sigra.install/core/reactivation_live.ex`] |
| Install golden contract | Test fixture / CI | Generated host | Golden fixture is regenerated evidence for `mix sigra.install` output and is compared byte-for-byte by the golden diff test. [VERIFIED: `test/sigra/install/golden_diff_test.exs`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex`] |
| Public docs | Documentation | API / Backend library and generated host | Docs must explain the boundary between library-owned Sigra auth/account data and host-owned domain data. [VERIFIED: `129-CONTEXT.md`, `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`] |

## Project Constraints (from CLAUDE.md)

- Target Phoenix 1.8+ and Ecto 3.x as the blessed path; Plug compatibility is secondary where DX is not compromised. [VERIFIED: `CLAUDE.md`]
- PostgreSQL is the primary database target; generator and docs should not add MySQL/SQLite-specific behavior in this phase. [VERIFIED: `CLAUDE.md`, `mix.exs`]
- Security-sensitive and truth-sensitive code belongs in the library; generated code should remain host-owned wrappers, schemas, routes, and presentation. [VERIFIED: `CLAUDE.md`, `129-CONTEXT.md`]
- Keep dependencies minimal; Phase 129 needs no new dependency. [VERIFIED: `CLAUDE.md`, `mix.exs`]
- Tests should be comprehensive, flat, self-contained, and cover happy path, main errors, and boundaries. [VERIFIED: `CLAUDE.md`, `test/sigra/templates/settings_live_test.exs`, `test/sigra/install/golden_diff_test.exs`]
- `mix test` requires a live Postgres at `localhost:5432` with `postgres`/`postgres`; this machine currently reports `localhost:5432` accepting connections. [VERIFIED: `CLAUDE.md`, `pg_isready`]
- GSD workflow guidance says direct repo edits should happen through a GSD workflow; this research artifact is part of the requested GSD phase workflow. [VERIFIED: `CLAUDE.md`, user objective]
- No project skills exist under `.claude/skills/` or `.agents/skills/`; only `.claude/settings.local.json` was found. [VERIFIED: `find .claude .agents -maxdepth 3 -type f`]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir / Mix | Local 1.19.5 on OTP 28; project minimum `~> 1.18` | Runtime, template compilation, tests, docs tasks | Existing project is an Elixir library and all relevant generator/test commands are Mix tasks. [VERIFIED: `elixir --version`, `mix --version`, `mix.exs`] |
| Phoenix | Locked 1.8.5; latest Hex 1.8.7 on 2026-05-27 | Generated host and LiveView target | Generated templates are Phoenix/Phoenix LiveView modules and the project targets Phoenix 1.8+. [VERIFIED: `mix deps`, `mix hex.info phoenix`, `priv/templates/sigra.install/core/settings_live.ex`] |
| Ecto / Ecto SQL | Locked 3.13.5; latest Hex Ecto 3.14.0 on 2026-05-27 | Generated schemas and repo-backed export queries | `Sigra.DataExport.export_auth_data/3` queries configured generated schemas through Ecto.Query. [VERIFIED: `mix deps`, `mix hex.info ecto`, `lib/sigra/data_export.ex`] |
| Oban | Locked 2.21.1; latest Hex 2.22.1 on 2026-05-27 | Optional lifecycle worker execution | Account deletion lifecycle worker semantics were pinned in Phase 128 and generated docs/copy must describe them truthfully. [VERIFIED: `mix deps`, `mix hex.info oban`, `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`] |
| ExUnit | Bundled with Elixir 1.19.5 | Template, docs, and golden parity tests | Existing parity proof uses ExUnit test files under `test/sigra/templates` and `test/sigra/install`. [VERIFIED: `elixir --version`, `test/sigra/templates/settings_live_test.exs`, `test/sigra/install/golden_diff_test.exs`] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Mox | Locked 1.2.0; latest Hex 1.2.0 | Existing unit-test mock support | Use only if planner adds focused generated-wrapper unit tests that need fake repo behavior. [VERIFIED: `mix deps`, `mix hex.info mox`, `test/test_helper.exs`] |
| ExDoc | Locked 0.40.1 | Public docs build | Use for docs verification if Phase 129 edits guide files or public module docs. [VERIFIED: `mix deps`, `mix.exs`] |
| `mix sigra.fixture.rebless_golden` | Local project Mix task | Regenerate install golden fixture | Use after template changes, then review `git diff test/fixtures/install_golden/` and run golden diff tests. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Thin generated `export_auth_data/2` wrapper | Generated payload-building module | Rejected by D-04/D-05 because generated host must not own payload shape or sensitive-field serialization. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Manual edits to golden fixture only | Rebless via `MIX_ENV=test mix sigra.fixture.rebless_golden` | Manual edits risk drift from `mix sigra.install`; rebless uses the same install fixture harness as golden tests. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `test/sigra/install/golden_diff_test.exs`] |
| New compliance guide | Update existing account lifecycle, audit logging, and testing docs | Existing docs are already part of ExDoc extras and Phase 129 only needs bounded truth alignment. [VERIFIED: `mix.exs`, `129-CONTEXT.md`] |

**Installation:**
```bash
# No new packages are recommended for Phase 129.
mix deps.get
```

**Version verification:** `mix deps`, `mix hex.info phoenix`, `mix hex.info ecto`, `mix hex.info oban`, `mix hex.info mox`, and `elixir --version` were run on 2026-05-27. [VERIFIED: command output]

## Architecture Patterns

### System Architecture Diagram

```text
Operator/developer asks for user auth export
  -> generated host context wrapper: export_auth_data(user, opts)
  -> supplies Repo + generated schema modules + caller opts
  -> Sigra.DataExport.export_auth_data(repo, user, opts)
       -> account lifecycle from user fields + Sigra.Account.Deletion.status/1
       -> optional section queries through configured schemas
       -> safe field allowlists for sessions, identities, audit, MFA, passkeys, memberships
       -> backup code summary only
       -> enterprise connection explicit exclusion
       -> omission notes for missing optional schema opts
  -> host app may combine returned Sigra-owned payload with host-domain export

User schedules/cancels account deletion
  -> generated SettingsLive/ReactivationLive
  -> generated context wrapper
  -> Sigra.Auth.schedule_deletion/3 or cancel_deletion/3
  -> Sigra.Account + Sigra.Account.Deletion library contract
       -> Phase 128 active-scheduled and finalization truth
  -> generated UI/email/docs describe strategy-specific consequence
```

### Recommended Project Structure

```text
priv/templates/sigra.install/
├── core/auth.ex                  # Add thin export_auth_data wrapper near lifecycle helpers
├── core/settings_live.ex         # Soften broad deletion copy
├── core/reactivation_live.ex     # Soften permanent-removal copy
└── core/emails.ex                # Soften finalized deletion email copy

test/example/
├── lib/example/accounts.ex       # Mirror generated export wrapper with impersonation style intact
├── lib/example_web/live/*.ex     # Mirror user-facing lifecycle copy
└── lib/example/accounts/emails.ex # Mirror generated email copy

test/fixtures/install_golden/
└── tree/                         # Regenerated output after template changes

guides/
├── flows/account-lifecycle.md    # Strategy consequences and Sigra/host data boundary
├── flows/audit-logging.md        # Auth/account export boundary and omissions
└── recipes/testing.md            # Helper truth for hard/soft/anonymize deletion
```

### Pattern 1: Thin Generated Export Wrapper

**What:** Add a generated context function that passes `repo`, `user`, and configured generated schemas into `Sigra.DataExport.export_auth_data/3`. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`]

**When to use:** Use when generated host code needs a public convenience seam for Sigra-owned auth/account export. [VERIFIED: `129-CONTEXT.md`]

**Example:**
```elixir
# Source pattern: lib/sigra/data_export.ex plus priv/templates/sigra.install/core/auth.ex
def export_auth_data(user, opts \\ []) do
  Sigra.DataExport.export_auth_data(
    Repo,
    user,
    Keyword.merge(
      [
        session_schema: UserSession,
        audit_schema: AuditEvent,
        mfa_credential_schema: UserMfaCredential,
        backup_code_schema: UserBackupCode
      ],
      opts
    )
  )
end
```

### Pattern 2: Generated Lifecycle Wrappers Stay Thin

**What:** Keep generated lifecycle functions as pass-throughs to `Sigra.Auth` and `Sigra.Account`. [VERIFIED: `priv/templates/sigra.install/core/auth.ex`, `test/example/lib/example/accounts.ex`]

**When to use:** Use for schedule, cancel, and status calls; do not duplicate active-scheduled checks or finalization strategy logic in LiveViews. [VERIFIED: `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`, `129-CONTEXT.md`]

**Example:**
```elixir
# Source: priv/templates/sigra.install/core/auth.ex
def deletion_status(user) do
  Sigra.Account.deletion_status(user)
end
```

### Pattern 3: Golden Is Regenerated Evidence

**What:** Template changes should flow into `test/fixtures/install_golden/tree/` via the fixture rebless task, then `golden_diff_test.exs` proves generated output matches the committed fixture. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `test/sigra/install/golden_diff_test.exs`]

**When to use:** Use after changing any `priv/templates/sigra.install/**` file that should affect `mix sigra.install` output. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`]

**Example:**
```bash
# Source: lib/mix/tasks/sigra.fixture.rebless_golden.ex
MIX_ENV=test mix sigra.fixture.rebless_golden
MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs
```

### Anti-Patterns to Avoid

- **Generated payload ownership:** Do not serialize sessions, identities, audit rows, MFA, passkeys, backup codes, organizations, or omissions in generated host code. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`]
- **Overbroad deletion copy:** Do not say "all associated data" or unconditional "permanently removed" unless scoped to hard-delete or to configured strategy behavior. [VERIFIED: `129-CONTEXT.md`, `priv/templates/sigra.install/core/settings_live.ex`, `priv/templates/sigra.install/core/reactivation_live.ex`, `priv/templates/sigra.install/core/emails.ex`]
- **Golden as source of truth:** Do not manually invent golden behavior; golden output mirrors templates and example parity. [VERIFIED: `129-CONTEXT.md`, `test/sigra/install/golden_diff_test.exs`]
- **Compliance overreach:** Do not imply Sigra exports all application data or satisfies legal/regulatory deletion by itself. [VERIFIED: `.planning/REQUIREMENTS.md`, `129-CONTEXT.md`, `lib/sigra/data_export.ex`] 

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auth/account export payload | Generated export serializer or controller-local map builder | `Sigra.DataExport.export_auth_data/3` | Library function already owns versioning, stable sections, safe serializers, omission notes, lifecycle status, and enterprise exclusion. [VERIFIED: `lib/sigra/data_export.ex`, `.planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md`] |
| Account deletion lifecycle truth | LiveView/controller checks for deletion state | `Sigra.Auth.schedule_deletion/3`, `Sigra.Auth.cancel_deletion/3`, `Sigra.Account.deletion_status/1` | Phase 128 pinned enqueue, active-scheduled, stale-worker, and soft-delete finalization semantics in library tests. [VERIFIED: `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`] |
| Golden fixture update | Manual fixture-only edits | `MIX_ENV=test mix sigra.fixture.rebless_golden` | The task regenerates from a fresh tmp app and reports fixture deltas. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`] |
| Deletion strategy documentation | Generic "deleted" wording | Strategy-specific hard/soft/anonymize language | Strategies have different row/PII consequences and docs must not collapse them. [VERIFIED: `guides/flows/account-lifecycle.md`, `129-CONTEXT.md`] |

**Key insight:** Phase 129 is about adapter parity and user/operator truth, not new data-lifecycle behavior. [VERIFIED: `.planning/ROADMAP.md`, `129-CONTEXT.md`]

## Common Pitfalls

### Pitfall 1: Export Wrapper Recreates Payload Shape

**What goes wrong:** Generated code builds its own export map or filters sensitive fields locally. [VERIFIED: `129-CONTEXT.md`]
**Why it happens:** A context wrapper can look like the natural place to combine schemas and data. [ASSUMED]
**How to avoid:** The wrapper should call `Sigra.DataExport.export_auth_data/3` directly and only supply repo/schema opts. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`]
**Warning signs:** New generated code mentions `:hashed_token`, `:encrypted_secret`, passkey credential fields, or `omissions` construction. [VERIFIED: `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`]

### Pitfall 2: Optional Schemas Look Like Missing Data

**What goes wrong:** Operators see empty sections and assume the export is complete. [VERIFIED: `.planning/REQUIREMENTS.md`, `lib/sigra/data_export.ex`]
**Why it happens:** Optional generated schemas may be absent when features are not installed. [VERIFIED: `lib/sigra/data_export.ex`, `priv/templates/sigra.install/core/auth.ex`]
**How to avoid:** Docs must explain `omissions` as explicit partial-export truth for missing optional Sigra-owned schemas. [VERIFIED: `.planning/REQUIREMENTS.md`, `129-CONTEXT.md`]
**Warning signs:** Docs show export examples without mentioning `omissions` or optional schema configuration. [VERIFIED: `guides/flows/audit-logging.md`, `guides/flows/account-lifecycle.md`]

### Pitfall 3: Soft Delete Is Described As Permanent Removal

**What goes wrong:** Generated UI/email or docs tell users their data is permanently removed even though `:soft_delete` preserves the user row and PII. [VERIFIED: `priv/templates/sigra.install/core/settings_live.ex`, `priv/templates/sigra.install/core/reactivation_live.ex`, `priv/templates/sigra.install/core/emails.ex`, `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`]
**Why it happens:** The same user-facing copy is reused across all deletion strategies. [VERIFIED: `priv/templates/sigra.install/core/settings_live.ex`, `priv/templates/sigra.install/core/emails.ex`]
**How to avoid:** Use strategy-neutral wording in generated UI and document exact strategy consequences in guides. [VERIFIED: `129-CONTEXT.md`, `guides/flows/account-lifecycle.md`]
**Warning signs:** Phrases like "all associated data" and "permanently removed" in generated settings, reactivation, email, example, or golden files. [VERIFIED: `rg -n "all associated data|permanently removed"`]

### Pitfall 4: Golden Fixture Drift

**What goes wrong:** Templates change but golden output remains stale, or fixture-only edits mask installer output drift. [VERIFIED: `test/sigra/install/golden_diff_test.exs`]
**Why it happens:** Golden fixture is a committed tree that must be regenerated after template changes. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`]
**How to avoid:** Rebless after template changes and run the golden diff test plus the existing `mix ci.install_golden` alias if time permits. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `mix.exs`]
**Warning signs:** `git diff` shows template changes without matching `test/fixtures/install_golden/tree/` changes. [VERIFIED: `test/sigra/install/golden_diff_test.exs`]

## Code Examples

### Existing Library Export Contract

```elixir
# Source: lib/sigra/data_export.ex
@spec export_auth_data(module(), struct(), keyword()) :: {:ok, map()}
def export_auth_data(repo, user, opts \\ []) do
  # returns schema_version, exported_at, account, sessions, identities,
  # audit, mfa, organizations, enterprise, and omissions
end
```

### Existing Lifecycle Wrapper Pattern

```elixir
# Source: priv/templates/sigra.install/core/auth.ex
def schedule_deletion(user, opts \\ []) do
  Sigra.Auth.schedule_deletion(sigra_config(), user,
    Keyword.merge(
      [
        changeset_fn: &User.deletion_changeset/2,
        user_token_schema: UserToken,
        session_store: Sigra.SessionStores.Ecto
      ],
      opts
    )
  )
end
```

### Existing Golden Rebless Contract

```bash
# Source: lib/mix/tasks/sigra.fixture.rebless_golden.ex
MIX_ENV=test mix sigra.fixture.rebless_golden --check
MIX_ENV=test mix sigra.fixture.rebless_golden
MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Export behavior only as a behaviour callback example | Library-owned `Sigra.DataExport.export_auth_data/3` with versioned Sigra-owned payload | Phase 127, completed 2026-05-27 | Generated host should add a thin wrapper rather than invent payload behavior. [VERIFIED: `.planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md`] |
| Deletion copy can say permanent removal generally | Strategy-specific truth: hard-delete removes row, soft-delete preserves row/PII, anonymize preserves row while clearing Sigra-owned PII | Phase 128 context and proof, completed 2026-05-27 | Generated UI/email/docs must avoid unconditional permanent-removal claims. [VERIFIED: `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`, `129-CONTEXT.md`] |
| Golden fixture as a static historical baseline | Golden fixture as regenerated contract evidence for current generated behavior | Existing local task and Phase 129 D-07/D-08 | Planner should include explicit rebless and golden diff verification. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `129-CONTEXT.md`] |

**Deprecated/outdated:**
- Generated and example copy saying "all associated data" or unconditional "permanently removed" is outdated for `:soft_delete` truth. [VERIFIED: `priv/templates/sigra.install/core/settings_live.ex`, `priv/templates/sigra.install/core/reactivation_live.ex`, `priv/templates/sigra.install/core/emails.ex`, `129-CONTEXT.md`]
- `guides/recipes/testing.md` saying `assert_account_deleted/3` means row gone or anonymized is incomplete for the row-preserving `:soft_delete` finalization truth. [VERIFIED: `guides/recipes/testing.md`, `lib/sigra/testing.ex`, `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A generated wrapper can naturally live in the existing generated Accounts/Auth context near lifecycle helpers. [ASSUMED] | Common Pitfalls / Pattern 1 | If planner chooses a different file, tests and docs must still prove a thin generated seam exists. |
| A2 | No new dependency is needed for Phase 129. [ASSUMED] | Standard Stack | If implementation discovers a docs or fixture tool gap, planner may need an environment/setup task, but current repo has required tools. |

## Open Questions

1. **Should docs add a new dedicated data-export guide or update current guides only?**
   - What we know: Context gives discretion on exact documentation structure and names account lifecycle, audit/auth export, and testing docs as required coverage. [VERIFIED: `129-CONTEXT.md`]
   - What's unclear: Whether a standalone guide improves discoverability enough to justify another ExDoc extra. [ASSUMED]
   - Recommendation: Update existing `account-lifecycle`, `audit-logging`, and `testing` guides first; add cross-links from getting-started only if the edits become hard to discover. [VERIFIED: `mix.exs`, `129-CONTEXT.md`]

2. **Should `lib/sigra/testing.ex` behavior change or only its docs?**
   - What we know: `assert_account_deleted/3` currently accepts absent row or anonymized email, while Phase 129 specifically names docs and generated parity. [VERIFIED: `lib/sigra/testing.ex`, `.planning/ROADMAP.md`]
   - What's unclear: Whether changing helper semantics belongs in Phase 129 or Phase 130 proof. [ASSUMED]
   - Recommendation: Plan doc truth first; change helper behavior only if tests/docs need a strategy-aware helper to avoid false claims. [VERIFIED: `guides/recipes/testing.md`, `129-CONTEXT.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | Mix tasks and tests | yes | 1.19.5 on OTP 28 | None needed. [VERIFIED: `elixir --version`] |
| Mix | `mix test`, `mix format`, golden rebless task | yes | 1.19.5 | None needed. [VERIFIED: `mix --version`] |
| PostgreSQL server | Full root test suite and install/idempotency tests if they hit DB setup | yes | `localhost:5432` accepting connections | Unit/template tests can run without full DB, but full suite needs Postgres. [VERIFIED: `pg_isready`, `CLAUDE.md`] |
| psql CLI | Manual DB inspection if needed | yes | 14.17 | Use Ecto tests if unavailable. [VERIFIED: `psql --version`] |
| Docker | Starting disposable Postgres if local DB stops | yes | 29.5.2 | Existing Postgres is available. [VERIFIED: `docker --version`, `pg_isready`] |
| Network/Hex | Version metadata verification | yes | Hex queries succeeded | Use locked `mix.lock` if offline. [VERIFIED: `mix hex.info phoenix`, `mix hex.info ecto`, `mix hex.info oban`, `mix hex.info mox`] |

**Missing dependencies with no fallback:**
- None found for Phase 129 planning. [VERIFIED: environment probes]

**Missing dependencies with fallback:**
- None found. [VERIFIED: environment probes]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with project Mix aliases; Mox exists for unit mocks. [VERIFIED: `mix.exs`, `test/test_helper.exs`] |
| Config file | `mix.exs`, `test/test_helper.exs`, and example subproject `test/example/mix.exs` for example-app tests. [VERIFIED: `mix.exs`, `test/test_helper.exs`, `test/example/mix.exs`] |
| Quick run command | `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` [VERIFIED: files exist] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| HOST-01 | Generated template, example app, and golden fixture expose the same thin export wrapper and lifecycle semantics. [VERIFIED: `.planning/REQUIREMENTS.md`] | template unit + example compile/test + golden integration | `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/golden_diff_test.exs --max-failures 1` plus targeted example tests if wrapper tests are added. [VERIFIED: `test/sigra/templates/settings_live_test.exs`, `test/sigra/install/golden_diff_test.exs`] | Existing files yes; export-wrapper assertions need new/expanded tests. [VERIFIED: `rg -n "export_auth_data|DataExport"`] |
| DOC-01 | Docs explain Sigra-owned/host-owned boundaries, omissions, and deletion strategy consequences. [VERIFIED: `.planning/REQUIREMENTS.md`] | docs grep / ExDoc build / focused guide tests | `mix docs` or targeted docs grep tests if project has existing guide checks. [VERIFIED: `mix.exs`, `test/sigra/guides_dx02_test.exs`] | Guide files yes; specific assertions likely need updates. [VERIFIED: `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`, `guides/recipes/testing.md`] |

### Sampling Rate

- **Per task commit:** Run the focused file(s) touched, plus `mix format --check-formatted` on changed `.ex`/`.exs` files. [VERIFIED: `mix.exs`, existing project pattern]
- **Per wave merge:** `mix test test/sigra/templates/settings_live_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs test/sigra/data_export_test.exs test/sigra/account/deletion_test.exs test/sigra/workers/account_deletion_test.exs --max-failures 1`. [VERIFIED: files exist, `mix.exs` alias includes golden/idempotency]
- **Phase gate:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` before `/gsd-verify-work`. [VERIFIED: `CLAUDE.md`, Phase 128 full-suite evidence]

### Wave 0 Gaps

- [ ] Add template assertions that `priv/templates/sigra.install/core/auth.ex` contains `export_auth_data` and `Sigra.DataExport.export_auth_data` without payload-shape construction. [VERIFIED: `test/sigra/templates/settings_live_test.exs`, `priv/templates/sigra.install/core/auth.ex`]
- [ ] Add or update assertions preventing broad generated deletion copy such as "all associated data" and unconditional "permanently removed" in templates. [VERIFIED: `test/sigra/templates/settings_live_test.exs`, `rg -n "all associated data|permanently removed"`]
- [ ] Rebless and verify install golden after template changes. [VERIFIED: `lib/mix/tasks/sigra.fixture.rebless_golden.ex`, `test/sigra/install/golden_diff_test.exs`]
- [ ] Add docs verification, either through existing guide tests or focused grep tests, for Sigra-owned/host-owned boundary and omission behavior. [VERIFIED: `test/sigra/guides_dx02_test.exs`, `guides/flows/audit-logging.md`]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | yes | Generated host stays on `Sigra.Auth` lifecycle APIs and does not duplicate auth state logic. [VERIFIED: `priv/templates/sigra.install/core/auth.ex`, `lib/sigra/auth.ex`] |
| V3 Session Management | yes | Schedule deletion continues to revoke sessions/tokens through library-owned lifecycle behavior; generated docs/copy should not alter it. [VERIFIED: `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md`, `lib/sigra/account/deletion.ex`] |
| V4 Access Control | yes | Example app keeps impersonation guard around sensitive deletion operations; export wrapper planning should preserve any existing host guard style if exposed in admin/user UI later. [VERIFIED: `test/example/lib/example/accounts.ex`, `test/example/test/example_web/impersonation_blocked_ops_test.exs`] |
| V5 Input Validation | yes | Export wrapper should pass typed repo/schema modules and user struct to library code; docs should avoid encouraging arbitrary host data export without validation. [VERIFIED: `lib/sigra/data_export.ex`, `129-CONTEXT.md`] |
| V6 Cryptography | yes | Do not export replay-relevant or secret-bearing fields; use `Sigra.DataExport.export_auth_data/3` allowlists instead of generated serializers. [VERIFIED: `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`] |

### Known Threat Patterns for Generated Host Export/Lifecycle

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret-bearing auth data exposure in generated export | Information Disclosure | Delegate to `Sigra.DataExport.export_auth_data/3` safe serializers and do not hand-roll payloads. [VERIFIED: `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`] |
| Misleading deletion copy causes operator/user trust failure | Repudiation / Information Disclosure | Strategy-specific docs and generated copy that distinguish hard-delete, soft-delete, and anonymize. [VERIFIED: `129-CONTEXT.md`, `guides/flows/account-lifecycle.md`] |
| Host-domain export overclaim | Information Disclosure / Compliance risk | State that Sigra export covers Sigra-owned auth/account data and host apps own domain-data export/retention. [VERIFIED: `.planning/REQUIREMENTS.md`, `129-CONTEXT.md`, `lib/sigra/data_export.ex`] |
| Optional schema omissions hidden from operators | Repudiation | Document and test explicit `omissions` returned by library export. [VERIFIED: `lib/sigra/data_export.ex`, `test/sigra/data_export_test.exs`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/129-generated-host-parity-and-docs/129-CONTEXT.md` - locked Phase 129 decisions, generated-host and docs scope. [VERIFIED]
- `.planning/REQUIREMENTS.md` - `HOST-01` and `DOC-01` requirements. [VERIFIED]
- `.planning/ROADMAP.md` - Phase 129 scope, dependency on Phase 128, and success criteria. [VERIFIED]
- `.planning/phases/127-versioned-auth-data-export/127-VERIFICATION.md` - completed export payload contract proof. [VERIFIED]
- `.planning/phases/128-account-deletion-lifecycle-truth/128-01-SUMMARY.md` - completed lifecycle truth proof. [VERIFIED]
- `lib/sigra/data_export.ex` - library-owned export contract. [VERIFIED]
- `priv/templates/sigra.install/core/auth.ex`, `settings_live.ex`, `reactivation_live.ex`, `emails.ex` - generated host surfaces. [VERIFIED]
- `test/example/lib/example/accounts.ex`, `test/example/lib/example_web/live/reactivation_live.ex`, `test/example/lib/example/accounts/emails.ex` - example app surfaces. [VERIFIED]
- `test/fixtures/install_golden/tree/` - generated output fixture. [VERIFIED]
- `test/sigra/install/golden_diff_test.exs` and `lib/mix/tasks/sigra.fixture.rebless_golden.ex` - golden parity workflow. [VERIFIED]
- `mix hex.info phoenix`, `mix hex.info ecto`, `mix hex.info oban`, `mix hex.info mox` - package version metadata. [VERIFIED]

### Secondary (MEDIUM confidence)

- HexDocs URLs for package docs if planner needs API references: `https://hexdocs.pm/ecto/`, `https://hexdocs.pm/phoenix/`, `https://hexdocs.pm/oban/Oban.Worker.html`, `https://hexdocs.pm/ex_unit/`. [CITED]

### Tertiary (LOW confidence)

- None. [VERIFIED: no unverified web-search-only claims used]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions verified from local lock/deps and Hex metadata; no new dependency recommended. [VERIFIED: `mix deps`, `mix hex.info ...`]
- Architecture: HIGH - generated/library boundary is locked by Phase 129 context and verified in current code. [VERIFIED: `129-CONTEXT.md`, `lib/sigra/data_export.ex`, `priv/templates/sigra.install/core/auth.ex`]
- Pitfalls: HIGH - current repo contains the exact overbroad copy and missing export seam the phase must address. [VERIFIED: `rg -n "all associated data|permanently removed|export_auth_data|DataExport"`]

**Research date:** 2026-05-27 [VERIFIED: system date]
**Valid until:** 2026-06-26 for internal architecture; re-check Hex versions after 30 days if dependency-sensitive planning occurs. [ASSUMED]
