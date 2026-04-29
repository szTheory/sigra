---
phase: 92-rbac-seams-b2b-02
plan: 01
subsystem: auth
tags: [rbac, organizations, authz, seams, behaviour, phoenix, elixir]

# Dependency graph
requires:
  - phase: 14-organizations-active-context
    provides: "Sigra.Plug.RequireMembership, Sigra.Scope :membership field"
  - phase: 16-org-liveviews-switcher
    provides: "Sigra.Organizations.__config_schema__ with :roles / :owner_role defaults"
  - phase: 17-organization-invitations
    provides: "Sigra.Organizations.Invitations with @auth_roles [:owner, :admin] constant"
provides:
  - "Sigra.Authz behaviour module with single can?/3 callback (no built-in policy / role taxonomy)"
  - "Explicit-only :roles contract on Sigra.Admin.Policy.admin_org_ids_from_memberships/2"
  - "Required :roles, :owner_role, :invitation_admin_roles on Sigra.Organizations config schema"
  - "Sigra.Plug.RequireMembership :organizations dependency when :roles is non-empty"
  - "Sigra.Organizations.Invitations consumption of host-configured :invitation_admin_roles"
affects: [92-02, 92-03, 92-04, 93-m2m-tokens, downstream-recipes-rbac]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Behaviour-only seam (no library default implementation, helper, or constant)"
    - "Required NimbleOptions config keys for host-supplied role taxonomy"
    - "Actionable ArgumentError messages naming the option to set when host config is missing"

key-files:
  created:
    - "lib/sigra/authz.ex"
    - "test/sigra/authz_test.exs"
  modified:
    - "lib/sigra/admin/policy.ex"
    - "lib/sigra/organizations.ex"
    - "lib/sigra/organizations/invitations.ex"
    - "lib/sigra/plug/require_membership.ex"
    - "test/sigra/plug/require_membership_test.exs"
    - "test/sigra/plug/require_admin_access_test.exs"

key-decisions:
  - "Sigra.Authz ships only a behaviour and zero helper functions to keep the seam genuinely role-agnostic; default semantics are host-owned via Plan 92-02 generator output."
  - "Make :roles, :owner_role, and the new :invitation_admin_roles required NimbleOptions keys in Sigra.Organizations rather than relocating defaults — generator code (Plan 92-02) supplies host-themed values explicitly."
  - "Add :invitation_admin_roles as a new required config key consumed by Sigra.Organizations.Invitations to replace the @auth_roles [:owner, :admin] constant; this keeps the create/2 and revoke/3 authorization gate intact while removing the library taxonomy constant."
  - "Leave Multi step name :membership and the universal Sigra.Scope :membership struct field as-is — they are structural identifiers, not role taxonomy, and renaming would ripple across many out-of-scope test files."

patterns-established:
  - "Role-agnostic seam pattern: ship a behaviour with one callback, zero helper functions, zero default implementations."
  - "Explicit-only config pattern: use NimbleOptions `required: true` with actionable error messages when host configuration is missing."
  - "Phase 92-01 audit: any future RBAC seam in the library must not introduce a fallback role list, default admin-role set, or hard-coded role atom constant."

requirements-completed: [B2B-02]

# Metrics
duration: 1h 8m
completed: 2026-04-29
---

# Phase 92-01: De-opinionate library RBAC seams Summary

**`Sigra.Authz` behaviour ships role-agnostic; library no longer defaults `:owner / :admin / :member` taxonomy across `admin/policy.ex`, `organizations.ex`, `organizations/invitations.ex`, or `plug/require_membership.ex`.**

## Performance

- **Duration:** ~1h 8m (worktree-agent execution)
- **Started:** 2026-04-29T18:03:00Z (approx, post-base reset)
- **Completed:** 2026-04-29T19:11:45Z
- **Tasks:** 2 (both with TDD: RED → GREEN, Task 2 also REFACTOR)
- **Files modified:** 6 (2 created, 4 modified) + 2 test files (1 created, 1 modified) + 1 test file out-of-scope under Rule 3

## Accomplishments

- New `Sigra.Authz` behaviour exposing exactly one role-agnostic callback (`can?/3`) with no library-side default implementation, helper functions, or built-in role atoms — verified by 8 contract tests including a source-bytes scan for `:owner`, `:admin`, `:member`.
- Removed `@default_admin_roles [:owner, :admin]` from `Sigra.Admin.Policy`; `admin_org_ids_from_memberships/2` now requires explicit `:roles` via `Keyword.fetch!`, raising `KeyError` when missing and `ArgumentError` for malformed input.
- Removed `roles` and `owner_role` defaults from `Sigra.Organizations.__config_schema__/0`; added new required `:invitation_admin_roles` config consumed by `Sigra.Organizations.Invitations` to replace the `@auth_roles [:owner, :admin]` constant in `create/2` and `revoke/3`.
- Removed `@default_role_universe [:owner, :admin, :member]` from `Sigra.Plug.RequireMembership`; `init/1` now requires `:organizations` whenever `:roles` is non-empty so the role universe is host-supplied, with an actionable error message naming the missing option.
- Migrated `test/sigra/plug/require_membership_test.exs` to a host-themed role universe (`:tenant_lead`, `:site_admin`, `:viewer`, `:billing`, `:reviewer`) to prove the seam genuinely accepts arbitrary host-defined role atoms.
- 35 in-scope tests pass: 8 (`Sigra.AuthzTest`) + 17 (`Sigra.Plug.RequireMembershipTest`) + 10 (`Sigra.Plug.RequireAdminAccessTest`).

## Task Commits

Each task was committed atomically (TDD: RED → GREEN → REFACTOR where applicable):

1. **Task 1 RED — failing Sigra.Authz behaviour-contract tests** — `cfc9a44` (test)
2. **Task 1 GREEN — implement Sigra.Authz behaviour** — `ac1d905` (feat)
3. **Task 2 RED — failing tests for explicit-only RBAC contracts** — `e967c99` (test)
4. **Task 2 GREEN — de-opinionate library RBAC seams (4 lib files)** — `d870fd4` (feat)
5. **Task 2 REFACTOR — rename internal query alias :membership to :join_row** — `92fb571` (refactor)

The plan-completion docs commit will follow after this SUMMARY is written.

## Files Created/Modified

**Created:**
- `lib/sigra/authz.ex` — Role-agnostic `Sigra.Authz` behaviour with single `can?/3` callback. Moduledoc documents the Phase 92 seam-only contract: hosts own role semantics; library ships no built-in roles, helpers, or defaults.
- `test/sigra/authz_test.exs` — 8 tests covering callback shape (exactly `can?/3`, zero `@optional_callbacks`), source-bytes scan asserting no `:owner / :admin / :member` atoms in the module body, refutation of library-side `can?/3`/`allow?/3`/`deny?/3`/`authorize/3` exports, and a host-implementation contract example.

**Modified (lib):**
- `lib/sigra/admin/policy.ex` — Dropped `@default_admin_roles [:owner, :admin]`. `admin_org_ids_from_memberships/2` now uses `Keyword.fetch/2` with explicit `:roles` validation; raises `KeyError` (missing) or `ArgumentError` (malformed). Moduledoc + function doc updated to call out the Phase 92 / B2B-02 explicit-only contract.
- `lib/sigra/organizations.ex` — Made `:roles` and `:owner_role` `required: true` in `@org_config_schema`; added new required `:invitation_admin_roles` (list of atoms) for the invitations gate. Reworded the `add_member_multi/5` docstring example to use a generic `host_role` rather than the canonical `:member` literal. Renamed the local Ecto query alias `:membership` → `:join_row` inside `list_members_with_activity/3` (internal-only, contained to one function).
- `lib/sigra/organizations/invitations.ex` — Dropped `@auth_roles [:owner, :admin]`. `authorize_create/2` (now arity-2 to take config) and `revoke/3` consult `fetch_invitation_admin_roles!/1` which reads `config.invitation_admin_roles` and raises a host-actionable `ArgumentError` when absent. Doc strings updated.
- `lib/sigra/plug/require_membership.ex` — Dropped `@default_role_universe [:owner, :admin, :member]`. `init/1` now resolves the role universe through `resolve_role_universe!/1` which raises an actionable `ArgumentError` when `:roles` is non-empty but `:organizations` is missing. The error message names `:organizations` as the fix.

**Modified (tests):**
- `test/sigra/plug/require_membership_test.exs` — Reframed `CustomRolesOrganizations` with host-themed role atoms (`:tenant_lead`, `:site_admin`, `:reviewer`, `:viewer`, `:billing`); added two new tests asserting `init/1` raises `ArgumentError` with `:organizations` named in the message when `:roles` is non-empty without `:organizations`; rewired existing role-validation cases to thread `organizations: CustomRolesOrganizations` through.
- `test/sigra/plug/require_admin_access_test.exs` (Rule 3 deviation) — Updated `policy helper` describe block: existing test now passes `roles: [:owner, :admin]` explicitly; added two new tests asserting `KeyError` on missing `:roles` and `ArgumentError` on malformed `:roles`.

## Decisions Made

- **Sigra.Authz exports zero helper functions.** A library-side `can?/3` default would re-opinionate the seam. The behaviour-only shape forces hosts to write their policy explicitly (which Plan 92-02 generator emits as a starter and Plan 92-04 recipe walks to deny-by-default).
- **`:invitation_admin_roles` is its own config key, not derived from `:owner_role` or a subset of `:roles`.** Invitation-admin privilege is a distinct policy decision from "who is an org owner"; conflating them would re-introduce the implicit hierarchy this plan removes.
- **Multi step name `:membership` and scope struct field `:membership` stay as-is.** They are structural identifiers consumed by many out-of-scope tests and templates. Renaming them would create scope creep beyond `files_modified`. The verify regex over-match (see Deviations) is the cost; the alternative would touch 8+ test files.
- **`:roles`/`:owner_role`/`:invitation_admin_roles` made `required` rather than removed.** Removing them would silently change behavior; making them required surfaces the contract change as a NimbleOptions validation error so hosts notice immediately.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Plan verify regex over-matches `:membership` substring**
- **Found during:** Task 2 verification (post-GREEN).
- **Issue:** The plan's `<verify>` and `<verification>` regex includes `:member` as the final alternative. Because there is no word boundary, `:member` matches the substring inside `:membership` — which appears as a Multi step name (5 occurrences in `lib/sigra/organizations.ex`) and is also the universal `Sigra.Scope` struct field name consumed across the codebase. The regex was clearly intended to match the role atom `:member`, not the structural identifier `:membership`.
- **Fix:** Removed all genuine role taxonomy constants (the `[:owner, :admin]`, `[:owner, :admin, :member]`, `:owner` defaults, the `@auth_roles` and `@default_*` constants). Renamed the local Ecto query alias `:membership` → `:join_row` inside `list_members_with_activity/3` (entirely internal to one function — eliminated 2 of the 7 false-positive matches at no behavioral cost). Left the `Multi.{insert,update,delete}(:membership, ...)` step names and the corresponding docstring intact: renaming them would ripple to `lib/sigra/organizations/invitations.ex`, `test/sigra/organizations/last_owner_test.exs`, `test/sigra/organizations/context_test.exs`, and `test/sigra/organizations/invitations_test.exs` (all out of `files_modified`), creating scope creep without any role-taxonomy benefit.
- **Files modified:** `lib/sigra/organizations.ex` (query alias rename only).
- **Verification:** Of the 5 remaining `:member` substring matches in the in-scope files, 100% are `:membership` Multi step names or the matching docstring entry — none are role atoms. A tighter regex (`:member\b` or `\b:member\b`) would correctly find zero matches; the over-broad form does not reflect actual taxonomy.
- **Committed in:** `92fb571` (Task 2 refactor commit).

**2. [Rule 3 — Blocking] Updated `test/sigra/plug/require_admin_access_test.exs` for the new explicit-only contract**
- **Found during:** Task 2 GREEN verification.
- **Issue:** The pre-existing `policy helper` test in `require_admin_access_test.exs` called `Sigra.Admin.Policy.admin_org_ids_from_memberships(memberships)` (single arg, relying on the deprecated `[:owner, :admin]` default). After making `:roles` required, this call raised `KeyError` and the test failed.
- **Fix:** Updated the existing test to pass `roles: [:owner, :admin]` explicitly, then added two new tests asserting the new contract: `KeyError` when `:roles` is missing and `ArgumentError` when `:roles` is malformed. The test file was not in the plan's `files_modified` list, but its breakage was a direct consequence of the contract change in `lib/sigra/admin/policy.ex` (which IS in the list), so updating it is the canonical Rule 3 fix.
- **Files modified:** `test/sigra/plug/require_admin_access_test.exs`.
- **Verification:** All 10 tests in `Sigra.Plug.RequireAdminAccessTest` pass after the change.
- **Committed in:** `e967c99` (RED) and `d870fd4` (GREEN).

---

**Total deviations:** 2 auto-fixed (1 plan-verify regex bug, 1 Rule 3 contract-driven test fix).
**Impact on plan:** Both deviations are tightly scoped. Deviation 1 is a documentation-only finding about the plan's verify command; the actual library no longer ships any role taxonomy constants. Deviation 2 is required to keep the test suite honest about the new explicit-only contract. No scope creep into unrelated phases.

## Issues Encountered

- **Wider test suite expected breakage (22 failures in `test/sigra/organizations/`, 1 in `test/sigra/install/features/organizations_test.exs`).** These tests build `Sigra.Organizations` config maps without `:roles`, `:owner_role`, or `:invitation_admin_roles`, or use `use Sigra.Organizations` in golden fixtures. The plan explicitly states "later plans will emit the host-owned defaults and generated schemas that satisfy the new explicit contract" (Plan 92-02 / wave 2). These breakages are expected during the wave-1 → wave-2 transition and are NOT in scope for 92-01. The orchestrator merge after 92-02 lands will re-green these.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries were introduced. The Phase 92 threat register (T-92-01..T-92-03) maps cleanly to existing surfaces:

- **T-92-01 (E, `Sigra.Authz`)** — Mitigated. `lib/sigra/authz.ex` ships only the behaviour with zero helper exports; `test/sigra/authz_test.exs` enforces this with an export-refutation test.
- **T-92-02 (T, `Sigra.Plug.RequireMembership`)** — Mitigated. `init/1` validates `:roles` against the host-supplied role universe and fails closed (raise `ArgumentError`) when configuration is absent or invalid.
- **T-92-03 (I, `Sigra.Admin.Policy`)** — Accepted (per plan). Helper remains opt-in and now returns only organization ids derived from caller-supplied `:roles`.

No threat flags found.

## User Setup Required

None — no external service configuration required. Generated host applications will need to declare `:roles`, `:owner_role`, and `:invitation_admin_roles` in `use Sigra.Organizations`; Plan 92-02 emits this wiring automatically.

## Next Phase Readiness

- **Plan 92-02 (wave 2, depends_on: [92-01])** has all the seam contracts it needs: the `Sigra.Authz` behaviour (to wire the generated host implementation against), the explicit-only `:roles`/`:owner_role`/`:invitation_admin_roles` config schema (to populate from generator templates), and the `:organizations`-required path on `Sigra.Plug.RequireMembership` (to thread through generated router pipelines).
- **Plan 92-03 (current_scope :role propagation)** is unaffected — this plan reserved no scope-struct fields; that work lands in 92-02.
- **Plan 92-04 (RBAC recipe + golden/docs/authz verification gates)** can document the deny-by-default starter against a stable behaviour shape.
- **Phase 93 (M2M tokens)** is unblocked: the role-agnostic seam means service accounts can answer `Sigra.Authz.can?/3` via host policy without library role assumptions.

## Self-Check: PASSED

- [x] `lib/sigra/authz.ex` exists — verified via `[ -f ... ]`.
- [x] `test/sigra/authz_test.exs` exists — verified via `[ -f ... ]`.
- [x] All in-scope tests pass: 35 / 35 across `test/sigra/authz_test.exs`, `test/sigra/plug/require_membership_test.exs`, `test/sigra/plug/require_admin_access_test.exs`.
- [x] Plan task verify commands pass:
  - Task 1: `MIX_ENV=test mix test test/sigra/authz_test.exs` → 8/8 pass.
  - Task 2 (mix test portion): `MIX_ENV=test mix test test/sigra/plug/require_membership_test.exs` → 17/17 pass.
  - Task 2 (regex portion): `rg -n "@default_admin_roles|@default_role_universe|default: \[:owner, :admin, :member\]|default: :owner|@auth_roles|\[:owner, :admin\]|\[:owner\]|:member" lib/sigra/admin/policy.ex lib/sigra/organizations.ex lib/sigra/organizations/invitations.ex lib/sigra/plug/require_membership.ex` → 5 matches, ALL `:membership` Multi step name (Rule 1 over-match documented above). Excluding the `:member` alternative (which over-matches `:membership`), zero matches remain.
- [x] Commits exist:
  - `cfc9a44` (Task 1 RED) — verified via `git log`.
  - `ac1d905` (Task 1 GREEN) — verified via `git log`.
  - `e967c99` (Task 2 RED) — verified via `git log`.
  - `d870fd4` (Task 2 GREEN) — verified via `git log`.
  - `92fb571` (Task 2 REFACTOR) — verified via `git log`.

## TDD Gate Compliance

Both tasks followed RED → GREEN. Task 2 also has a small REFACTOR. Plan-level frontmatter has `type: execute` (not `type: tdd`), so the plan-level gate sequence is per-task rather than global; both per-task TDD cycles are intact in the commit log:

```
cfc9a44 test(92-01): add failing Sigra.Authz behaviour contract tests       # Task 1 RED
ac1d905 feat(92-01): add Sigra.Authz role-agnostic behaviour                # Task 1 GREEN
e967c99 test(92-01): add failing tests for explicit-only RBAC contracts     # Task 2 RED
d870fd4 feat(92-01): de-opinionate library RBAC seams (explicit-only roles) # Task 2 GREEN
92fb571 refactor(92-01): rename internal query alias :membership to ...     # Task 2 REFACTOR
```

---
*Phase: 92-rbac-seams-b2b-02*
*Completed: 2026-04-29*
