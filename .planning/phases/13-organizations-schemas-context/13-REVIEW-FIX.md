---
phase: 13
fixed_at: 2026-04-12
review_path: .planning/phases/13-organizations-schemas-context/13-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 9
skipped: 2
status: partial
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-04-12
**Source review:** .planning/phases/13-organizations-schemas-context/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (3 Critical + 8 Warning)
- Fixed: 9
- Skipped: 2 (both are missing-test-coverage recommendations, not code bugs)

All 1428 tests pass after every committed fix. The full suite was re-run
after each batch of related changes to `lib/sigra/organizations.ex`,
`lib/sigra/organizations/query.ex`, and the generated schema templates.

## Fixed Issues

### CR-01: `guard_last_owner` does not lock the membership row being acted on

**Files modified:** `lib/sigra/organizations.ex`
**Commit:** e224b5c
**Applied fix:** Changed `guard_last_owner/4` to lock ALL owner rows for the
org via `FOR UPDATE` (removed the `m.id != ^membership_id` filter from the
DB query) and moved the exclusion of the current membership into an in-memory
`Enum.reject/2` after the lock. This guarantees concurrent removers/demoters
serialize on the same row set rather than each observing the other as "the
survivor". Added a comment block explaining the invariant and the reason
PostgreSQL rejects FOR UPDATE with aggregates.

### CR-02: `OrganizationMembership.changeset/2` casts only `:role`

**Files modified:**
- `priv/templates/sigra.install/organizations/organization_membership.ex`
- `test/example/lib/example/accounts/organization_membership.ex`

**Commit:** 86548ef
**Applied fix:** Expanded `cast/3` to include `:user_id` and `:organization_id`,
added them to `validate_required/2`, and added `assoc_constraint(:user)` and
`assoc_constraint(:organization)`. Mirrored to the example app copy. The
library's own `build_membership_changeset` still uses `put_change` — the fix
closes the gap for host apps that invoke the generated changeset directly.

### CR-03: Generated `OrganizationInvitation.changeset/2` cannot successfully insert

**Files modified:**
- `priv/templates/sigra.install/organizations/organization_invitation.ex`
- `test/example/lib/example/accounts/organization_invitation.ex`

**Commit:** 13cd5f3
**Applied fix:** Added `:organization_id`, `:invited_by_id`, and
`:accepted_by_id` to `cast/3`; added `:organization_id` to `validate_required/2`;
added `assoc_constraint(:organization)`; and added the
`unique_constraint([:organization_id, :email], name: :organization_invitations_pending_index)`
constraint to the library template (the example mirror already had it).

### WR-03: `maybe_generate_slug` silently overwrites slug on update (+ WR-08 empty-string edge case)

**Files modified:** `lib/sigra/organizations.ex`
**Commit:** bdc65dd
**Applied fix:** Removed the `maybe_generate_slug(attrs)` call from
`update_org_changeset/3`, with an explanatory comment that auto-regenerating
a slug on rename would silently rewrite URLs. Also tightened
`maybe_generate_slug/1` to reject empty-string names (`is_binary(name) and
name != ""`) addressing WR-08. Also switched `build_org_changeset/3` and
`update_org_changeset/3` to reference the partial index name
`:organizations_slug_active_index` in their `unique_constraint(:slug, ...)`
calls, addressing the library-side half of WR-06.

### WR-06: `unique_constraint(:slug)` does not reference the partial index name (template half)

**Files modified:**
- `priv/templates/sigra.install/organizations/organization.ex`
- `test/example/lib/example/accounts/organization.ex`

**Commit:** c252340
**Applied fix:** Updated both the installer template and the example app
mirror to use `unique_constraint(:slug, name: :organizations_slug_active_index)`
so host-app changesets match the partial unique index from the migration.

### WR-04 + WR-05: `has_org_id_filter?` false positives and fails open on rescue

**Files modified:** `lib/sigra/organizations/query.ex`
**Commit:** 2134085
**Applied fix:** Rewrote the AST walker to require a *pinned* equality
between `r.organization_id` (from any binding) and a pinned parameter (`^`)
or literal. The new `expr_pins_org_id?/1` rejects:
- `r.organization_id == r2.organization_id` (cross-tenant joins)
- `is_nil(r.organization_id)` (does not constrain to a tenant)
- `organization_id` appearing only in SELECT or unrelated call sites
It also handles `:and` / `:or` structurally: `AND` accepts if either branch
pins, `OR` requires BOTH branches to pin (otherwise a branch escapes tenancy).
Changed the rescue clause to fail CLOSED (return `false`) and log at
`Logger.error` instead of fail-open `true` + `Logger.warning`.

### WR-02: `change_role` race (same root cause as CR-01)

**Status:** Auto-resolved by CR-01 (commit e224b5c). The shared
`guard_last_owner/4` helper is now correct for both removal and demotion
paths, since `maybe_guard_last_owner_on_demote/4` delegates to it.

### WR-08: Empty-string name edge case in `maybe_generate_slug`

**Status:** Rolled into WR-03 commit (bdc65dd). See WR-03 entry above.

## Skipped Issues

### WR-01: Missing test coverage for hooks returning `{:error, reason}`

**File:** `lib/sigra/organizations.ex:259-277`
**Reason:** Skipped — this is a test-coverage recommendation, not a bug.
Adding it requires building new Mox-based inline schemas, a caller module
that implements the `before_*` behaviour callback to return `{:error, :aborted}`,
and wiring the caller into the context config. The `context_test.exs` file
currently has no hook test scaffolding to extend. Recommend addressing this
as a targeted follow-up task rather than in an auto-fix pass, since it
requires design decisions about where to place the shared stub caller
(inline per-test vs. a new support file).
**Original issue:** No test locks in the `with :ok <- run_before_hook(...)`
error-propagation behavior for `create_organization` / `add_member` /
`change_role`.

### WR-07: No integration test for `list_organizations_for_user` excluding soft-deleted orgs

**File:** `lib/sigra/organizations.ex:405-417`
**Reason:** Skipped — test-coverage recommendation, not a bug. Requires
adding a new integration test to the `test/example/test/example/organizations/`
directory with real-DB fixtures (create org, soft-delete it, create a second
org, verify only the second is returned). The existing unit test with
`MockRepo` already covers the query construction; the recommended integration
test verifies end-to-end behavior and is worth adding as a dedicated follow-up.
**Original issue:** Unit test uses a mock repo; no real-DB integration test
exercises the soft-delete filter in `list_organizations_for_user/2`.

---

_Fixed: 2026-04-12_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
