---
phase: 14-org-plugs-scope-hydration
fixed_at: 2026-04-12T17:25:00Z
review_path: .planning/phases/14-org-plugs-scope-hydration/14-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-04-12T17:25:00Z
**Source review:** .planning/phases/14-org-plugs-scope-hydration/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (1 critical + 5 warnings; 4 info findings out of scope)
- Fixed: 6
- Skipped: 0

All critical and warning findings were fixed atomically with per-finding
commits. Verification: `mix test` passes 1496 tests (baseline 1494 + 2
regression tests added by this fix pass), `mix compile
--warnings-as-errors` is clean, `mix credo --strict` shows only
pre-existing refactor suggestions on the touched files (no new issues
introduced).

## Fixed Issues

### CR-01: Generated organizations.ex template will fail to compile against Sigra.Organizations.__using__/1

**Files modified:** `priv/templates/sigra.install/organizations/organizations.ex`, `test/sigra/install/features/organizations_test.exs`
**Commit:** 607a32d
**Applied fix:** Nested `organization`, `membership`, `invitation`, `user`,
`scope` under a `schemas: [...]` keyword list so the template matches the
library's NimbleOptions schema. Added a compile-time regression test that
renders the EEx template against stub schema modules and
`Code.compile_string/1`s the result end-to-end against the real
`Sigra.Organizations.__using__/1` macro — this catches future
schema/template drift that a simple `=~` string-match cannot see.
**Human verification requested:** No (template validated by round-trip compile).

### WR-01: Sigra.Plug.PutActiveOrganization.call/3 does not nil-guard session or scope.user

**Files modified:** `lib/sigra/plug/put_active_organization.ex`
**Commit:** 0c3405d
**Applied fix:** Wrapped both `call/3` clauses in a `with` pipeline that
matches `%Sigra.Session{}` on `conn.private[:sigra_session]` and
`%{user: %_{}}` on `conn.assigns[:current_scope]`. Added
`{:error, :no_session}` and `{:error, :no_scope}` to `@type call_error`
and documented both in the moduledoc. Fail-closed: no crash, no write,
clean error tuple returned to the caller.

### WR-02: Sigra.Scope.Hydration.hydrate/3 assumes scope.user is non-nil

**Files modified:** `lib/sigra/scope/hydration.ex`, `test/sigra/scope/hydration_test.exs`
**Commit:** 2e3a76d
**Applied fix:** Added an explicit `def hydrate(%{user: nil} = scope, _, %Sigra.Session{})`
clause that returns `{:ok, scope}` unchanged before touching
`fetch_organization/2` or `get_membership/3`. Upholds the contract that
the hydrator NEVER raises (PITFALLS O-6). Added a regression test that
exercises the nil-user path with mocked Repo and asserts no queries fire.

### WR-03: Stale-pointer recovery re-queries membership instead of using the freshly listed orgs

**Files modified:** `lib/sigra/organizations.ex`, `lib/sigra/plug/load_active_organization.ex`, `test/sigra/plug/load_active_organization_test.exs`
**Commit:** 455c7b2
**Applied fix:** Added a new public function
`Sigra.Organizations.select_active_organization_with_membership/3` that
joins `organizations` to `organization_memberships` in a single query
(`select: {o, m}`) and returns `{:ok, org, membership}` on the
single-org and resume branches. Switched the plug recovery path to use
the new variant, eliminating the extra `get_membership/3` roundtrip on
the recovery hot path. The public
`select_active_organization/3` signature is unchanged. Updated the
recovery tests in `load_active_organization_test.exs` to mock the joined
return shape `[{org, membership}]` instead of `[org]`.

### WR-04: Sigra.Auth.maybe_assign_active_organization/6 swallows all selector errors silently

**Files modified:** `lib/sigra/auth.ex`
**Commit:** 5296b69
**Applied fix:** Inside `rescue` and `catch`, emit
`Telemetry.event([:sigra, :auth, :selector_error], %{}, %{user_id:
user.id, kind: kind, reason: inspect(reason)})` before falling through
to `nil`. Login still succeeds — this is a fail-open observability fix,
not a behavior change. Operators now get a breadcrumb when a host
Organizations module is broken instead of silent degradation.

### WR-05: LoadActiveOrganization ignores update_active_organization/3 failures during clear-step of recovery

**Files modified:** `lib/sigra/plug/load_active_organization.ex`
**Commit:** 4781868
**Applied fix:** Switched both `update_active_organization/3` calls in
the recovery path from strict `{:ok, ...} =` matches to `case`
statements that tolerate `{:error, _reason}` and fall through to a safe
empty-org scope. The plug still never halts; if the session row was
deleted concurrently by `delete_all_for_user/2` on another node, the
next request re-hydrates cleanly or the auth plug redirects to login.
**Human verification requested:** No (defensive pattern match, behavior
verified by existing recovery tests).

## Skipped Issues

None.

---

_Fixed: 2026-04-12T17:25:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
