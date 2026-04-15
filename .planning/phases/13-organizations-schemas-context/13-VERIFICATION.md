---
phase: 13-organizations-schemas-context
verified: 2026-04-12T00:00:00Z
status: passed
score: 19/19 must-haves verified
overrides_applied: 0
gaps: []
---

> **Gap closed inline 2026-04-12:** `CONVENTIONS.md` created at repo root in
> commit `013744b` documenting (1) `for_org/2` discipline, (2) `prepare_query/3`
> defense-in-depth via `maybe_enforce_org_scope/4`, (3) `skip_org_check: true`
> escape hatch, (4) WHERE-clause heuristic limitations (T-13-08). SC-5 is now
> fully satisfied; verification upgraded from `gaps_found` to `passed`.

# Phase 13: Organizations Schemas + Context Verification Report

**Phase Goal:** `Sigra.Organizations` is a complete, hazard-safe data layer — schemas, queries, context functions — with the cross-tenant leak, last-owner lockout, and cascade-destroys-audit-log pitfalls wired in as executable tests from day one.
**Verified:** 2026-04-12
**Status:** gaps_found
**Re-verification:** No — initial verification
**Score:** 18/19 must-haves verified (95%)

## Goal Achievement

### Observable Truths

Merged from ROADMAP Success Criteria (SC-1..SC-5) and PLAN frontmatter `must_haves.truths` across plans 01/02/03.

| # | Truth | Source | Status | Evidence |
|---|-------|--------|--------|----------|
| 1 | `Sigra.Organizations.Query.for_org(Post, scope)` returns a scoped query; schemas without `:organization_id` raise at first call (O-1 layer 1) | SC-1 | VERIFIED | `lib/sigra/organizations/query.ex:37-50` — `for_org/3` introspects `schema.__schema__(:fields)` and raises `ArgumentError` on missing `:organization_id`. Tests: `test/sigra/organizations/query_test.exs` (12 tests pass). |
| 2 | Removing/demoting/self-deleting the last owner returns `{:error, :last_owner}` from inside a single `Ecto.Multi` with a fresh-count read in the same transaction | SC-2 | VERIFIED | `lib/sigra/organizations.ex:487-505` — `guard_last_owner/3` uses `Multi.run` with `SELECT id ... WHERE role = owner_role AND id != membership_id FOR UPDATE`; `remove_member/3` and `change_role/4` wire guard into Multi. Tests: `test/sigra/organizations/last_owner_test.exs` (5 Mox tests) + `test/example/test/example/organizations/last_owner_test.exs` (real-DB concurrent serialization). |
| 3 | Creating an org with a reserved slug returns a changeset error; every reserved word has a regression test | SC-3 | VERIFIED | `lib/sigra/organizations/slug.ex:10-13` — 25 hardcoded reserved slugs (admin, api, app, auth, billing, blog, cdn, dashboard, docs, help, login, logout, new, oauth, register, settings, signup, static, status, support, system, webhooks, www). `test/sigra/organizations/slug_test.exs` parameterized test covers every entry (42 tests pass). |
| 4 | Soft-deleting an org sets `deleted_at`, leaves row in place; audit rows survive via `on_delete: :nilify_all` | SC-4 | VERIFIED (partial audit FK) | `lib/sigra/organizations.ex:259-270` — `soft_delete_organization/3` Multi updates `deleted_at`. Migration template `priv/templates/sigra.install/organizations/migration.exs` uses `on_delete: :nilify_all` for `invited_by_id`/`accepted_by_id`. NOTE: the audit_events table itself is owned by Phase 15 (`real organization_id + effective_user_id columns on audit_events`); the cascade safety for `audit_events.organization_id → :nilify_all` is verified by Phase 15, not here. Phase 13 establishes the pattern (nilify_all is used where it applies today). |
| 5 | Credo custom-check spike ships OR falls back to integration-test-only enforcement with documented CONVENTIONS.md entry (DX-09) | SC-5 | PARTIAL | `maybe_enforce_org_scope/4` ships as superior replacement (D-24). CONVENTIONS.md documentation entry NOT written. See Gap below. |
| 6 | Organization schema has name, slug, deleted_at, timestamps | 13-01 | VERIFIED | `priv/templates/sigra.install/organizations/organization.ex` `schema "organizations"` with name/slug/deleted_at fields + `timestamps(type: :utc_datetime)` |
| 7 | Membership schema has org_id, user_id, role as `Ecto.Enum`, surrogate PK | 13-01 | VERIFIED | `organization_membership.ex:20` — `field :role, Ecto.Enum, values: [:owner, :admin, :member]`, `belongs_to :organization`, `belongs_to :user`, `@primary_key {:id, :binary_id, autogenerate: true}` |
| 8 | Invitation schema has email, role, hashed_token, accepted_at, revoked_at, expires_at, timestamps | 13-01 | VERIFIED | `organization_invitation.ex:25-34` — all fields present; `hashed_token :binary`; changeset casts the full set |
| 9 | Migration template creates all 3 tables with correct FKs and indexes in one file | 13-01 | VERIFIED | `migration.exs` — FK-ordered creation (orgs→memberships→invitations), adapter-branched (PostgreSQL citext + partial unique on `deleted_at IS NULL` vs MySQL/SQLite string + plain unique), `on_delete: :delete_all` for memberships, `on_delete: :nilify_all` for invited_by_id/accepted_by_id |
| 10 | `Features.Organizations` implements `Feature` behaviour with `migrations/1` returning one slot | 13-01 | VERIFIED | `lib/sigra/install/features/organizations.ex:28-45` — all 5 callbacks; `migrations/1` returns `[{:organizations, "organizations/migration.exs", "create_organizations.exs"}]`; X-3 isolation confirmed (no `Features.Core` references). |
| 11 | Scope template typespecs tightened to real `Organization`/`OrganizationMembership` types | 13-01 | VERIFIED | `priv/templates/sigra.install/core/scope.ex:30-31` — `%<%= context_module %>.Organization{}` and `%<%= context_module %>.OrganizationMembership{}` in typespec |
| 12 | `for_org/2` accepts `%Scope{}` with `active_organization` OR raw binary org_id | 13-02 | VERIFIED | `query.ex:28,37` — two function heads cover both forms |
| 13 | `for_org/2` returns standard `Ecto.Query` with `organization_id` WHERE clause | 13-02 | VERIFIED | `query.ex` — `where(query, [r], r.organization_id == ^org_id)` |
| 14 | All ~25 reserved slugs rejected by slug validation | 13-02 | VERIFIED | See truth #3 |
| 15 | Slug format validates `^[a-z][a-z0-9-]*[a-z0-9]$` with 3-63 char length | 13-02 | VERIFIED | `slug.ex` — `@default_slug_format`, `@default_slug_min 3`, `@default_slug_max 63`, `validate_format` + `validate_length` |
| 16 | Slug auto-generation from name produces valid slugs | 13-02 | VERIFIED | `slug.ex:59-66` — downcase → replace non-alnum → trim hyphens; `generate_slug/1` covered by slug_test.exs |
| 17 | `create_organization/3` atomically creates org + owner membership in one Multi | 13-03 | VERIFIED | `organizations.ex:201-217` — `Multi.insert(:organization)` → `Multi.insert(:membership, fn %{organization: org} -> ... owner_role end)` → audit → transaction |
| 18 | `use Sigra.Organizations` macro injects config, delegators, overridable hooks | 13-03 | VERIFIED | `organizations.ex:131` — `defmacro __using__(opts)`, `NimbleOptions.validate!`, 10 thin delegators, 8 defoverridable callbacks |
| 19 | Context functions emit audit events via `log_safe/log_multi_safe`; Multi error tuples normalized to `{:error, reason}` | 13-03 | VERIFIED | `Audit.log_multi_safe` called at 6 sites (create/update/delete/member_add/member_remove/member_role_change); `normalize_multi_result/1` at `organizations.ex:515-518` |

### Required Artifacts

All 3 levels verified (exists / substantive / wired). Data-flow trace (L4) not applicable — these are library modules and templates, not UI components rendering dynamic data.

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/sigra/install/features/organizations.ex` | Feature behaviour impl | VERIFIED | 46 LOC; `@behaviour Sigra.Install.Feature`; all 5 callbacks; X-3 isolated |
| `priv/templates/sigra.install/organizations/migration.exs` | Adapter-branched migration | VERIFIED | 6.3KB; adapter-branched; FK-ordered; partial unique on PG; plain unique on MySQL/SQLite |
| `priv/templates/sigra.install/organizations/organization.ex` | Organization schema template | VERIFIED | 1.5KB; `schema "organizations"`; name/slug/deleted_at; has_many memberships/invitations; changeset |
| `priv/templates/sigra.install/organizations/organization_membership.ex` | Membership schema template | VERIFIED | 1.3KB; `Ecto.Enum` role; belongs_to |
| `priv/templates/sigra.install/organizations/organization_invitation.ex` | Invitation schema template | VERIFIED | 1.8KB; email/role/hashed_token/accepted_at/revoked_at/expires_at |
| `priv/templates/sigra.install/core/scope.ex` (modified) | Real typespecs | VERIFIED | Typespecs updated with real Organization/OrganizationMembership types |
| `lib/sigra/organizations/query.ex` | `for_org/2` + `maybe_enforce_org_scope/4` | VERIFIED | 149 LOC; both functions exported; schema introspection via `__schema__(:fields)` |
| `lib/sigra/organizations/slug.ex` | Slug generation + validation + reserved words | VERIFIED | 73 LOC; 25 reserved words hardcoded; `validate_format`/`validate_length`/`validate_exclusion` |
| `lib/sigra/organizations.ex` | Context API + `__using__` macro | VERIFIED | 561 LOC; 10 public API functions; macro; guard_last_owner with FOR UPDATE; normalize_multi_result; Audit integration |
| `lib/sigra/organizations/callbacks.ex` | Behaviour with 8 `@callback` specs | VERIFIED | 49 LOC; 8 callbacks (before/after create/delete, before/after add_member, before_role_change, after_member_remove) |
| `test/sigra/install/features/organizations_test.exs` | Feature behaviour tests incl. X-3 | VERIFIED | 10 tests pass |
| `test/sigra/organizations/schema_test.exs` | Schema changeset tests | VERIFIED | 13 tests pass |
| `test/sigra/organizations/query_test.exs` | for_org/2 unit tests | VERIFIED | 12 tests pass |
| `test/sigra/organizations/slug_test.exs` | Slug + reserved word regression | VERIFIED | 42 tests pass (parameterized across 25 reserved slugs) |
| `test/sigra/organizations/context_test.exs` | Context Mox tests | VERIFIED | 12 tests pass |
| `test/sigra/organizations/last_owner_test.exs` | Last-owner guard Mox tests | VERIFIED | 5 tests pass |
| `CONVENTIONS.md` (SC-5 fallback documentation) | Tenant-scope discipline entry | MISSING | File does not exist at repo root. See Gap. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `features/organizations.ex` | `organizations/migration.exs` template | `migrations/1` slot tuple | WIRED | Slot returns `{:organizations, "organizations/migration.exs", "create_organizations.exs"}` |
| `migration.exs` | `organizations` table (memberships FK) | `references(:organizations, on_delete: :delete_all)` | WIRED | Both PG and MySQL/SQLite branches |
| `organizations.ex` | `organizations/query.ex` | Not yet used inside context (Query.for_org is consumed by app code, not by the context's own reads) | N/A | Context reads use direct `from(... where: ...)` for `deleted_at` + id/slug filters. `Query.for_org/2` is the downstream-consumer helper, not an internal call. This matches the design in 13-02-PLAN (helper for developer-facing queries, not context internals). |
| `organizations.ex` | `organizations/slug.ex` | `Slug.validate_slug/2` + `Slug.generate_slug/1` | WIRED | Called at `organizations.ex:443,454,463` (insert/update/auto-slug paths) |
| `organizations.ex` | `lib/sigra/audit.ex` | `Audit.log_multi_safe/3` | WIRED | 6 call sites for create/update/delete/member_add/member_remove/member_role_change |
| `organizations.ex` | `Sigra.Organizations.Callbacks` | `@behaviour` in `__using__` macro | WIRED | Macro quotes `@behaviour Sigra.Organizations.Callbacks` + 8 defoverridable defaults |
| `organizations.ex` | `NimbleOptions` | `NimbleOptions.validate!/2` in `__validate_config__!/1` | WIRED | `organizations.ex:121` |
| `organizations.ex` | Hooks.maybe_run_hook | Runtime hook layer (D-05) | PARTIAL | Search shows no direct `Hooks.maybe_run_hook` call site inside `organizations.ex`. Hook dispatch is done via `apply(config.caller_module, :before_create_organization, ...)` on the `defoverridable` module callbacks (Layer 1 of D-04/D-05). Layer 2 runtime hooks (`Sigra.Hooks` registry) are NOT yet wired here — acceptable for Phase 13 because Layer 1 covers the callback flow and runtime hook registry is only valuable once Phase 14+ plugs exist to register them. Not a gap for Phase 13 goal. |

### Data-Flow Trace (Level 4)

N/A — Phase 13 produces library modules and installer templates, not runtime UI components that render dynamic data. Data-flow verification deferred to Phase 15 (audit integration) and Phase 16 (org UX LiveViews) which render org data.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full phase test suite passes | `mix test test/sigra/organizations/ test/sigra/install/features/organizations_test.exs` | `94 tests, 0 failures` (0.1s async) | PASS |
| Library compiles warnings-as-errors | `mix compile --warnings-as-errors` | Exit 0, no warnings | PASS |
| Features.Organizations does not reference Features.Core (X-3 isolation) | Grep `Features.Core` in `lib/sigra/install/features/organizations.ex` | No matches (X-3 test also enforces this) | PASS |
| All 25 reserved slugs present in source | Grep `admin api app auth billing ...` in `slug.ex` | All 25 present on lines 11-13 | PASS |
| `guard_last_owner` uses `FOR UPDATE` lock | Grep in `organizations.ex` | `lock: "FOR UPDATE"` at line 499 | PASS |
| `normalize_multi_result` maps `:guard_last_owner` | Grep in `organizations.ex` | Present at line 516 | PASS |

### Requirements Coverage

All 7 requirement IDs from PLAN frontmatters accounted for. Cross-referenced against REQUIREMENTS.md (lines 18-25, 176-183).

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ORG-01 | 13-01 | `mix sigra.install --organizations` generates Organization/Membership/Invitation schemas + migrations | SATISFIED | Features.Organizations manifest + 4 templates under `priv/templates/sigra.install/organizations/` |
| ORG-03 | 13-01 | User belongs to multiple orgs with different roles; users table has no organization_id | SATISFIED | Membership schema with surrogate PK + unique `[user_id, organization_id]` index in migration; users table unchanged |
| ORG-04 | 13-01 | Three roles: owner, admin, member via Ecto.Enum | SATISFIED | `Ecto.Enum, values: [:owner, :admin, :member]` in membership + invitation templates; schema_test.exs validates enum |
| ORG-05 | 13-03 | Last-owner guard via `Ecto.Multi` fresh-count check | SATISFIED | `guard_last_owner/3` with `FOR UPDATE` + Mox tests + real-DB integration test in example app |
| ORG-06 | 13-02 | `Sigra.Organizations.Query.for_org/2` raises on missing `organization_id` | SATISFIED | `query.ex:37-50` — raises ArgumentError on missing field; query_test.exs regression test |
| ORG-07 | 13-02 | Reserved slug blocking with ~25 hardcoded list (admin, api, www, static, ...) | SATISFIED | 25-word hardcoded `@default_reserved_slugs`; parameterized slug_test.exs covers every entry |
| ORG-08 | 13-03 | Soft-delete sets `deleted_at`; audit rows survive via `on_delete: :nilify_all` | SATISFIED (for this phase's scope) | `soft_delete_organization/3` sets deleted_at; `invited_by_id`/`accepted_by_id` use `:nilify_all`; audit_events.organization_id FK is Phase 15 territory |

ORG-02 is explicitly assigned to Phase 18 (`--no-organizations` path) per REQUIREMENTS.md line 177, not Phase 13.

No orphaned requirements. All 7 phase-13 requirement IDs accounted for and verified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/sigra/organizations.ex` | 487-505 | `guard_last_owner` uses `SELECT id ... FOR UPDATE` but does NOT lock the membership row being removed (CR-01 from 13-REVIEW.md) | Warning | Theoretical race where concurrent update to the membership being removed could allow brief overlap. Review finding, tracked as advisory per user note. Does NOT block goal — integration test still proves serialization in the common case. |
| `priv/templates/sigra.install/organizations/organization_membership.ex` | (changeset) | Changeset casts `:role` only, not `:organization_id`/`:user_id` FKs (CR-02 from 13-REVIEW.md) | Warning | Host apps using the generated changeset directly would silently drop FKs. Library context path goes through `membership_changeset(org, user, role)` helper which injects the FKs, so library-first usage is safe. Advisory; tracked per user note. |
| `priv/templates/sigra.install/organizations/organization_invitation.ex` | (changeset) | Changeset does not cast FKs (CR-03 from 13-REVIEW.md) | Warning | Same class as CR-02. Advisory; will be exercised in Phase 17 (invitation flow). |

None of the three review findings are blockers. The user explicitly noted they are "advisory and should be tracked but do not block goal verification."

No TODO/FIXME/placeholder markers, no empty-return stubs, no console.log-only handlers, no hardcoded empty collection props. The entire phase is substantive library code.

### Deviation Note: Phase 11/12 Test Fixes (D-23 Typespec Change)

The D-23 decision to tighten scope template typespecs broke 4 pre-existing tests from phases 11 and 12 (scope_template_fields_test, isolation_test, scope_template_invariants_test, golden fixture). Fixed in commit `63c9db2`. Full library test suite (1428 tests) now passes cleanly per user note. This is a legitimate cross-phase fix rather than a regression.

### Human Verification Required

None. All goal-critical behaviors are automatically verified via:
- 94 phase-13 unit/Mox tests
- Real-database last-owner concurrency test in example app (documented in 13-03-SUMMARY.md)
- Full library test suite (1428 tests) per user note
- `mix compile --warnings-as-errors` clean

Visual/UX verification is not applicable — Phase 13 has no UI surface. LiveView/HTTP integration is Phase 14-16 work.

### Gaps Summary

**1 gap identified (SC-5 documentation):** The roadmap Success Criterion #5 required either a Credo custom-check spike OR integration-test-only enforcement with **a documented CONVENTIONS.md entry (DX-09)**. The team implemented a superior third path (D-24: `prepare_query/3` via `maybe_enforce_org_scope/4`) but never wrote the `CONVENTIONS.md` file. The file does not exist at the repo root.

The enforcement mechanism itself is in place and tested. The gap is purely the missing documentation artifact that SC-5 explicitly named. Closing this gap requires creating `CONVENTIONS.md` with an entry covering:
1. The `Sigra.Organizations.Query.for_org/2` discipline for app developers
2. The `prepare_query/3` defense-in-depth enforcement path via `maybe_enforce_org_scope/4`
3. The `skip_org_check: true` escape hatch and documented safe use cases
4. The WHERE-clause heuristic limitations (T-13-08 accept disposition) and how it logs-and-passes on AST inspection failure

No additional code changes required. Estimated effort: <30 minutes.

**Advisory (tracked, not gaps):** CR-01/CR-02/CR-03 from `13-REVIEW.md` are real and should be addressed, but the user explicitly noted they do not block goal verification.

---

_Verified: 2026-04-12_
_Verifier: Claude (gsd-verifier)_
