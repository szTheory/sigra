# Phase 13: Organizations Schemas + Context - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 13 delivers the complete data layer for organizations: schemas, queries, context functions, and safety guards. It is the first phase to use the **library-first architecture** — a philosophy shift from v1.0's fat-generated-context pattern. Security-critical logic lives in the library (`Sigra.Organizations.*`), updated via `mix deps.update`. The generated wrapper module is thin (~50-80 lines): config + optional hooks.

**In scope:**
- `Organization`, `OrganizationMembership`, `OrganizationInvitation` Ecto schemas (generated, app-owned)
- `Sigra.Organizations` library context with all CRUD operations and safety guards
- `Sigra.Organizations.Query.for_org/2` tenant-scoping helper (raises on missing `:organization_id`)
- `Sigra.Organizations.Callbacks` behaviour for hook extension points
- `Sigra.Hooks` runtime registry for external lib integration (e.g., Accrue payments)
- `Sigra.Install.Features.Organizations` feature-manifest module with one migration slot
- `prepare_query/3` tenant enforcement helper in the library (generated Repo delegates to it)
- Reserved slug validation (~25 hardcoded words + configurable additions)
- Last-owner guard via `FOR UPDATE` lock inside `Ecto.Multi`
- Soft-delete for organizations (`deleted_at` field, explicit query filtering)
- Audit call sites via existing `Sigra.Audit.log_safe/2` (Phase 15 upgrades them)
- Scope template typespec tightening (`struct() | nil` → `%Organization{} | nil`)
- NimbleOptions config schema for `use Sigra.Organizations`
- ~28 tests (20 unit + 8 integration)

**Out of scope (belongs in later phases):**
- Plug hydration of `%Scope{active_organization: ...}` — Phase 14
- `Sigra.Plug.LoadActiveOrganization`, `RequireMembership` — Phase 14
- Audit `organization_id` + `effective_user_id` real columns — Phase 15
- LiveViews (switcher, settings, members) — Phase 16
- Invitation flow logic (HMAC, email, accept/reject, rate limiting) — Phase 17
- `--no-organizations` generator flag + backfill migration — Phase 18
- Hard-delete path — v1.2 admin territory
- Revisiting v1.0 Auth context API surface — future milestone

</domain>

<decisions>
## Implementation Decisions

### Architecture: Library-First Model (Philosophy Shift)

- **D-01:** **Library owns CRUD logic + safety guards. Generated wrapper is thin.** This is a deliberate shift from v1.0's fat-generated-context pattern. Sigra's value prop is being more than phx.gen.auth — the library should *manage* organizations, not *generate code that manages* organizations. Security patches land via `mix deps.update`, not generator re-runs.

  The rule across all v1.1+ features:
  - **Library** = security logic, persistence logic, audit emission, token machinery
  - **Generated (app-owned)** = schemas, migrations, LiveViews, templates, email content
  - **Generated (thin wiring)** = `use Sigra.Organizations` wrapper module, router plug injections

  **Why:** Pow died trying to be both a library AND a generator with unclear boundaries. Sigra avoids this by having a crisp boundary: the `use` macro is the delegation point. Everything above it (app code calling the wrapper) is app-owned. Everything below it (library functions) is Sigra-owned.

- **D-02:** **`use Sigra.Organizations` macro (~40 LOC).** Injects:
  1. Config stored as `@sigra_org_config` module attribute (validated by NimbleOptions at compile time)
  2. Thin delegator functions (each one line, calling `Sigra.Organizations.*` with stored config)
  3. `defoverridable` hook callbacks with no-op defaults
  4. `@behaviour Sigra.Organizations.Callbacks` for Dialyzer checking

  The macro does NOT inject schema fields, imports, or compile-time dependencies on app modules. Host app's generated wrapper is ~10 lines unless hooks are added.

- **D-03:** **NimbleOptions config schema.** Required: `repo`, `schemas` (organization, membership, invitation, user, scope). Configurable with defaults: `roles` (default `[:owner, :admin, :member]`), `owner_role` (default `:owner`), `reserved_slugs` (~25 defaults), `additional_reserved_slugs` (empty, additive), `slug_format` (regex), `slug_length` (3..63), `enforce_org_scope` (additional app schemas for prepare_query enforcement).

### Two-Layer Hook System

- **D-04:** **Layer 1: Module callbacks (local customization).** `defoverridable` functions in the generated wrapper. Developer overrides only what they need:

  | Hook | Args | Can modify? | Use case |
  |------|------|-------------|----------|
  | `before_create_organization/2` | changeset, scope | Changeset | Add validation, set fields |
  | `after_create_organization/2` | org, scope | Read-only | Create related records |
  | `before_delete_organization/2` | org, scope | Can abort | Check billing state |
  | `after_delete_organization/2` | org, scope | Read-only | Cancel subscriptions |
  | `before_add_member/4` | org, user, role, scope | Can abort | Check seat limits |
  | `after_add_member/3` | membership, org, scope | Read-only | Update seat counts |
  | `before_role_change/3` | membership, role, scope | Can abort | Billing role checks |
  | `after_member_remove/2` | membership, scope | Read-only | Revoke external access |

  All hooks run inside `Ecto.Multi`. Returning `{:error, reason}` aborts the transaction.

- **D-05:** **Layer 2: Runtime hook registry (external lib integration).** `Sigra.Hooks` module backed by persistent_term. External libs (e.g., Accrue for billing) register hooks at `Application.start/2` — zero generated code changes needed:
  ```elixir
  Sigra.Hooks.register(:organization, :after_create,
    {Accrue.Integrations.Sigra, :provision_billing}, priority: 100)
  ```
  Hooks execute in priority order within the same `Ecto.Multi`. First hook error aborts the entire transaction. Multiple hooks on the same stage run in registration order within the same priority.

### Organization Schema

- **D-06:** **Minimal schema: name, slug, deleted_at, timestamps.** Auth lib owns identity; devs own profile. No description, logo_url, settings, or metadata columns. Phase 16 can add fields via ALTER migration (proven Phase 12 pattern). The library context functions need `name` (display), `slug` (routing), `deleted_at` (soft-delete) — nothing else.

- **D-07:** **Slug: citext column, `^[a-z][a-z0-9-]*[a-z0-9]$`, 3–63 chars.** Citext provides DB-level case insensitivity (extension already required for emails). Changeset also validates lowercase-only (belt-and-suspenders). Auto-generation from name: `String.downcase |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")`.

- **D-08:** **~25 hardcoded reserved slugs, extensible by host app.** Library default list:
  ```
  admin api app auth billing blog cdn dashboard docs help login logout
  new oauth register settings signup static status support system webhooks www
  ```
  Host app adds via `additional_reserved_slugs:` config (additive, can't accidentally drop library defaults). Every reserved word has a regression test.

- **D-09:** **Partial unique index for slug reclamation after soft-delete.** `WHERE deleted_at IS NULL` allows reuse of deleted org slugs. PostgreSQL-native; MySQL/SQLite fallback uses composite approach. Migration template is adapter-branched (matching v1.0 pattern for email citext).

### Membership Schema

- **D-10:** **Minimal: org_id, user_id, role (Ecto.Enum), timestamps.** `Ecto.Enum` with values from config (default `[:owner, :admin, :member]`). Surrogate `id` primary key (not composite). Unique index on `[:user_id, :organization_id]`. No `invited_by_id` or `accepted_at` — Phase 17 can ALTER if needed.

- **D-11:** **Hard-delete on member removal.** Row is deleted, not soft-deleted. Prevents "rejoin with stale elevated permissions." The audit event captures the removal; the join table row itself has no audit trail. Simplifies unique constraint (no partial index needed).

### Invitation Schema

- **D-12:** **Full schema ships in Phase 13, zero flow logic.** Fields: email, role (Ecto.Enum), hashed_token (binary), accepted_at, revoked_at, expires_at, belongs_to organization/invited_by/accepted_by. Status derived from timestamps (pending = both nil, accepted = accepted_at set, revoked = revoked_at set). No explicit status enum — avoids dual-state bugs. Phase 17 adds HMAC generation, email delivery, accept/reject flow.

  Partial unique index on `[:organization_id, :email]` where `accepted_at IS NULL AND revoked_at IS NULL` — prevents duplicate pending invites to same email per org.

### Tenant Scoping

- **D-13:** **`for_org/2`: runtime raise, pure function.** Accepts `%Scope{}` (pattern matches `active_organization.id`) or raw binary `org_id`. Calls `Ecto.Queryable.to_query/1`, inspects schema via `__schema__(:fields)`, raises `ArgumentError` if `:organization_id` missing. Returns standard `%Ecto.Query{}` — composable with all Ecto query functions. Mirrors `Ecto.assoc/2` error semantics.

  `for_org/2` does NOT auto-filter `deleted_at`. That filter lives in library context functions (`list_organizations_for_user`, `get_organization!`, etc.).

- **D-14:** **`prepare_query/3` enforcement: one-line delegation in generated Repo.** Generated Repo calls `Sigra.Organizations.Query.maybe_enforce_org_scope/4`. Library derives enforced schema list from `use Sigra.Organizations` config (the three org schemas) plus `enforce_org_scope:` config (app schemas). Escape hatch: `Repo.all(query, skip_org_check: true)` for system queries.

### Last-Owner Guard

- **D-15:** **`FOR UPDATE` lock inside `Ecto.Multi`.** Counts owner memberships with `lock("FOR UPDATE")` — concurrent transactions block until the first commits/rolls back. `Multi.run(:guard_last_owner, ...)` returns `{:error, :last_owner}` to abort. Covers three mutation types: remove member, demote owner, self-delete account. Portable: works on PostgreSQL and MySQL; SQLite serializes by default.

- **D-16:** **Multi error normalization.** Library normalizes `{:error, :guard_last_owner, :last_owner, %{}}` to `{:error, :last_owner}` before returning through the thin wrapper. No leaking Multi internals to controllers/LiveViews.

### Soft-Delete

- **D-17:** **Explicit filtering in library context functions, not auto-scope.** `for_org/2` is generic tenant scoping — it doesn't know about org lifecycle. Library context functions (`list_organizations_for_user`, `get_organization!`, `get_organization_by_slug`) include `where: is_nil(o.deleted_at)` explicitly. Hard-delete path deferred to v1.2 admin panel.

  FK cascade strategy:
  - `memberships.organization_id` → `on_delete: :delete_all` (hard-delete cleanup)
  - `invitations.organization_id` → `on_delete: :delete_all`
  - `audit_events.organization_id` → `on_delete: :nilify_all` (audit rows survive)
  - `user_sessions.active_organization_id` → `on_delete: :nilify_all` (stale-pointer → Phase 14)

  Note: Soft-delete (`UPDATE deleted_at`) does NOT trigger FK cascades. These only fire on hard-delete.

### Auto-Owner on Create

- **D-18:** **`create_organization/2` atomically creates org + owner membership in one Multi.** The creating user (from `scope.user`) becomes the owner. No org can exist without at least one owner — this invariant is established at creation and maintained by the last-owner guard (D-15).

### Context API

- **D-19:** **Error handling: mixed returns, standard Elixir pattern.**
  - Changeset validation failure → `{:error, %Ecto.Changeset{}}`
  - Business logic failure → `{:error, :atom_reason}` (`:last_owner`, `:reserved_slug`)
  - Not found → `get_organization!/1` raises `Ecto.NoResultsError`; `get_organization_by_slug/1` returns `nil`

  Pattern-matchable in controllers/LiveViews:
  ```elixir
  case MyApp.Organizations.remove_member(scope, membership) do
    {:ok, _} -> redirect(...)
    {:error, :last_owner} -> put_flash(conn, :error, "Cannot remove last owner")
    {:error, changeset} -> render(:edit, changeset: changeset)
  end
  ```

- **D-20:** **Audit call sites ship in Phase 13 via existing `log_safe/2`.** All context functions include `Sigra.Audit.log_safe()` calls. No-op safe if audit not configured. Phase 15 upgrades call sites with real `organization_id` column + `metadata_from_scope/2`. Matches v1.0 precedent where auth context shipped with audit calls from day one.

### Migration

- **D-21:** **One migration slot in `Sigra.Install.Features.Organizations`.** All 3 tables in one file, FK-ordered (organizations → memberships → invitations). Phase 11's slot allocator assigns timestamp. Phase 18 fills in `files/1`, `injections/1`, `post_instructions/1`.

  Migration template is adapter-branched: PostgreSQL uses `citext` for slug column; MySQL/SQLite use `:string` with application-level lowercase enforcement. Matches v1.0 email column pattern.

  `Features.Organizations` does NOT reference `Features.Core` (Pitfall X-3 isolation).

### Testing

- **D-22:** **~28 tests: 20 unit + 8 integration.**

  Unit tests (Mox, async: true):
  - Context function happy paths + error cases (~8 tests)
  - `for_org/2` raises on wrong schema, accepts Scope and raw ID (~4 tests)
  - Parameterized reserved-slug regression (all ~25 words) (~3 tests)
  - Schema changeset validations (~4 tests)
  - Soft-delete behavior (~2 tests)

  Integration tests (DataCase, real DB):
  - Last-owner guard prevents concurrent removal (real `FOR UPDATE`)
  - Partial unique index allows slug reclamation after soft-delete
  - FK cascades: hard-delete org → memberships cascade, audit nilifies
  - `prepare_query/3` enforcement raises on unscoped queries
  - End-to-end: create org → add member → remove member → verify guard
  - Auto-owner: create org → verify owner membership exists
  - Invitation schema: pending invite uniqueness constraint
  - Soft-deleted org excluded from list queries

  Simple `build_organization/1` helper functions (no ex_machina). AAA style, flat, self-contained.

### Scope Typespec Tightening

- **D-23:** **Phase 13 updates Scope template: `struct() | nil` → real types.** `active_organization: %<%= context_module %>.Organization{} | nil`, `membership: %<%= context_module %>.OrganizationMembership{} | nil`. Unconditional — Phase 18 handles `--no-organizations` conditionality. Golden-diff fixture updated.

### Success Criterion #5 (Credo Check) Resolution

- **D-24:** **`prepare_query/3` replaces the Credo custom-check spike.** Research showed Credo cannot reliably analyze Ecto query structures (AST-level, not runtime-level). `prepare_query/3` (used by EctoTenancyEnforcer in production) inspects the fully-built `%Ecto.Query{}` struct with zero false negatives. This satisfies SC-5's intent (automated tenant-scope enforcement) via a superior mechanism. CONVENTIONS.md entry documents the `prepare_query` pattern + `skip_org_check: true` escape hatch.

### Claude's Discretion

- **CD-01:** Internal struct shapes for `Sigra.Hooks` registry (ETS vs persistent_term, priority ordering implementation).
- **CD-02:** Exact `for_org/2` schema extraction logic (`extract_schema/1` implementation).
- **CD-03:** `Features.Organizations` module structure — whether to stub `files/1`, `injections/1`, `post_instructions/1` as empty lists or leave them unimplemented with `@impl` stubs.
- **CD-04:** Test file organization — exact file names and module naming within the 5 test files.
- **CD-05:** Audit event action names (e.g., `"organization.create"` vs `"organizations.create_organization"`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` lines 18-25 — **ORG-01 through ORG-08**: Organization foundation requirements. Source of D-06 (minimal schema), D-08 (reserved slugs), D-10 (membership), D-15 (last-owner guard), D-17 (soft-delete).
- `.planning/ROADMAP.md` Phase 13 entry (lines 85-97) — goal, depends-on Phase 12, success criteria, pitfalls, v1.2 load-bearing notes.
- `.planning/ROADMAP.md` Phase 14 entry (lines 99-109) — downstream consumer of Phase 13 schemas + context. Plugs are library modules.
- `.planning/ROADMAP.md` Phase 15 entry (lines 112-124) — audit integration upgrades Phase 13's `log_safe` call sites.
- `.planning/ROADMAP.md` Phase 16 entry (lines 126-138) — LiveViews call Phase 13's thin wrapper.
- `.planning/ROADMAP.md` Phase 17 entry (lines 140-152) — invitation flow uses Phase 13's invitation schema.
- `.planning/ROADMAP.md` Phase 18 entry (lines 154-166) — generator wiring uses Phase 13's Features.Organizations.

### Architecture & Pattern
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` — Feature behaviour contract (D-01 through D-08). Phase 13 creates `Features.Organizations` as the second consumer.
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — Scope struct shape (D-08, D-09). Phase 13 tightens typespecs (D-23).
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` D-09 — explicitly defers typespec tightening to Phase 13.
- `.planning/research/ARCHITECTURE.md` §C1 — subdirectory + feature manifest pattern. Phase 13's `Features.Organizations` is the first non-Core feature.
- `.planning/research/ARCHITECTURE.md` §Part D — build order; Phase 13 depends on Phase 12.

### Pitfalls
- `.planning/research/PITFALLS.md` §O-1 — cross-tenant leak. Mitigated by D-13 (`for_org/2` raises) + D-14 (`prepare_query` enforcement).
- `.planning/research/PITFALLS.md` §O-4 — last-owner lockout + admin-deletes-owner escalation. Mitigated by D-15 (`FOR UPDATE` in Multi).
- `.planning/research/PITFALLS.md` §O-9 — slug squatting. Mitigated by D-08 (reserved slugs).
- `.planning/research/PITFALLS.md` §O-10 — cascade wipes audit log. Mitigated by D-17 (`on_delete: :nilify_all` on audit FK).
- `.planning/research/PITFALLS.md` §X-3 — conditional template leakage. `Features.Organizations` must not reference `Features.Core`.

### Existing Code
- `lib/sigra/audit.ex` — `log_safe/2` no-op-safe audit helper. Phase 13 context functions call this (D-20).
- `lib/sigra/session.ex` — `%Sigra.Session{}` with `:active_organization_id` field (Phase 12).
- `lib/sigra/install/features/core.ex` — Phase 11 feature module. Phase 13's `Features.Organizations` follows the same pattern.
- `lib/sigra/install/feature.ex` — `Sigra.Install.Feature` behaviour. Phase 13 implements it.
- `priv/templates/sigra.install/core/scope.ex` — Scope template to update typespecs (D-23).
- `priv/templates/sigra.install/core/migration.exs` — v1.0 migration template (reference for adapter branching pattern).

### Ecosystem References
- [EctoTenancyEnforcer](https://github.com/sb8244/ecto_tenancy_enforcer) — production `prepare_query/3` enforcer. Source of D-14 pattern.
- [Ecto Multi-tenancy with FK guide](https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html) — official Ecto guide for row-based tenancy.
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) — `put_organization/2` precedent (Phase 14).
- [NimbleOptions docs](https://hexdocs.pm/nimble_options/NimbleOptions.html) — config schema validation pattern.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Install.Feature` behaviour** (Phase 11) — `Features.Organizations` implements the same 5 callbacks.
- **`Sigra.Install.MigrationTimestamps.allocate/2`** (Phase 11) — automatically assigns timestamps to the new Organizations slot.
- **`Sigra.Audit.log_safe/2`** — no-op-safe audit helper. Context functions call this for all mutations.
- **`Sigra.Token`** — existing HMAC token infrastructure. Phase 17 reuses for invitation tokens.
- **Phase 10.1.1 smoke harness** — extend with org-related tests.

### Established Patterns
- **Feature-manifest isolation** (Phase 11 X-3) — `Features.Organizations` does not import/reference `Features.Core`.
- **Adapter-branched migrations** (v1.0 `migration.exs`) — PostgreSQL citext vs MySQL/SQLite string. Phase 13 follows for slug column.
- **Slot-based migration ordering** (Phase 11 D-04) — Phase 13 adds one slot to the Organizations feature.
- **Mox-based unit testing** (v1.0 test suite) — mock Repo for async unit tests, real DB for integration.

### Integration Points
- `lib/sigra/install/features/organizations.ex` — new Feature module (Phase 13 creates, Phase 18 completes).
- `priv/templates/sigra.install/organizations/` — new template subdirectory for org schemas + migration.
- `priv/templates/sigra.install/core/scope.ex` — typespec update (D-23).
- Generated Repo module — one-line `prepare_query/3` delegation (D-14).
- Generated wrapper module — `use Sigra.Organizations` (D-02).

</code_context>

<specifics>
## Specific Ideas

- **Library-first is the new default for v1.1+ features.** Organizations uses library-owns-logic + thin wrapper. Passkeys (phases 19-21) should follow the same pattern. v1.0 Auth stays as-is for now — higher customization surface justifies its fat generated context. Earmarked for potential future revisit.

- **Accrue interop is the design validation.** The hook system (D-04/D-05) was designed with Accrue (payments library) as the concrete consumer. Seat-limit checks on `before_add_member`, billing customer creation on `after_create`, subscription cancellation on `after_delete` — these are the canonical use cases. If the hook API can't support these cleanly, it's wrong.

- **`create_organization` = atomic org + owner.** No org can exist without an owner (D-18). This invariant is the foundation for the last-owner guard (D-15). It must be impossible to create an ownerless org through any public API path.

- **`prepare_query` is defense-in-depth, not primary enforcement.** The primary enforcement is `for_org/2` inside library context functions. `prepare_query` catches cases where developers bypass the context and query directly. Both layers together close pitfall O-1.

- **Phase 13 creates `Features.Organizations` with only `migrations/1` populated.** Phase 18 fills in `files/1`, `injections/1`, `post_instructions/1`. This is intentional — the feature module exists early for migration ordering, but template generation is Phase 18's job.

</specifics>

<deferred>
## Deferred Ideas

### Future Milestone: Revisit v1.0 Auth Context API Surface
The library-first model (D-01) may be the right pattern for Auth too. v1.0's generated Auth context is ~760 lines that most developers never customize. Evaluate whether Auth should move to `use Sigra.Auth` with thin wrapper + hooks in a future milestone. **Not a v1.1 concern — Auth works fine as-is. Revisit after v1.1 ships and the Organizations pattern proves out.**

### Future Milestone: Accrue Payments Integration Guide
Write a guide showing how Accrue (payments library) hooks into Sigra's org lifecycle. Concrete examples: seat-based billing, Stripe customer provisioning, subscription management on org delete. **Depends on both Sigra v1.1 and Accrue reaching usable states.**

### Phase 17: `invited_by_id` on Membership
If the members list needs "invited by" display without joining to invitations, Phase 17 can ALTER memberships to add `invited_by_id`. Deferred from Phase 13 (D-10) because the membership schema stays minimal for now.

### Phase 18: `--no-organizations` Scope Template Conditionality
Phase 13 hardcodes `%Organization{} | nil` in the Scope typespec (D-23). Phase 18 introduces the `--no-organizations` flag which needs to conditionally fall back to `struct() | nil`. The binding-flag approach (e.g., `organizations_enabled: true/false`) handles this.

### v1.2: Hard-Delete Path
`Sigra.Organizations.hard_delete/2` gated to admin/operators. Checks `deleted_at <= now - retention_window`. Cascades via FK `on_delete: :delete_all` for memberships/invitations; audit rows survive via `nilify_all`. Not needed for v1.1.

### v1.2: `Sigra.Session.put_active_organization_id/2`
Named setter deferred from Phase 12 D-05. Add if three or more call sites benefit in Phase 14+.

</deferred>

<downstream>
## Downstream Phase Implications

Phase 13's architecture decisions affect phases 14–18. Capturing here so planners don't re-derive:

### Phase 14 (Plugs + Scope Hydration)
- Plugs are **library modules** (`Sigra.Plug.LoadActiveOrganization`, `RequireMembership`). Do not generate them.
- Generated code is router injections only: `plug Sigra.Plug.RequireMembership, roles: [:owner, :admin]`.
- Plugs call library context functions (e.g., `Sigra.Organizations.get_membership/2`) — not the thin wrapper.

### Phase 15 (Audit Integration)
- Library already owns context functions with `log_safe` call sites (D-20). Phase 15 adds real columns and upgrades to `metadata_from_scope/2`.
- All changes are library-side — no generated code edits needed.

### Phase 16 (LiveViews)
- LiveViews are **generated** (app-owned UI). They call the **thin wrapper** (`MyApp.Organizations.create_organization(scope, attrs)`), NOT the library directly.
- This maintains the single indirection layer — hooks fire correctly.

### Phase 17 (Invitations)
- Invitation schema already exists (D-12). Phase 17 adds flow logic to the **library** (`Sigra.Organizations.Invitation.*`).
- HMAC token machinery is security-critical → library-owned.
- Generated code: accept/reject LiveViews + email template.

### Phase 18 (Generator Wiring)
- `Features.Organizations.enabled?/1` gates everything. When false: skips migration, schemas, wrapper, router injections, LiveViews.
- The library module `Sigra.Organizations` always exists (it's a dep). Only the generated artifacts are conditional.

</downstream>

---

*Phase: 13-organizations-schemas-context*
*Context gathered: 2026-04-12*
