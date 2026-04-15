# Phase 12: Scope + Session Foundation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 12 is a **mechanical data-shape extension** that gives every downstream phase (14 Org Plugs, 16 Org LiveViews, v1.2 Impersonation) the fields they need to pattern-match on without attaching any business logic. Three surfaces change:

1. **`%Sigra.Session{}`** (library struct, `lib/sigra/session.ex`) gains a first-class `:active_organization_id` field.
2. **`<%= context_module %>.Scope`** (generated template, `priv/templates/sigra.install/core/scope.ex`) gains three additive fields: `:active_organization`, `:membership`, `:impersonating_from` — all default `nil`. `for_user/1` and `new/1` remain arity-1.
3. **`user_sessions`** table (generated migration) gains a nullable `active_organization_id :binary_id` column, delivered as a **separate `ALTER TABLE` migration** via a new `:active_org_column` slot in `Sigra.Install.Features.Core.migrations/1`. The Phase 11 `:primary` migration template stays byte-identical.

**In scope:**
- `Sigra.Session` struct + `@type` extension; `SessionStore` behaviour impls round-trip the new field.
- Generated `Scope` template extension + typespec; reserved-field discipline mechanism for `:impersonating_from`.
- Generated `UserSession` Ecto schema gains `field :active_organization_id, :binary_id`.
- New `:active_org_column` feature-manifest slot + new migration template `add_active_organization_id_to_user_sessions.exs`.
- Library-side invariant test asserting the reserved `:impersonating_from` field is present in the rendered Scope template.
- End-to-end serialization round-trip test: write `active_organization_id` via `Sigra.Session`, read via `Plug.Conn.get_session/2`.
- Golden-diff fixture gets a new file (the ALTER migration) added — Phase 11 files stay byte-identical.

**Out of scope (belongs in later phases):**
- Population / hydration of `%Scope{active_organization: ...}` — Phase 14.
- `Organization` and `Membership` schemas — Phase 13.
- Active-org rotation on switch — Phase 16.
- Any `:impersonating_from` population — v1.2.
- `mix sigra.upgrade --backfill-personal-orgs` — Phase 18 (may reuse the same `add_active_organization_id_to_user_sessions.exs` template).
- `Sigra.Session` API for `:impersonating_from` — v1.2 lands this additively.

</domain>

<decisions>
## Implementation Decisions

### Migration Shape (ORG-SCOPE-02)

- **D-01:** **New `:active_org_column` migration slot.** `Sigra.Install.Features.Core.migrations/1` gains a new slot between `:primary` and `:api_token` that emits a **standalone ALTER migration file**, `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs`, with a single `alter table(:user_sessions) do add :active_organization_id, :binary_id end` change. The Phase 11 `:primary` migration template stays **byte-identical** to what Phase 11 shipped — Phase 12 does not edit `migration.exs`.

  **Why:** (a) Phase 18's `mix sigra.upgrade --backfill-personal-orgs` must emit this exact column addition for v1.0 installs, and it can reuse this template verbatim — one canonical definition of "the active_organization_id migration" across fresh-install and upgrade codepaths. (b) `alter table ... add :col, :binary_id` is dialect-agnostic in Ecto, so the single template file works for PostgreSQL, MySQL, and SQLite without branching — whereas editing the `:primary` template would require 3× DB-dialect branch edits in `migration.exs`. (c) Phase 11's byte-identity invariant stays clean: the Phase 11 golden-diff fixture for `migration.exs` does not need re-baselining. (d) Matches the idiomatic Elixir library pattern (Oban `Oban.Migrations.up(version: N)`, Dashbit's "never edit released migrations" guidance).

- **D-02:** **Feature-manifest ordering.** The new slot lands between `:primary` and `:api_token`. The `Sigra.Install.Feature` behaviour uses **3-tuples** `{slot, template_relpath, target_basename}` (not 2-tuples — the original draft here was a typo, corrected 2026-04-11 after Phase 12 research verified the actual `migrations/1` return shape in `lib/sigra/install/features/core.ex`):

  ```elixir
  def migrations(_binding) do
    [
      {:primary, "core/migration.exs", "create_sigra_auth_tables.exs"},
      {:active_org_column,
       "core/add_active_organization_id_to_user_sessions.exs",
       "add_active_organization_id_to_user_sessions.exs"},
      {:api_token, "core/api_token_migration.exs", "create_user_api_tokens.exs"},
      {:audit_events, "core/create_audit_events.exs", "create_audit_events.exs"}
    ]
  end
  ```

  Fresh install emits **4 migration files** instead of 3. `Sigra.Install.MigrationTimestamps.allocate/2` (Phase 11 D-04) handles the timestamp sequence automatically — slots are assigned sequential offsets in manifest order. The new slot must also be added to the parallel `base_files/1` list (Phase 11's inlining pattern for byte-identity with the monolith) — see 12-RESEARCH.md for the exact insert point.

- **D-03:** **No index in Phase 12.** The column is added nullable with no index. Phase 18 (`Features.Organizations`) or Phase 14 (Org Plugs) adds the FK reference + index when they ship the `organizations` table. ORG-SCOPE-02 is data-shape only.

### `Sigra.Session` Library Struct (ORG-SCOPE-02 write path)

- **D-04:** **First-class `:active_organization_id` field on `%Sigra.Session{}`.** The library struct in `lib/sigra/session.ex` gains the field directly — not via a metadata map. Sigra v1.1 is the Organizations milestone; the library is org-aware in v1.1+. Carrying a nullable `active_organization_id :: binary() | nil` on the session struct matches principle-of-least-surprise (1:1 with the DB column and the generated `UserSession` schema field), gives Dialyzer full visibility, and keeps pattern matching flat at Phase 14 / Phase 16 call sites.

  ```elixir
  defstruct [
    :id,
    :user_id,
    :token,
    :hashed_token,
    :type,
    :ip,
    :user_agent,
    :parsed_ua,
    :geo_city,
    :geo_country_code,
    :last_active_at,
    :sudo_at,
    :active_organization_id,  # NEW — Phase 12
    :inserted_at
  ]

  @type t :: %__MODULE__{
          # ... existing fields unchanged ...
          active_organization_id: binary() | nil,
          inserted_at: DateTime.t() | nil
        }
  ```

- **D-05:** **No dedicated setter function.** `Sigra.Session.put_active_organization_id/2` is **not** added in Phase 12. Callers use Elixir's native struct-update syntax (`%{session | active_organization_id: org_id}`). Adding a named setter is premature abstraction — Phase 14 can add one if it has three or more call sites that benefit from it.

- **D-06:** **`SessionStore` behaviour impls round-trip the new field.** Every existing `Sigra.SessionStore` implementation (currently `Sigra.SessionStores.*`) must map the struct field to/from the `user_sessions.active_organization_id` column. This is additive — no behaviour callback changes.

- **D-07:** **v1.2 `:impersonating_from` lands on `%Sigra.Session{}` additively** in v1.2. Phase 12 does not reserve a field for it on the session struct (only on the generated `Scope` template, per D-09). The session struct and the scope struct are distinct — the session carries the persisted pointer; the scope carries the hydrated per-request view.

### Generated `Scope` Template (ORG-SCOPE-01)

- **D-08:** **Pure additive defstruct, arity-1 constructors unchanged.** Per the [Phoenix 1.8 scopes guide](https://hexdocs.pm/phoenix/scopes.html), the template extends `defstruct` with three nil-default fields and leaves `for_user/1` and `new/1` signatures untouched. Phase 14 lands a `put_active_organization/2` helper following the Phoenix guide's `put_organization/2` precedent.

  ```elixir
  defstruct user: nil,
            active_organization: nil,
            membership: nil,
            # Reserved for v1.2 impersonation. Do not remove — see UPGRADE-v1.2.md.
            impersonating_from: nil

  @type t :: %__MODULE__{
          user: %<%= schema_alias %>{} | nil,
          active_organization: struct() | nil,
          membership: struct() | nil,
          impersonating_from: %<%= schema_alias %>{} | nil
        }
  ```

- **D-09:** **Typespec uses `struct() | nil` for `:active_organization` and `:membership` in v1.1.** Phase 13 ships `Organization` and `Membership` schemas and tightens the typespec to `%<%= context_module %>.Organization{} | nil` and `%<%= context_module %>.Membership{} | nil` in the same commit that introduces those modules. Using `struct() | nil` in Phase 12 is honest — the modules literally do not exist yet — and avoids a forward reference that would break generator template compilation.

- **D-10:** **`:impersonating_from` is typed as `%<%= schema_alias %>{} | nil`** (i.e., a user struct). v1.2 impersonation carries the *acting* user's identity in the scope; the user schema is the right type.

### Reserved-Field Discipline for `:impersonating_from`

- **D-11:** **Enforcement = doc comment (A) + library-side invariant test (C). Skip belt-and-suspenders golden-diff reliance (D).** Three mechanisms work together — one for humans, one for CI, and the existing Phase 11 golden-diff as general drift detection (not specifically relied on for this invariant).

  **Doc comment (A)** — an inline `# Reserved for v1.2 impersonation. Do not remove — see UPGRADE-v1.2.md.` comment above the `defstruct` line in the template, plus a `@moduledoc` paragraph explaining the reserved field. Zero cost, human-readable courtesy.

  **Library-side invariant test (C)** — new file `test/sigra/install/scope_template_invariants_test.exs`. Two assertions:
  1. **Source-level grep** — reads the template file and regexes for `impersonating_from: nil` in the `defstruct` line. Catches the mutation at the template layer with a loud failure message naming `UPGRADE-v1.2.md`.
  2. **Compile-and-introspect** — evaluates the EEx template with test bindings, compiles the rendered Elixir, and asserts `:impersonating_from in Map.keys(rendered_struct.__struct__())`. Catches cases where the field is renamed or moved out of the `defstruct` via refactoring that the regex might miss.

  Both assertions point at `UPGRADE-v1.2.md` in their failure messages so a future contributor immediately understands what they're breaking.

- **D-12:** **`UPGRADE-v1.2.md` is created in Phase 12** as a short doc explaining the v1.1 → v1.2 upgrade contract: reserved fields, what they're for, why they cannot be removed. This doc is the single referenced target from D-11 failure messages and from the `@moduledoc` annotation. Phase 12 ships a skeleton; v1.2 fills in the actual migration steps.

- **D-13:** **Phase 11 golden-diff is NOT relied on for this invariant.** The golden-diff is a review-dependent signal — a contributor deleting the field would regenerate the fixture and the diff would slip past review. D-11's test (C) fails first with a clear reason, which is strictly more useful. The golden-diff stays in place for general template drift detection; it is just not the enforcement mechanism for the reserved field.

### Verification

- **D-14:** **End-to-end serialization round-trip test** (Success Criterion #3). A test boots a fresh generated app (or reuses the Phase 10.1.1 smoke fixture), logs a user in, writes `active_organization_id` onto the session via `Sigra.Session`, persists via the `SessionStore` behaviour, reloads, and asserts the value round-trips. The test also reads the value back via `Plug.Conn.get_session/2` at the web layer to prove the fresh-install Phoenix session + DB row stay consistent.

  **D-14 clarification (2026-04-11, post-research):** "Pipeline survives new field" interpretation. `active_organization_id` lives on the DB row (`user_sessions.active_organization_id`), not in the Plug session cookie. The test proves: (a) login works unchanged, (b) the `%Sigra.Session{}` struct carries `active_organization_id` end-to-end through the `SessionStore` behaviour, (c) `Plug.Conn.get_session/2` still returns the `:user_token` cookie value unchanged — i.e., the Phase 12 additions do NOT break the existing Phoenix session pipeline. Phase 12 does **not** extend `Plug.FetchSession` to stash `active_organization_id` in the cookie itself; that stays out of scope for v1.1 (may change in a later phase).

- **D-15:** **Golden-diff fixture update.** Phase 11's `test/fixtures/install_golden/` gains the new `add_active_organization_id_to_user_sessions.exs` file; the Phase 11 `migration.exs` fixture stays byte-identical. The Phase 11 CI golden-diff test should pass with zero changes to existing fixture files.

- **D-16:** **Compile-without-warnings check** (Success Criterion #1). The generated `user_auth.ex` (and any other file that pattern-matches on `%Scope{}`) must compile with no unused-variable warnings when matched against `%Scope{active_organization: _, membership: _, impersonating_from: _}`. Add a boot-time test that compiles the generated app and asserts warnings are zero.

### Claude's Discretion

- **CD-01:** **Exact attribute name for the library session struct field.** `:active_organization_id` is the chosen name (matches the DB column and the generated schema). Planner may not rename.

- **CD-02:** **`UPGRADE-v1.2.md` format.** Short markdown — two or three sections: "Reserved fields in v1.1", "v1.2 population contract", "If you need to remove a reserved field". Planner picks concrete wording.

- **CD-03:** **Test module naming.** `Sigra.Install.ScopeTemplateInvariantsTest` is suggestive. Planner may rename as long as the file lives under `test/sigra/install/` and the test function names make the invariant clear.

- **CD-04:** **Whether `SessionStore` test doubles need updating vs. the real impls covering the round-trip.** If the real SessionStore impls have strong test coverage, extending them may be sufficient; if a test double needs the new field, planner adds it.

### Folded Todos

None — no pending todos matched Phase 12 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` line 29 — **ORG-SCOPE-01**: `%Scope{}` gains `:active_organization`, `:membership`, reserved `:impersonating_from`. Source of D-08, D-09, D-10.
- `.planning/REQUIREMENTS.md` line 30 — **ORG-SCOPE-02**: `user_sessions.active_organization_id` nullable column. Source of D-01, D-04.
- `.planning/ROADMAP.md` Phase 12 entry (lines 68–78) — goal, depends-on Phase 11, success criteria, v1.2 load-bearing note. Source of the "mechanical data-shape extension, zero business logic" constraint.

### Architecture & Pattern (from Phase 11)
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` D-01 through D-08 — the `Sigra.Install.Feature` behaviour contract, migration slot pattern (D-04), byte-identity CI gate (D-08). Phase 12 extends the manifest via D-02 in this file without touching Phase 11's `:primary` template.
- `.planning/phases/11-generator-feature-system/11-CONTEXT.md` §canonical_refs — the full reference list from Phase 11 still applies; Phase 12 inherits it.
- `.planning/research/ARCHITECTURE.md` §C1 (subdirectory + feature manifest) — hybrid pattern; Phase 12 is the first consumer that extends the manifest after Phase 11 established it.

### Pitfalls
- `.planning/research/PITFALLS.md` §X-2 (migration ordering) — D-01's slot-based allocator (inherited from Phase 11 D-04) addresses this. Phase 12's new slot sits at a deterministic position in the manifest.
- `.planning/research/PITFALLS.md` §O-5 (cross-org session confusion setup) and §O-6 (stale pointer prep) — Phase 12 lays the data shape these pitfalls will be addressed against in Phase 14; the column being nullable is the first step in the O-6 "silently reset to nil" strategy.

### Phoenix 1.8 Precedent
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) — authoritative pattern for extending `%Scope{}` with `defstruct` + a `put_*/2` setter. Source of D-08 and D-09. Phase 14 will follow the `put_organization/2` precedent verbatim.
- [mix phx.gen.auth — Phoenix v1.8.5](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html) — generated Scope module shape. Sigra's generated Scope matches this.

### OSS Library Precedent
- [Oban Installation](https://hexdocs.pm/oban/installation.html) and [Oban v2.11 upgrade guide](https://hexdocs.pm/oban/v2-11.html) — versioned migration pattern (`Oban.Migrations.up(version: N)`) is the canonical Elixir precedent for D-01.
- [Dashbit: Automatic and manual Ecto migrations](https://dashbit.co/blog/automatic-and-manual-ecto-migrations) — "never edit released migrations, layer ALTERs" guidance. Source for the D-01 rationale.
- [fly-apps/safe-ecto-migrations](https://github.com/fly-apps/safe-ecto-migrations) — safe column addition patterns.

### Existing Code to Modify
- `lib/sigra/session.ex` (78 lines) — the struct getting the new `:active_organization_id` field. D-04.
- `lib/sigra/session_store.ex` and `lib/sigra/session_stores/*.ex` — behaviour + impls that round-trip the new field. D-06.
- `priv/templates/sigra.install/core/scope.ex` (38 lines) — template getting the defstruct extension. D-08.
- `priv/templates/sigra.install/core/user_session.ex` (35 lines) — generated Ecto schema getting a new `field :active_organization_id, :binary_id`.
- `priv/templates/sigra.install/core/migration.exs` (~250 lines) — **NOT edited** (invariant per D-01); Phase 12 adds a new sibling template file alongside.
- `lib/sigra/install/features/core.ex` — `migrations/1` gets the new slot. D-02.

### Files to Create
- `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` — new migration template. D-01.
- `test/sigra/install/scope_template_invariants_test.exs` — library-side reserved-field invariant test. D-11.
- `UPGRADE-v1.2.md` (project root) — reserved-field upgrade contract doc. D-12.
- New golden-diff fixture file for the ALTER migration. D-15.

### v1.2 Direction
- `.planning/v1.2-DIRECTION.md` — dormant but referenced. `:impersonating_from` populates here; D-11's failure messages cite `UPGRADE-v1.2.md` which references this file.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Install.Feature` behaviour + `Features.Core`** (from Phase 11) — extended in D-02 by adding one slot to the `migrations/1` return. Zero edits to the behaviour contract.
- **`Sigra.Install.MigrationTimestamps.allocate/2`** (Phase 11 D-04) — automatically assigns a timestamp to the new `:active_org_column` slot in manifest order. No changes needed.
- **`Sigra.Install.Injector`** (Phase 11 D-02) — not used in Phase 12 (no new injections).
- **`Sigra.SessionStore` behaviour** — extended transparently: impls round-trip one more field, no callback signature changes.
- **Phase 10.1.1 smoke harness** — the serialization round-trip test (D-14) reuses the existing fresh-install smoke fixture.

### Established Patterns
- **`mix sigra.install` migration emission via feature slots** (Phase 11 D-04) — Phase 12 is the first phase to exercise the "add a new slot to an existing feature" pattern. If this works cleanly, Phases 13+ inherit the same shape for free.
- **Generated file ownership** (Sigra philosophy) — the `Scope` template is host-owned once generated. D-11's enforcement is library-side, not host-side; host apps that edit their own Scope are Phase 18 upgrade-task territory.
- **`defstruct` field ordering** — existing `Sigra.Session` struct orders fields roughly by semantic group (identity → token → type → metadata → timestamps). New field `:active_organization_id` slots between `:sudo_at` (auth state) and `:inserted_at` (timestamp) — scope-pointer feels closer to auth state than to pure timestamps.

### Integration Points
- `lib/sigra/install/features/core.ex` — one-line edit: new tuple in `migrations/1`.
- `lib/sigra/session.ex` — two edits: `defstruct` + `@type t`.
- `priv/templates/sigra.install/core/scope.ex` — three edits: `defstruct` extension, `@type t` extension, reserved-field comment.
- `priv/templates/sigra.install/core/user_session.ex` — one new `field/2` line.
- `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs` — new file.
- `test/sigra/install/scope_template_invariants_test.exs` — new file.
- `test/fixtures/install_golden/` — one new fixture file (the ALTER migration), existing files unchanged.
- `UPGRADE-v1.2.md` — new doc at project root.

### Creative Options
- None. Phase 12 is deliberately narrow — any "creative" extension belongs in Phase 14+.

</code_context>

<specifics>
## Specific Ideas

- **v1.1 library is org-aware.** The earlier "library has no concept of organizations" framing came from the v1.0 era, before the 2026-04-11 scope split that moved Organizations into v1.1 Foundations. D-04's rec (first-class `:active_organization_id` field on `Sigra.Session`) is explicitly grounded in this corrected framing. See also `.claude/projects/-Users-jon-projects-sigra/memory/project_v1_1_org_aware.md` (memory entry written during this discussion).

- **Reserved-field discipline favors correctness over minimalism.** Sigra's simplicity principle forbids building for *hypothetical* futures, but v1.2 is *planned*, *documented*, and load-bearing — not hypothetical. One 30-LOC test (D-11) that names the contract and fires loud on deletion is engineering, not over-engineering. Belt-and-suspenders (adding D on top of A+C) was explicitly rejected as cost without signal.

- **Phase 18's `mix sigra.upgrade` reuses the D-01 migration template verbatim.** This is the load-bearing reason Option B beat Option A for the migration shape question. When Phase 18 lands, it imports the same `.exs` template file that Phase 12 ships — zero duplication, zero drift risk.

- **Phase 13 tightens typespecs.** D-09 explicitly defers the `struct() | nil → %Organization{} | nil` tightening to Phase 13. Downstream planners should know this is a one-line template edit, not an API change.

</specifics>

<deferred>
## Deferred Ideas

- **`Sigra.Session.put_active_organization_id/2` setter function** (D-05) — deferred until Phase 14 if three or more call sites benefit. For Phase 12, Elixir's struct-update syntax is sufficient.

- **`Scope.hydrate/2` or `Scope.put_active_organization/2` helper** — lands in Phase 14 following the Phoenix 1.8 `put_organization/2` precedent. Phase 12 ships the defstruct; Phase 14 ships the setter.

- **Index on `user_sessions.active_organization_id`** (D-03) — Phase 14 or Phase 18 adds this when the `organizations` table exists and cross-tenant queries need indexing.

- **`:impersonating_from` field on `Sigra.Session`** (D-07) — v1.2 adds this additively. The scope has the reserved field in v1.1 (D-08, D-10); the session struct does not.

- **`Sigra.Session.put_metadata/3` / metadata map extensibility** — rejected in favor of first-class fields (D-04 rationale). If a future phase needs host-extensible session state for something other than auth core, revisit then.

- **Removing the Phase 11 golden-diff for this invariant** (D-13) — keep it in place for general drift detection; just do not rely on it as the reserved-field enforcement mechanism. The library-side invariant test (D-11) is the authoritative signal.

</deferred>

---

*Phase: 12-scope-session-foundation*
*Context gathered: 2026-04-11*
