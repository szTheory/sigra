# Phase 15: Audit Integration - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 15 plumbs `organization_id` and `effective_user_id` through every Sigra audit emission as **real indexed columns** on `audit_events` — not JSONB metadata — so that v1.2's per-org audit views and admin impersonation dual-actor trail become purely additive filter changes with no schema migration required.

Concretely, the phase delivers:

- Real indexed `organization_id :binary_id` (nullable, FK `on_delete: :nilify_all`) and `effective_user_id :binary_id` (nullable) columns on `audit_events`, added via a standalone ALTER migration for existing v1.0 installs.
- `Sigra.Audit.log_safe/3` as the single public API for library-internal audit emission, with scope as the second positional argument (matching Phoenix 1.8 scopes idiom) and a private `scope_fields/1` duck-typer as the v1.2 impersonation one-line-diff seam.
- A library-side `Sigra.Scope.build/3` constructor used by both login-time scope synthesis and the `Sigra.Workers` behaviour so web and worker call sites look identical.
- A pure `@behaviour Sigra.Workers` contract + `Sigra.Workers.new/3` enqueue validator, with `Sigra.Workers.AccountDeletion` refactored as the reference implementation.
- Extended `Sigra.Audit.Query` with `:organization_id`, `:effective_user_id`, and `:organization_scope` filters; strict whitelist validation (raises on unknown keys — breaking change for v1.0 users who rely on silent-ignore).
- Mechanical sweep of all 79 existing `Sigra.Audit.log_safe/2` call sites in `lib/sigra/**` to the new `/3` form, followed by semantic enrichment of Category 1 (post-auth) sites.
- `Sigra.Credo.NoLogSafe2InLib` custom check that prevents regression of the "one idiom in lib/" property.
- Ordering fix: `session.create` audit now fires **after** `select_active_organization/3` so the very first audit event of a login carries the real `organization_id`.

**In scope:**
- Alter migration template + generator wiring
- `Sigra.Audit.log_safe/3` public API + private `scope_fields/1`
- `Sigra.Scope.build/3` library helper
- `Sigra.Audit.Query` extension (two new filters + tagged-tuple `:organization_scope` filter + whitelist validation)
- Schema + changeset additions (`audit_event.ex` template, `Sigra.Audit.Changeset` `@cast_fields`)
- 79-site mechanical sweep across `lib/sigra/auth.ex`, `mfa.ex`, `account.ex`, `oauth.ex`, `api_token.ex`, `lockout.ex`, `suspicious_login.ex`, `plug/load_active_organization.ex`
- Semantic enrichment of Category 1/2/3 sites (real scope where available, `target_id` for failed-login subject)
- `Sigra.Workers` behaviour + `AccountDeletion` reference refactor
- `Sigra.Credo.NoLogSafe2InLib` custom check
- Index hit-count test for `(organization_id, inserted_at)`
- `assert_audit_logged/2` test helper addition to `Sigra.Testing`
- Generator template + `test/fixtures/install_golden/` + `test/example/` fixture updates
- CHANGELOG entry noting the `session.create` ordering fix and the unknown-filter-key raise as intentional behavior changes

**Out of scope (belongs in later phases or v1.2):**
- `effective_user_id` composite index — deferred to v1.2 when impersonation makes it diverge from `actor_id`
- `Sigra.Audit.Query.for_scope/2` convenience — defer to v1.2 when the admin UI caller exists
- Admin UI, per-org audit views, per-impersonator views — v1.2 "Admin Dashboard" milestone
- `Sigra.Workers` adoption for `AuditCleanup`, `TokenCleanup`, `EmailDelivery` — they are tenant-agnostic or org-aware in v1.2, not v1.1
- `Sigra.Audit.log_multi/3` / `log_multi_safe/3` scope support — v1.1 keeps the multi-variant on the existing opts shape; only `log_safe/3` gains the scope arg (the multi variants currently have zero integration call sites, and changing both doubles review surface for no benefit)
- Cloak-encrypted audit metadata — out of scope; orthogonal
- Cross-database compatibility for `WHERE org_id = ? OR org_id IS NULL` index usage — flagged as a v1.2 concern (partial index or UNION rewrite) with `# TODO(v1.2):` comment

</domain>

<decisions>
## Implementation Decisions

### `Sigra.Audit.log_safe/3` API Shape

- **D-01: `Sigra.Audit.log_safe/3` = `(action, scope_or_nil, opts)` — scope is the second positional argument.** Mirrors Phoenix 1.8 `phx.gen.auth` scopes guide (`fn(scope, ...)` is the canonical shape), Bodyguard/Canada subject-first convention, Ash actor model, and Sentry context pattern. Call sites read as `Audit.log_safe("auth.login.success", scope, repo: ..., audit_schema: ..., metadata: %{...})`. Pre-auth sites pass `nil` explicitly — self-documenting.

- **D-02: `log_safe/2` stays as a thin shim that delegates to `log_safe/3` with `nil` scope.** Backwards-compatible for host apps that called `Sigra.Audit.log_safe/2` directly (which they shouldn't have, but the shim is free). Zero library call sites use the arity-2 form after Phase 15 — enforced by the Credo check.

- **D-03: Private `scope_fields/1` duck-types the scope on `%{user, active_organization, impersonating_from}`.** It does NOT pattern-match on `%Sigra.Scope{}` because `Scope` is generated into the host app, not a library struct. Duck-typing is necessary, not a choice. Nil scope returns `[organization_id: nil, effective_user_id: nil, actor_id: nil]` — explicit nils, not absent keys, so caller-opts-win merge semantics stay consistent and any accidental `NOT NULL` constraint fails fast.

- **D-04: `scope_fields/1` uses `&&` short-circuits on `impersonating_from`, NOT pattern match.** The v1.1 implementation is literally one line: `effective_user_id: user && user.id`. The v1.2 impersonation diff is one additional conditional on the same line: `effective_user_id: (scope.impersonating_from && user.id) || (user && user.id)`. The whole point of the helper existing is to make v1.2 a one-line change in one place.

- **D-05: `scope_fields/1` is and stays PRIVATE.** ROADMAP SC-2 says the helper is "the single assembly point" — it does NOT say it must be public. One public entry point (`log_safe/3`) means one way to do it. Dashbit "one way to do it" principle. `metadata_from_scope/2` as a public name is rejected.

- **D-06: `scope_fields/1` returns a keyword list that is prepended to `opts`, so caller-supplied keys always win on conflict.** Sidesteps the `Keyword.merge` ordering footgun entirely. Verified via grep: zero existing v1.0 call sites pass `:organization_id` or `:effective_user_id` (columns don't exist yet), so the merge direction is safe to lock in now.

- **D-07: Top-level fields, NOT nested in `:metadata`.** `organization_id` and `effective_user_id` land in real indexed columns via `@cast_fields`, not the JSONB `metadata` map. Comment in `build_attrs/4` making this explicit so a future refactor doesn't accidentally flatten them.

- **D-08: `log_multi/3` and `log_multi_safe/3` do NOT gain a scope argument in Phase 15.** They have zero integration call sites today. Updating them doubles the review surface for no benefit. v1.2 can revisit if the admin UI needs multi-variant org-aware emission.

### Migration Strategy + Index Shape

- **D-09: Frozen `create_audit_events.exs` template + standalone `alter_audit_events_add_org_columns.exs` migration.** The create template is treated as a historical artifact — never mutated. Matches phx_gen_auth, pow, and ash_authentication library-migration precedent exactly. Fresh v1.1 installs run both migrations back-to-back (normal and boring); v1.0 users' migration history stays byte-identical.

- **D-10: The alter migration uses `@disable_ddl_transaction true` + `@disable_migration_lock true` + `create index(..., concurrently: true)`.** Safe for v1.0 users with production audit tables (concurrent index creation works fine on empty tables too). One code path for both fresh and upgrade installs. Planner must verify the Sigra adapter-branching system emits non-concurrent index creation for SQLite/MySQL — PostgreSQL-only syntax otherwise.

- **D-11: Index shape = `index(:audit_events, [:organization_id, :inserted_at])` — single composite index.** Exactly parallels the existing `(actor_id, inserted_at)` and `(action, inserted_at)` convention. Postgres does an index range scan and stops at `LIMIT`, no sort node. No `id` tiebreak column (not needed at `LIMIT 50` with `inserted_at` as `utc_datetime_usec`). No partial index (partials are for lopsided distributions, not nullable FKs).

- **D-12: No `effective_user_id` index in v1.1.** In v1.1, `effective_user_id` always equals `actor_id`/`user_id`, so every query is already served by the existing `(actor_id, inserted_at)` composite. Adding an unused index is pure write amplification on an insert-heavy table. v1.2 adds the index in a follow-up migration alongside impersonation. The COLUMN ships in v1.1; only the INDEX is deferred.

- **D-13: FK declaration is explicit: `references(:organizations, type: :binary_id, on_delete: :nilify_all)`.** Without `type: :binary_id`, some adapters silently emit an integer FK. Locked per Phase 13 D-17.

- **D-14: `audit_event.ex` schema template + `Sigra.Audit.Changeset` `@cast_fields` both gain the two new fields unconditionally.** No `--organizations` conditional EEx branching — nullable columns in non-org apps are a rounding error, and conditional branching multiplies the test matrix. One template, one test path.

- **D-15: `Sigra.Audit.Query` extension — three new filters in Phase 15:**
  - `:organization_id` — strict equality; `nil` value means `WHERE organization_id IS NULL`
  - `:effective_user_id` — strict equality; `nil` value means `WHERE effective_user_id IS NULL`
  - `:organization_scope` — tagged-tuple higher-level intent filter: `{:only, org_id}` = strict equality, `{:including_global, org_id}` = `WHERE organization_id = ? OR organization_id IS NULL` (admin view that sees library-emitted events too).
  Also: the existing silent catch-all clause is REMOVED and replaced with an explicit whitelist validator that raises `ArgumentError` on unknown filter keys. This is a breaking change for v1.0 users and must be CHANGELOG'd. Rationale: silently-ignored typos (`actor:` for `actor_id:`) returning unfiltered results is a security-adjacent bug in an audit query.

- **D-16: `Sigra.Audit.Query.for_scope/2` convenience DEFERRED to v1.2.** v1.1 doesn't need it, and we don't know yet what the admin UI wants it to return. Ship when the caller exists.

- **D-17: `# TODO(v1.2):` comment next to `:organization_scope` `:including_global` clause.** Postgres may not use the `(organization_id, inserted_at)` composite index for `WHERE org_id = ? OR org_id IS NULL` — the IS NULL branch can fall off the plan. v1.2 will revisit with a partial index on `WHERE organization_id IS NULL` or a `UNION ALL` rewrite. Out of scope for v1.1 but the technical debt is documented inline.

### `Sigra.Workers` Behaviour

- **D-18: Pure `@behaviour Sigra.Workers` + tiny helper module. No `use` macro.** Mirrors `Phoenix.LiveView.on_mount` and `Plug` — single-callback contracts without injected `use`. Dashbit rule: macros are for *unavoidable* boilerplate; 5 lines of delegation is not unavoidable. AshOban's macro is justified because it generates entire Reactor actions; Sigra isn't generating anything. `lib/sigra/workers.ex` has zero references to Oban and compiles without it.

- **D-19: Callback contract is `@callback perform(scope :: term() | nil, args :: map()) :: :ok | {:ok, term()} | {:error, term()} | {:snooze, pos_integer()}`.** Scope is first positional arg — mirrors `log_safe/3` exactly. One mental model for web and worker call sites.

- **D-20: `Sigra.Workers.new/3` enqueue validator fails fast on missing `organization_id` / `actor_id` keys.** `args` must have the keys present; nil values are allowed (pre-auth jobs have nil actor). Precedent: Oban Pro's `enqueue/1` callback + Ecto changeset "validate at construction" pattern. Belt-and-suspenders: the behaviour wrapper also `Map.fetch!`es at perform time so a hand-built job still fails loudly with a helpful `KeyError`.

- **D-21: Worker scope reconstruction = minimal id-only skeleton using the host's `Scope` struct (not a separate struct type).** Via `Sigra.Scope.build/3` (see D-23). Audit's `scope_fields/1` only reads `.id`, so duck-typing already supports this. Preserves the `log_safe(action, scope, opts)` cohesion between web and worker sites exactly. Worker scopes are **audit-only**; hosts must NOT pass them to authz functions — document loudly in `Sigra.Workers` moduledoc.

- **D-22: `Sigra.Workers.AccountDeletion` is the reference refactor.** ROADMAP says "existing v1.0 worker is refactored... as the reference implementation." `AccountDeletion` is the only worker where a real audit event (`account.deletion_executed`) naturally lands in v1.1 scope, making it the direct template for v1.2 admin-impersonation audits. `EmailDelivery` auditing is v1.2 territory. `AuditCleanup` and `TokenCleanup` are genuinely tenant-agnostic and stay untouched — document the opt-out explicitly in the `Sigra.Workers` moduledoc. Precedent: `Ecto.Multi` isn't used for every transaction, just ones that benefit.

- **D-23: `Sigra.Scope.build/3` is a new library function — `build(scope_module, user, opts)` — that calls `struct(scope_module, user: user, active_organization: opts[:active_organization], membership: opts[:membership], impersonating_from: nil)`.** Used by both the login-time scope synthesis (D-27) AND the worker reference implementation. One helper, two cohesive use cases. Lives in `lib/sigra/scope/` alongside `hydration.ex`.

- **D-24: `AccountDeletion` args gain `"scope_module"`, `"user_schema"`, `"organization_schema"` as stringified module names, resolved via `Module.safe_concat/1` inside `perform/1`.** Matches the existing `"repo"` / `"user_schema"` pattern in the current worker. Oban replays them verbatim on retry — retry safety is inherited from args immutability.

### Call-Site Migration (Two-Plan Split)

- **D-25: Phase 15 is structured as three plans, executed sequentially:**
  - **Plan 15-01** = Schema + helper + mechanical sweep (foundation, pure-mechanical change)
  - **Plan 15-02** = Semantic enrichment + worker refactor (semantic work)
  - **Plan 15-03** = Generator template + fixture updates (install path)
  This maps onto Phase 14's multi-plan precedent (`14-01/14-02/14-03`). The mechanical sweep (Plan 15-01 step N) is a trivially-reviewable `log_safe(action, opts)` → `log_safe(action, nil, opts)` find-and-replace across all 79 sites. Plan 15-02 does the semantic work of replacing those `nil` placeholders with real scopes where they're naturally available.

- **D-26: Failed-login `effective_user_id` is strictly nil; the "event is about this user" signal uses `target_id: user.id`.** OWASP ASVS V7.1 and NIST 800-63B §5.2.2 both say: do NOT record the actor as the claimed identity the system just rejected. Matches Rails `Audited` / `PaperTrail` actor/subject distinction. `target_id` already exists in `@cast_fields` — no new column needed. Document the split in `Sigra.Audit` moduledoc: "`effective_user_id` is the authenticated principal (or v1.2 impersonation target); `target_id` is the subject of the event. They diverge for anonymous-actor events (failed login, magic link request) and for admin actions on other users."

- **D-27: Login-time scope synthesis uses `Sigra.Scope.build/3`, and `session.create` audit is REORDERED to fire AFTER `select_active_organization/3`.** Today `session.create` fires at `lib/sigra/auth.ex:1016` before org selection, so the very first audit event has no org. Phase 15 reorders to emit `session.create` and `auth.login.success` *after* org assignment with the synthesized scope. This is an intentional semantic fix, not just a refactor — flag in CHANGELOG under "Minor behavior changes."

- **D-28: Pre-auth sites with a resolved user pass a user-only scope via `Sigra.Scope.build(scope_module, user, active_organization: nil)`.** Sites: `password_reset_request` with matching email, `magic_link_request` with matching email, `api.token_verify.failure` with resolved user. Also set `target_id: user.id`. Self-documenting: "user known, org unknown." Unresolved-email sites and truly anonymous sites (`security.invalid_credentials`) pass `nil` scope + `target_id: nil`.

- **D-29: Failed-login with unknown email logs IP + User-Agent only — NO email hash in metadata.** A keyed HMAC hash was considered for forensic correlation but rejected: it adds key-management surface for marginal value and a server secret leak creates an enumeration oracle on the historical audit table. Matches `ash_authentication`'s `LogAttempts` shape.

- **D-30: `Sigra.Credo.NoLogSafe2InLib` custom Credo check forbids arity-2 `Sigra.Audit.log_safe` calls in `lib/sigra/**`.** Allowed locations: tests, the `log_safe/2` shim definition itself. This is the mechanism that prevents drift under future phases. Without it, "one idiom in lib/" is a convention that rots; with it, it's enforced structurally.

- **D-31: Test strategy for the 79-site sweep = `assert_audit_logged/2` helper in `Sigra.Testing`.** Signature: `assert_audit_logged(repo, fields)` reads the latest row from the test audit schema and asserts on `{action, actor_id, effective_user_id, organization_id, target_id}`. One assertion per migrated site. No snapshot tests — they obscure intent. Added to `Sigra.Testing` per REQ DX-02.

### Claude's Discretion

- Exact boundaries between Plan 15-01 / 15-02 / 15-03 are a planning-phase concern. The principle is: 15-01 is trivially-reviewable mechanical change, 15-02 is semantic enrichment, 15-03 is install-path wiring.
- The exact arg keys for `AccountDeletion` (`"scope_module"` vs `"scope"` vs something else) are planner's call provided the retry-safety property holds.
- Choice of `ExUnit` tags, fixture file locations, and test-helper internal structure are planner/executor discretion.
- Whether the Credo check lives in `lib/sigra/credo/` or a test-only path is planner discretion — the constraint is that it must run in CI, not just locally.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project-Level Specs
- `.planning/ROADMAP.md` §Phase 15 (lines 116-128) — phase goal, success criteria, v1.2 load-bearing commitments.
- `.planning/REQUIREMENTS.md` AUD-01..AUD-05 (lines 73-77) — acceptance criteria.
- `.planning/PROJECT.md` — key decisions, especially the v1.1/v1.2 scope split (2026-04-11) and the library-first org philosophy.
- `.planning/v1.2-DIRECTION.md` — dormant but authoritative for v1.2 load-bearing decisions (impersonation shape, admin UI needs).
- `.planning/research/PITFALLS.md` §O-7 (audit misattribution under impersonation) and §O-11 (worker runs without tenant context) — the two pitfalls Phase 15 is specifically designed to prevent.
- `.planning/research/PITFALLS.md` §O-10 (cascade wipes audit log) — already mitigated by Phase 13 D-17 `on_delete: :nilify_all`, Phase 15 must not regress it.

### Prior Phase Decisions
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — the 28 decisions that shape `Sigra.Audit`. Phase 15 does NOT revisit these; it extends on top.
- `.planning/phases/12-scope-session-foundation/12-CONTEXT.md` — `%Sigra.Session{active_organization_id}` shape, `Scope.impersonating_from` reserved field contract.
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` — D-17 `audit_events.organization_id → on_delete: :nilify_all`, D-20 "audit call sites already ship via log_safe/2; Phase 15 upgrades them."
- `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md` — D-01 `Sigra.Scope.Hydration.hydrate/3` as the single source of request-time scope, D-14 stale-pointer audit emission via `organization.active_auto_reassigned`.

### Library Source (must read before planning)
- `lib/sigra/audit.ex` — existing `log/2`, `log_multi/3`, `log_safe/2`, `__log_internal__/3`, `build_attrs/4` (line 384), `changeset_opts/2` (line 363)
- `lib/sigra/audit/changeset.ex` — `@cast_fields` list (line 30) that must gain two entries
- `lib/sigra/audit/query.ex` — existing filter reduce pattern; line 43 catch-all that must be removed
- `lib/sigra/scope/hydration.ex` — sibling module for `Sigra.Scope.build/3`
- `priv/templates/sigra.install/core/create_audit_events.exs` — FROZEN, do not modify
- `priv/templates/sigra.install/core/audit_event.ex` — schema template that gains two `field` declarations
- `priv/templates/sigra.install/core/scope.ex` — host-side Scope template, for verification only (NOT modified — helpers live library-side)
- `lib/sigra/workers/account_deletion.ex` — reference worker to be refactored
- `lib/sigra/workers/email_delivery.ex`, `audit_cleanup.ex`, `token_cleanup.ex` — tenant-agnostic workers, untouched

### Call Sites to Sweep (all 79)
Verified counts via `grep -c "Audit\.log_safe("` across `lib/sigra/`:
- `lib/sigra/auth.ex` — 24 sites
- `lib/sigra/mfa.ex` — 20 sites
- `lib/sigra/account.ex` — 17 sites
- `lib/sigra/oauth.ex` — 8 sites
- `lib/sigra/api_token.ex` — 7 sites
- `lib/sigra/lockout.ex` — 1 site
- `lib/sigra/suspicious_login.ex` — 1 site
- `lib/sigra/plug/load_active_organization.ex` — 1 site (Phase 14; already has scope, verify it migrates cleanly to `/3`)

### External Standards
- OWASP ASVS V7.1 (authentication logging) — failed-login audit MUST record claimed identity + outcome but MUST NOT assert the actor as the claimed user.
- NIST SP 800-63B §5.2.2 — authentication event logging requirements.
- Phoenix 1.8 `phx.gen.auth` scopes guide (in `deps/phoenix/guides/` or hexdocs) — `fn(scope, ...)` positional argument convention.
- Dashbit blog "Mocks and explicit contracts" — behaviour-vs-macro tradeoff.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Sigra.Audit.log_safe/2`** (`lib/sigra/audit.ex:111`) — the existing no-op-safe library audit helper. Becomes the shim that delegates to `log_safe/3` with `nil` scope.
- **`Sigra.Audit.build_attrs/4`** (`lib/sigra/audit.ex:384`) — the single attrs-builder for every log path. Gains two keyword reads: `organization_id` and `effective_user_id`.
- **`Sigra.Audit.Changeset`** `@cast_fields` list (`lib/sigra/audit/changeset.ex:30`) — one edit adds both new fields to the changeset cast.
- **`Sigra.Audit.Query.build/2`** reduce pattern — three new `apply_filter/2` clauses follow the existing shape exactly. No refactoring required.
- **`Sigra.Scope.Hydration`** (`lib/sigra/scope/hydration.ex`) — the `lib/sigra/scope/` directory already exists; `Sigra.Scope.build/3` lives alongside.
- **`Sigra.Workers.AccountDeletion`** (`lib/sigra/workers/account_deletion.ex`) — already threads `"user_id"` and `"repo"` / `"user_schema"` as stringified args; gains three more (`"scope_module"`, `"organization_schema"`, `"actor_id"`, `"organization_id"`) and a `perform(scope, args)` clause implementing the new behaviour.

### Established Patterns
- **Optional Oban integration**: every worker module is wrapped in `if Code.ensure_loaded?(Oban.Worker) do ... end`. `Sigra.Workers` behaviour must NOT reference Oban at the module level — the behaviour itself compiles without Oban, only implementing workers conditionally exist.
- **Stringified module args**: `AccountDeletion` already uses `Module.safe_concat([args["repo"]])` to resolve modules at perform time. The same pattern applies to the new `"scope_module"` / `"organization_schema"` args.
- **Test audit schema**: `test/support/audit_test_event.ex` exists and is used by the existing `test/sigra/audit_*_test.exs` suite. New `:organization_id` / `:effective_user_id` fields on the test schema are a one-line edit.
- **Generator install-golden**: `test/fixtures/install_golden/tree/` is the canonical snapshot of the generated tree. New migration + schema-field additions propagate here via the generator refactor plus test run.
- **Conditional migration templates**: Sigra's existing `Sigra.Adapters` branching (used for citext, JSONB) is the hook point for the SQLite non-concurrent index creation — planner must verify the branching exists or add it.

### Integration Points
- **`lib/sigra/auth.ex:1016`** — `session.create` audit emission. Must be reordered to fire AFTER `maybe_assign_active_organization` (~line 1000-1015) so the first session audit carries real `organization_id`.
- **`lib/sigra/install/features/core.ex`** — the generator feature manifest that drives template emission. Must be updated to emit the new alter migration file alongside the existing create migration.
- **`lib/sigra/testing.ex`** (or equivalent) — the public test-helper module per REQ DX-02. Gains `assert_audit_logged/2`.
- **`.credo.exs`** — the custom check is registered here, alongside whatever existing Sigra-specific Credo configuration lives there.

</code_context>

<specifics>
## Specific Ideas

- **One-line v1.2 impersonation diff as the success test for D-04**: after Phase 15 lands, implementing v1.2 impersonation should literally be a one-line change inside `scope_fields/1`. If it takes more than that, something in Phase 15 is shaped wrong.
- **Parallel between web and worker call sites**: reviewer opening `lib/sigra/auth.ex` and `lib/sigra/workers/account_deletion.ex` side by side should see the same `Audit.log_safe(action, scope, opts)` call shape. If they look different, the design failed its cohesion goal.
- **Credo check is load-bearing**: without `Sigra.Credo.NoLogSafe2InLib`, "one idiom in lib/" is a convention that future phases will erode. Shipping the check in the same phase as the sweep is non-negotiable.
- **Admin UI query API forward-compatibility**: v1.2's admin UI must be able to write `Sigra.Audit.Query.build(schema, organization_scope: {:only, org_id})` on day one without a migration or query-API change. If v1.2 planning ever needs to alter `Sigra.Audit.Query` before the first admin view ships, Phase 15 shipped the wrong filter surface.

</specifics>

<deferred>
## Deferred Ideas

- **`Sigra.Audit.Query.for_scope/2`** — convenience function accepting a `%Scope{}` and building filters. Deferred to v1.2 when the admin UI caller exists and we know what it wants the query to return (just `organization_id`? plus date range? plus impersonation target?).
- **`effective_user_id` composite index** — deferred to v1.2. In v1.1 the column always equals `actor_id`, so the existing `(actor_id, inserted_at)` index serves every query. Adding an unused composite now is write amplification.
- **`Sigra.Audit.log_multi/3` scope support** — `log_multi/3` and `log_multi_safe/3` have zero integration call sites today. Revisit when v1.2 admin UI needs multi-variant org-aware emission.
- **Partial index or UNION rewrite for `organization_scope: :including_global`** — Postgres may seq-scan for `WHERE org_id = ? OR org_id IS NULL`. Documented as `# TODO(v1.2):` comment inline; fix when the query starts actually hitting it at scale.
- **`Sigra.Workers` adoption for `EmailDelivery`** — currently tenant-agnostic; v1.2 admin-sent emails will want org context. Refactor at that time.
- **Cloak-encrypted audit metadata** — orthogonal to Phase 15; out of scope.
- **`--no-organizations` conditional for audit columns** — v1.1 always ships the columns. If a future generator flag makes orgs optional, the migration becomes conditional then.

</deferred>

---

*Phase: 15-audit-integration*
*Context gathered: 2026-04-12*
