---
phase: 14-org-plugs-scope-hydration
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - lib/sigra/install/features/core.ex
  - lib/sigra/install/features/organizations.ex
  - lib/sigra/organizations.ex
  - lib/sigra/plug/error_handler.ex
  - lib/sigra/plug/load_active_organization.ex
  - lib/sigra/plug/put_active_organization.ex
  - lib/sigra/plug/require_membership.ex
  - lib/sigra/scope/hydration.ex
  - lib/sigra/session_store.ex
  - lib/sigra/session_stores/ecto.ex
  - priv/templates/sigra.install/core/error_handler.ex
  - priv/templates/sigra.install/core/scope.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - priv/templates/sigra.install/organizations/organizations.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/auth_error_handler.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/user_auth.ex
  - test/sigra/auth_org_selection_test.exs
  - test/sigra/install/features/organizations_test.exs
  - test/sigra/organizations/context_test.exs
  - test/sigra/plug/load_active_organization_test.exs
  - test/sigra/plug/put_active_organization_test.exs
  - test/sigra/plug/require_membership_test.exs
  - test/sigra/scope/hydration_test.exs
  - test/sigra/scope/plug_liveview_parity_test.exs
  - test/sigra/session_stores/ecto_test.exs
  - test/sigra/session_test.exs
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

Phase 14 introduces the org-aware scope-hydration pipeline, the three library
plugs (`LoadActiveOrganization`, `RequireMembership`, `PutActiveOrganization`),
the shared `Sigra.Scope.Hydration` primitive, and the install-time templates
that wire them into a host app. Overall the design is solid: the fail-closed
hydrator/fail-open login split is correctly implemented, the stale-pointer
recovery flow does not resume the bad pointer (D-14), the membership-before-
write authz choke point in `PutActiveOrganization` is verified by tests, and
the no-op short-circuit in `SessionStores.Ecto.update_active_organization/3`
keeps hot paths quiet.

The most important finding is **CR-01**: the generated `organizations.ex`
template passes schema modules at the top level of `use Sigra.Organizations`,
but the library's NimbleOptions schema requires them nested under `:schemas:`.
A freshly-generated host app will fail to compile. The golden install test
does not catch this because no compile step exercises the generated wrapper
against the real `__using__` macro.

The remaining findings are smaller: a handful of nil-guarding gaps in the two
write/read plugs, an N+1 in stale-pointer recovery, an audit-opts dead path,
and a couple of doc/spec drifts.

## Critical Issues

### CR-01: Generated `organizations.ex` template will fail to compile against `Sigra.Organizations.__using__/1`

**File:** `priv/templates/sigra.install/organizations/organizations.ex:27-33`
**Issue:** The template renders:

```elixir
use Sigra.Organizations,
  repo: <%= repo_module %>,
  organization: <%= app_module %>.Organization,
  membership: <%= app_module %>.OrganizationMembership,
  invitation: <%= app_module %>.OrganizationInvitation,
  user: <%= context_module %>.<%= schema_alias %>,
  scope: <%= context_module %>.Scope
```

But `Sigra.Organizations.@org_config_schema` (lib/sigra/organizations.ex:38-101)
declares `:schemas` as a **required keyword list** with the per-entity modules
nested under it:

```elixir
schemas: [
  type: :keyword_list,
  required: true,
  keys: [
    organization: [...],
    membership: [...],
    invitation: [...],
    user: [...],
    scope: [...]
  ]
]
```

`__using__/1` calls `Sigra.Organizations.__validate_config__!/1` at compile
time, which routes through `NimbleOptions.validate!/2`. The flat keyword list
emitted by the template will trigger one of:

- `unknown options [:organization, :membership, :invitation, :user, :scope]`, or
- `required option :schemas not found`

…the moment a host app starts up after `mix sigra.install`. The library's own
moduledoc example (lib/sigra/organizations.ex:14-25) shows the correct nested
shape, and `Sigra.Plug.LoadActiveOrganizationTest.TestOrganizations` (and the
other test stubs) all assemble the config with `schemas: %{...}`. Only the
generated template is wrong.

The golden install fixture
(`test/fixtures/install_golden/tree/...`) does not include
`organizations.ex` at the host-app level, so the existing
`Sigra.Install.Features.OrganizationsTest` only string-matches the template
body — there is no test that actually compiles the rendered output against
the real `use Sigra.Organizations` macro. That blind spot is what let this
slip through.

**Fix:** Change the template to nest the schemas:

```elixir
defmodule <%= app_module %>.Organizations do
  use Sigra.Organizations,
    repo: <%= repo_module %>,
    schemas: [
      organization: <%= app_module %>.Organization,
      membership: <%= app_module %>.OrganizationMembership,
      invitation: <%= app_module %>.OrganizationInvitation,
      user: <%= context_module %>.<%= schema_alias %>,
      scope: <%= context_module %>.Scope
    ]

  defdelegate set_active_organization(conn, org),
    to: Sigra.Plug.PutActiveOrganization,
    as: :call
end
```

Then add a test that boots EEx through the same binding the walker passes
and `Code.compile_string/1`s the result against the real `Sigra.Organizations`
to catch any future schema/template drift.

## Warnings

### WR-01: `Sigra.Plug.PutActiveOrganization.call/3` does not nil-guard `session` or `scope.user`

**File:** `lib/sigra/plug/put_active_organization.ex:62-103`
**Issue:** Both function clauses pull `session = conn.private[:sigra_session]`
and `scope = conn.assigns[:current_scope]` and pass them directly into
`session_store.update_active_organization/3` and
`Organizations.get_membership/3` without checking for `nil`. If a controller
ever invokes `set_active_organization` from a request that hasn't run the
session-fetch plug (or where the user logged out mid-request), the call
crashes with a `FunctionClauseError` deep inside the SessionStore or with a
`KeyError` on `nil.id` inside the membership query — and the host app sees a
500 instead of a clean `{:error, :unauthenticated}`-shaped reject.

This matters more than the tests suggest because the docstring positions this
as "the single authoritative write site," which means callers in Phase 16+
(switcher controller, invitation accept) and later third-party code will rely
on it without re-validating session presence themselves.

**Fix:**

```elixir
def call(%Plug.Conn{} = conn, target, opts) do
  with %Sigra.Session{} = session <- conn.private[:sigra_session] || {:error, :no_session},
       %{user: %_{}} = scope <- conn.assigns[:current_scope] || {:error, :no_scope} do
    do_call(conn, session, scope, target, opts)
  else
    {:error, _} = err -> err
  end
end
```

…and document `:no_session` / `:no_scope` in `@type call_error`.

### WR-02: `Sigra.Scope.Hydration.hydrate/3` assumes `scope.user` is non-nil

**File:** `lib/sigra/scope/hydration.ex:58-69`
**Issue:** The non-nil-pointer clause does `user = scope.user` and then
`Organizations.get_membership(config, user, org)`. `get_membership/3` builds
`where: m.user_id == ^user.id`, which raises `KeyError` if `user` is nil. The
hydrator's contract says it "NEVER raises … specifically to keep
Ecto.NoResultsError out of the request pipeline (PITFALLS O-6)" — but a nil
user would still raise.

The plug call site filters `is_nil(scope)` but not `is_nil(scope.user)`, so
the only thing keeping this safe today is the convention that the auth plug
populates a scope only when a user exists. That convention is correct but
fragile, and the hydrator is the documented "single place scope hydration
lives" — it should be defensive on its own boundary.

**Fix:** Either pattern-match on `%{user: %_{} = user}` in the head and add
an explicit fail-closed clause for the nil-user case, or add an early
`is_nil(scope.user) -> {:ok, scope}` short-circuit. Then add a regression
test in `Sigra.Scope.HydrationTest`.

### WR-03: Stale-pointer recovery re-queries membership instead of using the freshly listed orgs

**File:** `lib/sigra/plug/load_active_organization.ex:126-132`
**Issue:** `apply_selection({:ok, new_org}, ...)` calls
`Organizations.get_membership(config, scope.user, new_org)` immediately after
`Organizations.select_active_organization/3` already did
`list_organizations_for_user(config, user)`. That means the recovery path
costs **three** DB roundtrips (`fetch_organization` + the failed
`get_membership` from the original hydrate, then `list_organizations_for_user`,
then this extra `get_membership`). For the resume path we already know the
user is a member of every org we listed — listing already joined through
`organization_memberships`. The extra membership lookup is dead weight on the
hot recovery path.

This is not a correctness issue, but the hydration contract loudly advertises
"only the reads necessary," and the recovery path is the one place where a
user with a stale pointer pays a perf tax. With many concurrent users hit
during a deploy that drops them all into recovery at once, this adds 33% to
the SQL load.

**Fix:** Have `select_active_organization/3` return `{:ok, org, membership}`
on the resume / single-org branch (it already touched the join), and let
`apply_selection` use that directly. Alternatively, keep the public selector
signature stable and add a private `select_with_membership/3` that the plug
calls.

### WR-04: `Sigra.Auth.maybe_assign_active_organization/6` swallows all selector errors silently

**File:** `lib/sigra/auth.ex:1037-1075`
**Issue:** The `try/rescue/catch` around the selector is the right call for
T-14-13 (login must not fail on selector raise), but every failure is
collapsed to `nil` with no telemetry, no log line, and no audit row. If the
host app's `MyApp.Organizations` module starts raising — bad migration, typo
in schema config, NimbleOptions failure on a field that wasn't validated at
boot — every login silently degrades to "no active org" and the operator has
no signal beyond user reports.

Login is the right place to be paranoid and continue, but it is the wrong
place to be silent. The login MUST succeed; it MUST also leave a breadcrumb.

**Fix:** Inside `rescue` and `catch`, emit
`Telemetry.event([:sigra, :auth, :selector_error], %{}, %{user_id: user.id, kind: kind, reason: inspect(reason)})`
and (optionally) `Logger.warning/1` once. Audit is overkill since this is
not user-attributable, but telemetry is essential.

### WR-05: `LoadActiveOrganization` ignores `update_active_organization/3` failures during clear-step of recovery

**File:** `lib/sigra/plug/load_active_organization.ex:96`
**Issue:** The recovery path matches `{:ok, cleared_session}` with a strict
pattern:

```elixir
{:ok, cleared_session} = session_store.update_active_organization(session, nil, store_opts)
```

If the session row was deleted concurrently (`{:error, :not_found}`), this
crashes the request with a `MatchError` mid-pipeline — the exact failure mode
the fail-closed hydrator design was built to avoid. The same row could be
deleted by `delete_all_for_user/2` running on another node during a forced
logout cascade.

**Fix:** Match both branches and fall through to a safe scope:

```elixir
case session_store.update_active_organization(session, nil, store_opts) do
  {:ok, cleared} -> ...continue recovery...
  {:error, :not_found} ->
    Plug.Conn.assign(conn, :current_scope,
      %{scope | active_organization: nil, membership: nil})
end
```

The same defensive treatment should apply to the second
`update_active_organization` call inside `apply_selection({:ok, new_org}, ...)`.

## Info

### IN-01: `audit_opts` in `LoadActiveOrganization` is opt-in but undocumented at call sites

**File:** `lib/sigra/plug/load_active_organization.ex:46-48, 93`
**Issue:** `:audit_opts` defaults to `[]`, so `Audit.log_safe/2` is a no-op
unless the host explicitly threads `[audit_schema: ..., repo: ...]` through
the router pipeline. The moduledoc mentions this in passing, but neither the
generated `router.ex` injection (lib/sigra/install/features/core.ex:415-418)
nor the README example wires it. Result: the documented audit event
`"organization.active_auto_reassigned"` is never written for any out-of-the-
box install.

**Fix:** Either (a) resolve audit opts from `Sigra.Config` when not passed,
or (b) update the router injection in `Features.Core.router_injection/3` to
include `audit_opts: [...]`. Option (a) is cleaner.

### IN-02: `Sigra.Organizations.list_organizations_for_user/2` orders by name; `select_active_organization/3` re-sorts by inserted_at desc

**File:** `lib/sigra/organizations.ex:425, 504`
**Issue:** The DB query orders by `o.name asc`, then the selector immediately
re-sorts the result list by `inserted_at desc`. The first sort is wasted work
and (more importantly) misleading — anyone reading
`list_organizations_for_user` will assume callers can rely on name ordering,
but the only library caller throws that order away.

**Fix:** Drop `order_by` from `list_organizations_for_user/2` (callers that
want a stable UI listing should sort themselves), or split into
`list_organizations_for_user/2` (name asc, public) and
`list_organizations_for_user_recent/2` (inserted_at desc, internal) and use
the latter from the selector.

### IN-03: `Sigra.Plug.RequireMembership.@role_universe` duplicates `Sigra.Organizations` defaults

**File:** `lib/sigra/plug/require_membership.ex:43`
**Issue:** `@role_universe [:owner, :admin, :member]` is a hardcoded module
attribute, but `Sigra.Organizations.@org_config_schema` declares the same
list as the default for `:roles`. If a host app extends roles via the Phase
14 config (`:viewer`, `:billing`, etc.), the plug will reject those at
`init/1` even though the schema accepts them. The moduledoc acknowledges this
("If the host org config's role list grows, update this module attribute …
in lockstep") but lockstep with library-internal state is the opposite of
the "library is org-aware, hosts customize" story.

**Fix:** Make `init/1` look up the host's role list at compile time via the
`:organizations` module (similar to how `LoadActiveOrganization` reads
`__sigra_org_config__/0`). Defer the validation to first `call/2` if needed
to avoid coupling `init/1` to the org module being compiled first.

### IN-04: Spec for `Sigra.Auth.authenticate/3` lists return shape `{:ok, struct(), map()}` that no clause produces

**File:** `lib/sigra/auth.ex:271-275`
**Issue:** The `@spec` declares
`{:ok, struct()} | {:ok, struct(), map()} | {:error, ...}`, but neither
`authenticate_with_config/2` nor the keyword-form `authenticate/3` returns
the 3-tuple shape anywhere I can see in the file slice reviewed. Either dead
spec branch or the implementation that returns the tuple lives elsewhere
without coverage. Either way, dialyzer can't catch the drift.

**Fix:** If a callback site does return `{:ok, user, metadata}`, add a
regression test that pins the shape; otherwise drop the dead branch from the
spec.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
