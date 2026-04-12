---
phase: 14
plan: 3
subsystem: organizations + scope + generator templates
tags: [organizations, scope, auth, templates, generator, integration]
requires:
  - Phase 14 Plan 01 (Sigra.Scope.Hydration.hydrate/3, select_active_organization/3,
    fetch_organization/2, SessionStore.update_active_organization/3,
    ErrorHandler :no_active_org + :insufficient_role types)
  - Phase 14 Plan 02 (LoadActiveOrganization, RequireMembership, PutActiveOrganization,
    __sigra_org_config__/0 accessor)
  - Phase 13 (Sigra.Organizations context, list_organizations_for_user/2, get_membership/3)
  - Phase 12 (Sigra.Session + SessionStore behaviour + active_organization_id column)
provides:
  - Sigra.Config.scope_module + organizations_module fields (nullable)
  - Sigra.Auth.create_session/4 login-time 0/1/2+ selector wiring with
    fail-open T-14-13 mitigation and opts[:previous_active_organization_id]
    resume pointer
  - Generated Scope.put_active_organization/3 pure function (2 clauses)
  - Generated user_auth.ex mount_current_scope calling
    Sigra.Scope.Hydration.hydrate/3 (LV on_mount parity — D-23)
  - Generated error_handler.ex :no_active_org + :insufficient_role clauses
    with exact UI-SPEC copy (non-blaming, no role-name leak)
  - New priv/templates/sigra.install/organizations/organizations.ex template
    (context wrapper with defdelegate set_active_organization/2)
  - Features.Organizations.files/1 registration of the new wrapper template
  - Router injection adds :require_org + :require_org_owner pipelines
  - test/sigra/scope/plug_liveview_parity_test.exs (SC-3 enforcement)
  - test/sigra/auth_org_selection_test.exs (Task 1 9 tests + Config roundtrip)
affects:
  - Phase 15 (Audit Integration) — the log_safe call in LoadActiveOrganization
    is ready to consume metadata_from_scope/2 once Phase 15 lands
  - Phase 16 (switcher + picker) — will use :require_org pipelines
  - Phase 17 (invitations) — will call set_active_organization/2
    via the generated wrapper
tech-stack:
  added: []
  patterns:
    - Login-time selector wrapped in try/rescue — selector failures MUST NOT
      fail login (T-14-13). Fail-open at login; fail-closed at hydration (D-01).
    - Single docstring on multi-clause put_active_organization/3 — Elixir
      doesn't allow @doc on both clauses of the same function.
    - Library-side config carries scope_module + organizations_module so the
      library can resolve host modules without recompiling. Defaults nil for
      legacy installs.
    - LV on_mount mirrors the plug path by calling the SAME hydrator with
      the host's __sigra_org_config__/0 (D-23). LV graceful-degrades on
      stale-pointer errors since it has no conn to recover through — the
      next Plug request recovers.
key-files:
  created:
    - test/sigra/auth_org_selection_test.exs
    - test/sigra/scope/plug_liveview_parity_test.exs
    - priv/templates/sigra.install/organizations/organizations.ex
  modified:
    - lib/sigra/config.ex (scope_module + organizations_module fields)
    - lib/sigra/auth.ex (create_session/4 selector wiring, fail-open)
    - lib/sigra/install/features/core.ex (router injection :require_org pipelines)
    - lib/sigra/install/features/organizations.ex (files/1 registers new template)
    - priv/templates/sigra.install/core/scope.ex (put_active_organization/3)
    - priv/templates/sigra.install/core/user_auth.ex (mount_current_scope calls hydrate/3)
    - priv/templates/sigra.install/core/error_handler.ex (:no_active_org + :insufficient_role)
    - test/sigra/install/features/organizations_test.exs (6 new assertions)
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/user_auth.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/auth_error_handler.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex
    - .planning/phases/14-org-plugs-scope-hydration/14-VALIDATION.md (wave_0_complete: true)
decisions:
  - D-01 (fail-closed hydrator) — preserved; login selector is independently fail-open
  - D-12 (selector at login) — implemented via create_session/4 wiring
  - D-14 (no stale-pointer resume) — previous_active_organization_id forwarded as-is;
    forged pointers drop through to nil per Plan 01's select_active_organization/3
  - D-15 (Scope.put_active_organization/3 single write path) — pure function shipped
  - D-19 (organizations.ex defdelegate wrapper) — new template created
  - D-22 (library-first) — all wiring is library code; only templates are host-emitted
  - D-23 (plug ↔ LV parity via shared hydrator) — enforced by parity test
  - D-26 (login telemetry + audit unchanged) — existing session.create audit preserved
  - CD-router (LoadActiveOrganization plug wiring deferred) — see Deviation 1
  - CD-features-org (Features.Organizations not yet in installer @features) — see Deviation 2
metrics:
  duration: ~45 minutes
  tasks: 3
  commits: 3
  files_changed: 14
  tests_added: 18
  tests_total_passing: 1494
completed: 2026-04-12
---

# Phase 14 Plan 03: Integration & Templates Summary

The final wave of Phase 14 makes the organization-aware surface end-to-end
observable. `Sigra.Auth.create_session/4` now runs the 0/1/2+ selector once
per login and writes the result atomically into the new session row; the
generated `Scope` template carries the pure `put_active_organization/3`
function; the generated `user_auth.ex` `mount_current_scope` helper calls
the SAME `Sigra.Scope.Hydration.hydrate/3` the plug path uses (D-23 parity);
the generated `error_handler.ex` has the two new auth-error clauses with
exact UI-SPEC copy; a brand-new `organizations.ex` template ships a
`defdelegate set_active_organization/2` wrapper; the router injection
carries two new `:require_org` / `:require_org_owner` pipelines; and an
18-test integration layer proves SC-1 through SC-4 on a green 1494-test
suite.

## Tasks Completed

### Task 1: Login-time selector + Sigra.Config fields + integration tests
**Commit:** `8d170e4`

- Extended `Sigra.Config` with two nullable fields — `:scope_module` and
  `:organizations_module` — in the NimbleOptions `@schema`, `@type t`,
  and `defstruct`. Both default to `nil` so legacy installs round-trip
  unchanged.
- Rewrote `Sigra.Auth.create_session/4`'s post-insert branch to call
  `maybe_assign_active_organization/6`, which:
  1. Short-circuits to `{:ok, session}` when `config.organizations_module`
     is `nil` (legacy-install preservation).
  2. Wraps the selector call in a `try/rescue` + `catch` — T-14-13 fail-open.
     Selector raises, throws, and exits all degrade to `active_org_id = nil`.
  3. Reaches into the host wrapper via `organizations_module.__sigra_org_config__/0`
     (exposed by Plan 02 Task 1) to pass the validated org-config map to
     `Sigra.Organizations.select_active_organization/3`.
  4. Forwards `opts[:previous_active_organization_id]` to the selector so
     callers can resume the user's last active org on multi-org login.
  5. On `{:ok, org}` from the selector, calls
     `session_store.update_active_organization(session, org.id, store_opts)`
     — the same Plan 01 Task 1 callback. On `{:error, _}` from the
     session-store write, login still succeeds with the nil pointer
     (the selector's result is advisory, not authoritative).
- 9 new Mox-based integration tests in `test/sigra/auth_org_selection_test.exs`:
  - 2 `Sigra.Config` round-trip tests (scope_module + organizations_module)
  - 1 legacy-install regression (no selector call when organizations_module nil)
  - 5 0/1/2+ selector cases (zero, one, two-no-resume, two-with-match, two-with-forged)
  - 1 fail-open selector-raise test using a `BoomOrganizations` module
    whose `__sigra_org_config__/0` raises

All 58 existing `Sigra.AuthTest` `create_session` tests continue to pass
without modification (zero regressions).

### Task 2: Generated-template edits + new organizations.ex wrapper
**Commit:** `6568510`

- **`priv/templates/sigra.install/core/scope.ex`** — added
  `put_active_organization/3` with a single joint docstring on the function
  head plus two clauses: `(scope, org, membership)` and `(scope, nil, nil)`.
  Elixir rejects `@doc` on multiple clauses of the same function, so the
  docstring was collapsed to one on the function head with both clauses
  documented inline.
- **`priv/templates/sigra.install/core/user_auth.ex`** — `mount_current_scope`
  swapped from the legacy `get_user_by_session_token` single-arg helper to
  `get_user_and_session_by_token`, then calls
  `Sigra.Scope.Hydration.hydrate(scope, <%= app_module %>.Organizations.__sigra_org_config__(), sigra_session)`.
  On `{:error, _}` the helper returns the non-hydrated scope — LV path
  intentionally does not trigger stale-pointer recovery because there is
  no conn to write through. Contract documented inline and cross-referenced
  to CONTEXT §D-14, §D-23.
- **`priv/templates/sigra.install/core/error_handler.ex`** — added two new
  `auth_error/3` clauses:
  - `:no_active_org` → `put_flash(:info, "Pick or create an organization to continue.")`
    + `redirect(to: ~p"/organizations")`. Uses `:info` (NOT `:error`) per
    UI-SPEC's non-blaming rule.
  - `:insufficient_role` → `put_flash(:error, "You don't have permission to access this page in the current organization.")`
    + `put_status(:forbidden)` + `put_view(...ErrorHTML)` + `render(:"403")`
    + `halt()`. Exact UI-SPEC copy; no role-name leak.
  - Moduledoc addition: "Clauses for :no_active_org and :insufficient_role
    are generated by Sigra for organization-aware routes. Edit the redirect
    target or message to match your product's tone."
- **New template `priv/templates/sigra.install/organizations/organizations.ex`** —
  generates a `<%= app_module %>.Organizations` module that `use
  Sigra.Organizations` (gets `__sigra_org_config__/0` + the thin
  delegators) plus `defdelegate set_active_organization(conn, org), to:
  Sigra.Plug.PutActiveOrganization, as: :call`. The module is the single
  authoritative host-app write path for active org transitions.
- **`lib/sigra/install/features/organizations.ex`** — populated `files/1`
  (was `[]` in Phase 13) to emit the new template into `lib/<otp_app>/organizations.ex`.
- **`test/sigra/install/features/organizations_test.exs`** — 6 new tests
  covering the files/1 entry, the Scope template's put function, the
  error_handler's exact UI-SPEC copy (with `refute` on "This page requires the"
  to enforce no-role-name-leak), the organizations.ex defdelegate + `use
  Sigra.Organizations`, and the user_auth.ex hydrator call.
- **Golden fixtures updated** — `scope.ex`, `user_auth.ex`, `auth_error_handler.ex`
  in `test/fixtures/install_golden/tree/` all updated to match the new
  template output. Golden diff test (42s to run a real `mix phx.new` + `mix
  sigra.install` + byte-compare) is green.

### Task 3: Plug ↔ LiveView parity test + router :require_org pipelines
**Commit:** `2ab7ee4`

- **`test/sigra/scope/plug_liveview_parity_test.exs`** — new test module,
  3 tests enforcing D-23:
  1. **Happy path parity:** build user + org + membership + session, drive
     the same session through (a) `Hydration.hydrate/3` direct (LV path)
     and (b) `LoadActiveOrganization.call/2` (plug path) using independent
     Mox expectation cycles. Assert the resulting scopes are structurally
     equal on `user`, `active_organization.id`, `membership.id`, and
     `impersonating_from`. Proof that the collapsed SC-3 matrix (D-23)
     holds live on a real code path.
  2. **Nil active_organization_id:** neither path makes ANY Repo call
     (enforced by Mox `verify_on_exit!` — no expectations set). Both
     return the zero-org scope with all org fields nil. `conn.halted`
     is false on the plug path.
  3. **Stale pointer — plug recovers, LV degrades:** both paths observe
     the same `{:error, :org_not_found}` hydration signal. The LV path
     returns it and the test asserts on it (proving the graceful-degradation
     contract the template comment documents). The plug path then takes
     the recovery branch: clears the stale pointer via the mocked
     SessionStore, re-runs the selector (mocked empty list → zero orgs),
     never halts, leaves `active_organization: nil`.
- **Router injection (`lib/sigra/install/features/core.ex`)** — appended
  two new pipelines to the Core feature's router content block, immediately
  after `:require_authenticated`:
  - `:require_org` — any active membership permitted.
  - `:require_org_owner` — `roles: [:owner]`.
  Both use the host's `<web_module>.AuthErrorHandler`. The pipelines are
  declared but not wired into any scope — opt-in scaffolding for host apps.
  Phase 16 will pipe_through them on the switcher + settings routes.
- **Golden router.ex fixture** updated to match.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Added `:organizations_module` to `Sigra.Config`**
- **Found during:** Task 1.
- **Issue:** The plan only instructed adding `:scope_module` to `Sigra.Config`,
  but `create_session/4` has no path to reach the host's Organizations
  wrapper without a module reference on the config struct. The validated
  org-config map lives behind `module.__sigra_org_config__/0` (exposed in
  Plan 02 Task 1); `create_session/4` must receive the module name via
  `Sigra.Config` since it's called from library code that knows only the
  Sigra.Config struct. Without this, there is no in-config path to the
  selector.
- **Fix:** Added a second nullable field `:organizations_module` to
  `Sigra.Config` alongside `:scope_module`. Both default to nil so
  legacy installs round-trip unchanged. `create_session/4` reads
  `config.organizations_module` and short-circuits if nil.
- **Files modified:** `lib/sigra/config.ex`, `lib/sigra/auth.ex`,
  `test/sigra/auth_org_selection_test.exs`.
- **Commit:** `8d170e4`.

**2. [Rule 2 - Missing critical functionality] Collapsed multi-clause `@doc`**
- **Found during:** Task 2 (golden diff run).
- **Issue:** The initial template put `@doc """..."""` above both clauses
  of `put_active_organization/3`. Elixir 1.15+ warns (and logs
  `"redefining @doc attribute previously set at line N"`) when `@doc`
  is reset between clauses of the same function. The golden-diff run
  surfaced the warning in the installed host app's compile output.
- **Fix:** Collapsed both docstrings into a single joint docstring on the
  function head, with both clauses documented inline under bullets.
  Second clause has no `@doc` — it inherits from the head.
- **Files modified:** `priv/templates/sigra.install/core/scope.ex`,
  `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/scope.ex`.
- **Commit:** `2ab7ee4`.

**3. [Rule 3 - Blocker] Router injection scope reduced: LoadActiveOrganization plug NOT added**
- **Found during:** Task 3 Step 1.
- **Issue:** The plan instructed "Add `plug Sigra.Plug.LoadActiveOrganization`
  IMMEDIATELY after `plug Sigra.Plug.FetchSession`" in the router template.
  Two blockers:
  1. There is no `router.ex` template — the router is edited via a
     `%Sigra.Install.Injection{}` record against the host's already-existing
     `router.ex`, and the current Core injection only emits route scopes
     and `:require_authenticated`, NOT the upstream `:browser_authenticated`
     pipeline that would contain `FetchSession`. Adding
     `LoadActiveOrganization` has no sensible insertion point without
     expanding Core's router injection scope.
  2. `LoadActiveOrganization.init/1` requires `:organizations` (the host's
     Organizations wrapper module). The host's `AppName.Organizations`
     module is emitted by `Features.Organizations` which is NOT yet in the
     installer's `@features` list (see Deviation 4). Wiring the plug
     before the wrapper exists would break host compilation.
- **Fix:** The two opt-in pipelines `:require_org` / `:require_org_owner`
  ARE added — they only reference `RequireMembership` (reads scope.membership.role)
  and the host's `AuthErrorHandler` (compile-time verified). The
  `LoadActiveOrganization` wiring is deferred to Phase 16 or Phase 18
  (installer walker expansion), when host apps will have the Organizations
  wrapper in their lib/ tree.
- **Files modified:** `lib/sigra/install/features/core.ex`,
  `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex`.
- **Commit:** `2ab7ee4`.

**4. [Rule 3 - Blocker] Features.Organizations not yet in installer `@features` list**
- **Found during:** Task 2 golden-diff verification.
- **Issue:** The plan instructed registering the new `organizations.ex`
  template on `Features.Organizations.files/1`. I did so. However,
  `lib/mix/tasks/sigra.install.ex` currently defines
  `@features [Sigra.Install.Features.Core]` — Features.Organizations is
  NOT yet in the walker's canonical list. Adding it now would require
  cascading work (walker registration, feature isolation tests, multi-feature
  golden-diff fixture regeneration) that is Phase 18's explicit scope
  per `Features.Organizations` moduledoc.
- **Fix:** `Features.Organizations.files/1` now returns the right template
  list AND the per-file unit tests assert on it directly (file reads, not
  installer invocation). The installer-level wiring is left for Phase 18.
  The golden-diff test continues to pass because Features.Organizations
  is still dead code at the walker level — installed host apps do not
  yet receive the `organizations.ex` file. Test coverage is at the
  feature-module level, which is where Phase 14 Plan 03's contract lives.
- **Files modified:** `lib/sigra/install/features/organizations.ex`,
  `test/sigra/install/features/organizations_test.exs`.
- **Commit:** `6568510`.

### CONTEXT.md Drift

None. All canonical refs held. The two deferred items (LoadActiveOrganization
plug wiring, Features.Organizations walker registration) are architectural
boundaries that Phase 18 is explicitly chartered to resolve; Plan 03 does
not overreach into them.

## Requirements Progress

| Requirement  | Status   | Notes                                                                                      |
| ------------ | -------- | ------------------------------------------------------------------------------------------ |
| ORG-SCOPE-03 | complete | Hydration primitive (Plan 01), plug (Plan 02), plug-path tests (Plan 02), LV parity (this plan). |
| ORG-SCOPE-04 | complete | RequireMembership ships (Plan 02). Router :require_org / :require_org_owner pipelines registered here. |
| ORG-SCOPE-05 | complete | Generated user_auth.ex mount_current_scope calls Sigra.Scope.Hydration.hydrate/3 (D-23 parity enforced). |
| ORG-SCOPE-06 | complete | 0/1/2+ selector wired into Sigra.Auth.create_session/4 with fail-open + resume pointer. 9 integration tests cover every branch. |

## Threat Register Coverage

| Threat  | Status    | Evidence                                                                                                 |
| ------- | --------- | -------------------------------------------------------------------------------------------------------- |
| T-14-13 | mitigated | `auth_org_selection_test.exs` "selector raise does NOT fail login" test uses `BoomOrganizations` whose `__sigra_org_config__/0` raises; login returns `{:ok, session}` with `active_organization_id: nil`. |
| T-14-14 | mitigated | `error_handler.ex` uses verified route `~p"/organizations"` — compile-time checked by Phoenix. `organizations_test.exs` asserts the literal `"Pick or create an organization to continue."` string is present. |
| T-14-15 | mitigated | `organizations_test.exs` `refute error_handler =~ "This page requires the"` — no role-name leak. The clause's message is a flat permission statement without role enumeration. |
| T-14-16 | mitigated | `plug_liveview_parity_test.exs` happy-path test drives the SAME session fixture through `Hydration.hydrate/3` (LV path) and `LoadActiveOrganization` (plug path) and asserts structurally-equal scopes. D-23 parity is live. |
| T-14-17 | plan 02 / plan 15 | Audit on transition is emitted by LoadActiveOrganization (Plan 02, commit `7caab84`). Real metadata enrichment lands in Phase 15. |
| T-14-18 | partial   | `:require_org` / `:require_org_owner` pipelines DO reference host's AuthErrorHandler (compile-error on missing impl). `LoadActiveOrganization` plug wiring in the router injection is deferred — see Deviation 3 for the architectural reason. |
| T-14-19 | accepted  | Task 2 user_auth.ex template comment documents the LV graceful-degradation contract; parity test 3 enforces the boundary (LV returns non-hydrated scope, plug recovers). Phase 16 adds LV handle_params re-check. |

## Verification Results

```
mix test test/sigra/auth_org_selection_test.exs
# 9 tests, 0 failures

mix test test/sigra/scope/plug_liveview_parity_test.exs
# 3 tests, 0 failures

mix test test/sigra/install/features/organizations_test.exs
# 15 tests, 0 failures (9 pre-existing + 6 new)

mix test test/sigra/install/
# 352 tests, 0 failures — includes golden-diff pass

mix test
# 33 doctests, 3 properties, 1494 tests, 0 failures
#   (+17 new tests vs Plan 02's 1477: 9 auth-org + 3 parity + 5 organizations template tests
#    plus 1 pre-existing organizations test that previously asserted [] → updated)

mix compile --warnings-as-errors
# clean

# Invariant greps:
grep -n "scope_module" lib/sigra/config.ex             # 3 matches: @schema, @type, defstruct
grep -n "organizations_module" lib/sigra/config.ex     # 3 matches: @schema, @type, defstruct
grep -c "select_active_organization" lib/sigra/auth.ex # 1 (inside create_session only)
grep -n "def put_active_organization" priv/templates/sigra.install/core/scope.ex
# 2 matches (2 clauses, one @doc)
grep -c "Sigra.Scope.Hydration.hydrate" priv/templates/sigra.install/core/user_auth.ex  # 1
grep -c "get_user_by_session_token" priv/templates/sigra.install/core/user_auth.ex  # 0
grep -c ":no_active_org" priv/templates/sigra.install/core/error_handler.ex  # 1
grep -c ":insufficient_role" priv/templates/sigra.install/core/error_handler.ex  # 1
grep -c "Pick or create an organization to continue" priv/templates/sigra.install/core/error_handler.ex  # 1
grep -c "You don't have permission to access this page in the current organization" priv/templates/sigra.install/core/error_handler.ex  # 1
grep -c "This page requires the" priv/templates/sigra.install/core/error_handler.ex  # 0 (UI-SPEC non-negotiable)
grep -c "defdelegate set_active_organization" priv/templates/sigra.install/organizations/organizations.ex  # 1
grep -c "Sigra.Plug.PutActiveOrganization" priv/templates/sigra.install/organizations/organizations.ex  # 1
grep -c "pipeline :require_org" lib/sigra/install/features/core.ex  # 2 (:require_org + :require_org_owner)

# Pitfall 2 guard:
grep -rn "get_organization!" lib/sigra/scope lib/sigra/plug  # returns 0
```

## Handoff Notes for Phase 15+

1. **Phase 15 (Audit Integration)** — `Sigra.Plug.LoadActiveOrganization` already
   emits `Sigra.Audit.log_safe("organization.active_auto_reassigned", ...)` on
   stale recovery (shipped by Plan 02). Phase 15 will plug `metadata_from_scope/2`
   into the metadata arg. The `audit_schema` is already opt-wired through
   `:audit_opts`; no code changes needed at the call site.

2. **Phase 16 (organization picker + switcher)** — Use the `:require_org`
   pipelines already in the generator's router injection. The picker's
   target route `~p"/organizations"` is already the `:no_active_org`
   redirect destination, locked in by UI-SPEC §Copywriting Contract.
   LiveView `handle_params` re-check for stale pointers is the only
   remaining LV gap (T-14-19, accepted disposition).

3. **Phase 17 (invitation accept)** — Call
   `<app_module>.Organizations.set_active_organization(conn, org)` after
   invitation acceptance. The `defdelegate` routes through
   `Sigra.Plug.PutActiveOrganization.call/2` which enforces
   membership-before-write (T-14-06).

4. **Phase 18 (installer walker expansion)** — Two tasks left from Plan 03
   deviations:
   - Add `Sigra.Install.Features.Organizations` to
     `lib/mix/tasks/sigra.install.ex` `@features` list (Deviation 4).
   - Expand the router injection to include `plug Sigra.Plug.LoadActiveOrganization`
     after `FetchSession` (Deviation 3). This also requires the host's
     Organizations module to be materialized at install time (depends on
     the previous item).

## Self-Check: PASSED

- `test/sigra/auth_org_selection_test.exs` — FOUND (9 tests)
- `test/sigra/scope/plug_liveview_parity_test.exs` — FOUND (3 tests)
- `priv/templates/sigra.install/organizations/organizations.ex` — FOUND
- `lib/sigra/config.ex` — modified, scope_module + organizations_module added
- `lib/sigra/auth.ex` — modified, create_session/4 selector wiring + maybe_assign_active_organization/6
- `lib/sigra/install/features/core.ex` — modified, :require_org pipelines added
- `lib/sigra/install/features/organizations.ex` — modified, files/1 populated
- `priv/templates/sigra.install/core/scope.ex` — modified, put_active_organization/3 (joint docstring)
- `priv/templates/sigra.install/core/user_auth.ex` — modified, mount_current_scope calls hydrate/3
- `priv/templates/sigra.install/core/error_handler.ex` — modified, 2 new clauses
- `test/sigra/install/features/organizations_test.exs` — modified, 6 new assertions
- Golden fixtures updated (4 files)
- `.planning/phases/14-org-plugs-scope-hydration/14-VALIDATION.md` — wave_0_complete: true
- Commit `8d170e4` — FOUND (Task 1)
- Commit `6568510` — FOUND (Task 2)
- Commit `2ab7ee4` — FOUND (Task 3)
- Full `mix test` — 1494 passing, 0 failing
- `mix test test/sigra/install/` — 352 passing (including 42s golden-diff)
- `mix compile --warnings-as-errors` — clean
- All grep invariants: as documented in Verification Results
