---
phase: 14-org-plugs-scope-hydration
fixed_at: 2026-04-12T17:45:00Z
review_path: .planning/phases/14-org-plugs-scope-hydration/14-REVIEW.md
iteration: 2
findings_in_scope: 10
fixed: 9
skipped: 1
status: partial
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-04-12T17:45:00Z
**Source review:** .planning/phases/14-org-plugs-scope-hydration/14-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 10 (1 critical + 5 warnings + 4 info)
- Fixed: 9 (6 from iteration 1 + 3 new info fixes)
- Skipped: 1 (IN-04 — stale/incorrect finding; spec is already correct)

Iteration 1 resolved CR-01 and WR-01..WR-05. Iteration 2 resolved IN-01,
IN-02, and IN-03. IN-04 is a stale finding: the reviewer missed the
`handle_valid_login_with_security/6` clause that produces the 3-tuple
shape, and tests already pin it. Verification: `mix test` passes 1499
tests (1496 baseline + 3 new RequireMembership regression tests for
IN-03), `mix compile --warnings-as-errors` is clean, `mix credo --strict`
on touched files shows only a single pre-existing nested-depth warning
in `select_active_organization_with_membership/3` (iteration-1 code, not
touched this pass).

## Fixed Issues

### CR-01: Generated organizations.ex template will fail to compile against Sigra.Organizations.__using__/1

**Iteration:** 1
**Files modified:** `priv/templates/sigra.install/organizations/organizations.ex`, `test/sigra/install/features/organizations_test.exs`
**Commit:** 607a32d
**Applied fix:** Nested `organization`, `membership`, `invitation`, `user`,
`scope` under a `schemas: [...]` keyword list so the template matches the
library's NimbleOptions schema. Added a compile-time regression test that
renders the EEx template against stub schema modules and
`Code.compile_string/1`s the result end-to-end against the real
`Sigra.Organizations.__using__/1` macro — this catches future
schema/template drift that a simple `=~` string-match cannot see.

### WR-01: Sigra.Plug.PutActiveOrganization.call/3 does not nil-guard session or scope.user

**Iteration:** 1
**Files modified:** `lib/sigra/plug/put_active_organization.ex`
**Commit:** 0c3405d
**Applied fix:** Wrapped both `call/3` clauses in a `with` pipeline that
matches `%Sigra.Session{}` on `conn.private[:sigra_session]` and
`%{user: %_{}}` on `conn.assigns[:current_scope]`. Added
`{:error, :no_session}` and `{:error, :no_scope}` to `@type call_error`
and documented both in the moduledoc. Fail-closed: no crash, no write,
clean error tuple returned to the caller.

### WR-02: Sigra.Scope.Hydration.hydrate/3 assumes scope.user is non-nil

**Iteration:** 1
**Files modified:** `lib/sigra/scope/hydration.ex`, `test/sigra/scope/hydration_test.exs`
**Commit:** 2e3a76d
**Applied fix:** Added an explicit `def hydrate(%{user: nil} = scope, _, %Sigra.Session{})`
clause that returns `{:ok, scope}` unchanged before touching
`fetch_organization/2` or `get_membership/3`. Upholds the contract that
the hydrator NEVER raises (PITFALLS O-6). Added a regression test that
exercises the nil-user path with mocked Repo and asserts no queries fire.

### WR-03: Stale-pointer recovery re-queries membership instead of using the freshly listed orgs

**Iteration:** 1
**Files modified:** `lib/sigra/organizations.ex`, `lib/sigra/plug/load_active_organization.ex`, `test/sigra/plug/load_active_organization_test.exs`
**Commit:** 455c7b2
**Applied fix:** Added a new public function
`Sigra.Organizations.select_active_organization_with_membership/3` that
joins `organizations` to `organization_memberships` in a single query
(`select: {o, m}`) and returns `{:ok, org, membership}` on the
single-org and resume branches. Switched the plug recovery path to use
the new variant, eliminating the extra `get_membership/3` roundtrip on
the recovery hot path. The public `select_active_organization/3`
signature is unchanged. Updated the recovery tests in
`load_active_organization_test.exs` to mock the joined return shape
`[{org, membership}]` instead of `[org]`.

### WR-04: Sigra.Auth.maybe_assign_active_organization/6 swallows all selector errors silently

**Iteration:** 1
**Files modified:** `lib/sigra/auth.ex`
**Commit:** 5296b69
**Applied fix:** Inside `rescue` and `catch`, emit
`Telemetry.event([:sigra, :auth, :selector_error], %{}, %{user_id:
user.id, kind: kind, reason: inspect(reason)})` before falling through
to `nil`. Login still succeeds — this is a fail-open observability fix,
not a behavior change. Operators now get a breadcrumb when a host
Organizations module is broken instead of silent degradation.

### WR-05: LoadActiveOrganization ignores update_active_organization/3 failures during clear-step of recovery

**Iteration:** 1
**Files modified:** `lib/sigra/plug/load_active_organization.ex`
**Commit:** 4781868
**Applied fix:** Switched both `update_active_organization/3` calls in
the recovery path from strict `{:ok, ...} =` matches to `case`
statements that tolerate `{:error, _reason}` and fall through to a safe
empty-org scope. The plug still never halts; if the session row was
deleted concurrently by `delete_all_for_user/2` on another node, the
next request re-hydrates cleanly or the auth plug redirects to login.

### IN-01: audit_opts in LoadActiveOrganization is opt-in but undocumented at call sites

**Iteration:** 2
**Files modified:** `lib/sigra/plug/load_active_organization.ex`
**Commit:** c6dc641
**Applied fix:** Implemented option (a) from the review — when `:audit_opts`
is absent (or an empty list), the plug now auto-derives
`[repo: config.repo, audit_schema: config.audit_schema]` from the host's
`__sigra_org_config__/0` via a new `resolve_audit_opts/2` helper. Out-of-
the-box installs that declare `audit_schema:` in their
`use Sigra.Organizations` block now write the documented
`"organization.active_auto_reassigned"` audit event without requiring
router-level opt-in. Hosts with `audit_schema: nil` (the default) stay
no-op via `Audit.log_safe/2` — behavior unchanged. Existing
`LoadActiveOrganizationTest` suite passes unchanged because the test
`TestOrganizations` fixture already uses `audit_schema: nil`.

### IN-02: list_organizations_for_user/2 orders by name; select_active_organization/3 re-sorts

**Iteration:** 2
**Files modified:** `lib/sigra/organizations.ex`
**Commit:** 316e03b
**Applied fix:** Dropped `order_by: [asc: o.name]` from
`list_organizations_for_user/2` — the only library caller
(`select_active_organization/3`) throws the order away and re-sorts by
`inserted_at desc`, so the DB sort was wasted work AND misleading for
external callers. Updated the `@doc` to explicitly state the order is
unspecified and that callers needing a stable UI listing should sort
themselves. Existing context tests do not assert on ordering; they
continue to pass.
**Human verification requested:** Yes — this is technically a
semi-public API shape change. Any downstream Phase 16+ caller that
assumed alphabetical ordering from this function will now need to sort
explicitly. Recommend a grep for `list_organizations_for_user` before
merging Phase 16 LiveViews.

### IN-03: RequireMembership.@role_universe duplicates Sigra.Organizations defaults

**Iteration:** 2
**Files modified:** `lib/sigra/plug/require_membership.ex`, `test/sigra/plug/require_membership_test.exs`
**Commit:** 0833f31
**Applied fix:** Added a new optional `:organizations` option to
`Sigra.Plug.RequireMembership`. When passed, `init/1` reads the role
universe from `organizations.__sigra_org_config__().roles` via a new
`resolve_role_universe/1` helper, so hosts can extend the role list
(`:viewer`, `:billing`, etc.) in their `use Sigra.Organizations` block
and the plug will validate against the actual host roles. When
`:organizations` is absent, the plug falls back to the canonical
`[:owner, :admin, :member]` universe (preserved as
`@default_role_universe`), so existing call sites work unchanged.
Renamed the module attribute to make the fallback intent explicit.
Added 3 regression tests: accepts host-extended roles when
`:organizations` is passed, rejects unknown atoms against host config,
and without `:organizations` still rejects custom roles. All 15 plug
tests pass (was 12 before this fix). `resolve_role_universe/1` is
defensive — it catches `UndefinedFunctionError` so a rare compile-time
module-load race cannot crash `init/1`.

## Skipped Issues

### IN-04: Spec for Sigra.Auth.authenticate/3 lists return shape {:ok, struct(), map()} that no clause produces

**Iteration:** 2
**File:** `lib/sigra/auth.ex:271-275`
**Reason:** Stale/incorrect finding — the `{:ok, struct(), map()}` shape IS
produced by a clause the reviewer missed. Specifically,
`authenticate_with_config/2` (line 277) routes to
`handle_valid_login_with_security/6` at line 1441, which returns
`{:ok, updated_user, result}` on line 1488 where `result` is a map
containing `:session`, optional `:mfa_required`, and optional
`:suspicious_login` keys. The shape is already pinned by tests:
`test/sigra/auth_test.exs:1508` asserts
`{:ok, _user, %{session: _, mfa_required: true}}` against the config
path with an MFA user, and `test/sigra/auth_test.exs:1562` asserts
`{:ok, _user, %{session: _}}` against the config path with a standard
user. The 2-tuple `{:ok, struct()}` shape is produced by the legacy
keyword-form `authenticate/3` (line 281), which does NOT compose with
sessions. Both branches of the spec are live and both are regression-
tested. No code change required.
**Original issue:** "Either dead spec branch or the implementation that
returns the tuple lives elsewhere without coverage. Either way, dialyzer
can't catch the drift."

---

_Fixed: 2026-04-12T17:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
