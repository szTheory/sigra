---
phase: 14
plan: 1
subsystem: organizations + scope
tags: [organizations, scope, session-store, error-handler, library]
requires:
  - Phase 12 (Sigra.Session + SessionStore behaviour + active_organization_id column)
  - Phase 13 (Sigra.Organizations context, list_organizations_for_user/2, get_membership/3)
provides:
  - Sigra.Scope.Hydration.hydrate/3 (pure hydrator shared by plug + on_mount)
  - Sigra.Organizations.select_active_organization/3 (pure selector)
  - Sigra.Organizations.fetch_organization/2 (non-raising fetcher — fail-closed)
  - Sigra.SessionStore.update_active_organization/3 (behaviour callback + ecto impl)
  - Sigra.Plug.ErrorHandler @type error_type extended with :no_active_org + :insufficient_role
affects:
  - Phase 14 Plan 02 (LoadActiveOrganization / RequireMembership / PutActiveOrganization plugs)
  - Phase 14 Plan 03 (generator template edits + UserAuth.on_mount)
tech-stack:
  added: []
  patterns:
    - Pure selector returning triadic {:ok | :none | :multiple, ...} — collapses
      zero/one/multiple semantics into a single function the orchestrator branches on.
    - Fail-closed scope hydrator that NEVER raises — uses non-raising
      fetch_organization/2 instead of the bang variant (PITFALLS O-6).
    - No-op short-circuit on SessionStore writes when the new value equals the
      current value (D-20 optimization) — avoids an UPDATE on every authed hit.
key-files:
  created:
    - lib/sigra/scope/hydration.ex
    - test/sigra/scope/hydration_test.exs
  modified:
    - lib/sigra/session_store.ex
    - lib/sigra/session_stores/ecto.ex
    - lib/sigra/organizations.ex
    - lib/sigra/plug/error_handler.ex
    - test/sigra/session_stores/ecto_test.exs
    - test/sigra/organizations/context_test.exs
    - test/sigra/session_test.exs
decisions:
  - D-01 (shared hydrator contract) — implemented as Sigra.Scope.Hydration.hydrate/3
  - D-08 (partial) — behaviour surface extended with :no_active_org + :insufficient_role
  - D-11 (selector returning zero/one/multiple) — implemented as select_active_organization/3
  - D-14 (fail-closed on stale pointer) — surfaced via {:not_a_member, :org_not_found}
  - D-20 (SessionStore behaviour extension with no-op short-circuit) — implemented
  - D-22 (all new modules live in the library) — hydrator is under lib/sigra/scope/
  - D-23 (hydrator unit test collapses SC-3 parity matrix) — 7 unit tests cover the contract
  - CD-03 (filepath choice) — settled on lib/sigra/scope/hydration.ex (top-level Sigra.Scope namespace)
  - CD-04 (sort strategy for {:multiple, orgs}) — descending by inserted_at for stable UI ordering
metrics:
  duration: ~25 minutes
  tasks: 3
  commits: 3
  files_changed: 9
  tests_added: 22
  tests_total_passing: 1450
completed: 2026-04-12
---

# Phase 14 Plan 01: Pure Primitives Summary

Pure, side-effect-free foundations for Phase 14's org plugs and scope hydration —
`Sigra.Scope.Hydration.hydrate/3`, `Sigra.Organizations.select_active_organization/3`,
the `SessionStore.update_active_organization/3` behaviour callback + ecto impl, and
the additive `:no_active_org`/`:insufficient_role` extension to
`Sigra.Plug.ErrorHandler`'s `@type error_type` — all covered by 22 new Mox-based
unit tests that collapse the SC-3 plug-vs-on_mount parity matrix (D-23) into a
single hydrator contract.

## Tasks Completed

### Task 1: SessionStore.update_active_organization/3 callback + ecto impl
**Commit:** `b0a62d9`

- Extended `Sigra.SessionStore` behaviour with an 8th callback:
  `update_active_organization(session, org_id, opts) :: {:ok, Session.t()} | {:error, term()}`.
- Implemented in `Sigra.SessionStores.Ecto` with:
  - A guarded head `when current == org_id` that returns `{:ok, session}` unchanged
    (no-op-safe short-circuit per D-20 — no DB write when the value is already set).
  - A real `Repo.update_all/2` head that returns `{:error, :not_found}` on `{0, _}`
    and `{:ok, %{session | active_organization_id: org_id}}` on success.
- 5 new Mox unit tests in `test/sigra/session_stores/ecto_test.exs`:
  1. writes the column for a valid session + org_id
  2. clears the column when passed `nil`
  3. no-op when `org_id` equals the current value (MockRepo expects no call — verified via `verify_on_exit!`)
  4. no-op also covers the nil → nil case
  5. returns `{:error, :not_found}` when the row is gone

**Deviation from PLAN signature:** The plan listed `update_active_organization/2`, but every
existing SessionStore callback takes `opts` as its last argument so the ecto impl can
fetch `:repo`/`:session_schema`. Rule 3 blocker: the impl literally cannot work
without `opts`. I added `opts :: keyword()` as arg 3 — matches every sibling callback.

### Task 2: select_active_organization/3 + fetch_organization/2 + ErrorHandler types
**Commit:** `876a2af`

- Added `Sigra.Organizations.select_active_organization/3` — pure selector
  returning `{:ok, org}` / `{:none, :zero_orgs}` / `{:multiple, [org]}`. Sorts the
  `{:multiple, ...}` list by `inserted_at` descending (CD-04) and matches
  `:previous_active_organization_id` against the user's own membership list so a
  forged resume pointer cannot inject an org the user is not a member of
  (threat T-14-03 regression test).
- Added `Sigra.Organizations.fetch_organization/2` — non-raising sibling to
  `get_organization!/2`. Soft-deleted rows (`deleted_at != nil`) are treated as
  `{:error, :not_found}`. Required by the hydrator so `Ecto.NoResultsError` cannot
  escape into the request pipeline (PITFALLS O-6).
- Extended `Sigra.Plug.ErrorHandler` `@type error_type` additively with `:no_active_org`
  and `:insufficient_role`. Updated the `@moduledoc` error-types list to document
  the new atoms (plus the four pre-existing extensions from earlier phases that
  hadn't been documented there yet).
- 10 new Mox unit tests in `test/sigra/organizations/context_test.exs`:
  - `select_active_organization/3`: zero orgs, one org, resume pointer matches,
    resume pointer is forged/non-matching, no resume pointer, sort order (CD-04),
    silent ignore of unknown opts.
  - `fetch_organization/2`: happy path, not found, does-not-raise.

### Task 3: Sigra.Scope.Hydration.hydrate/3 pure hydrator
**Commit:** `7cdbcb1`

- Created `lib/sigra/scope/hydration.ex` with two clauses:
  - `hydrate(scope, _config, %Session{active_organization_id: nil})` → `{:ok, scope}` unchanged.
  - `hydrate(scope, config, %Session{active_organization_id: org_id})` → calls
    `Organizations.fetch_organization/2` then `Organizations.get_membership/3`,
    returning `{:ok, %{scope | active_organization: org, membership: membership}}`,
    `{:error, :not_a_member}`, or `{:error, :org_not_found}`.
- **Zero `Repo.` calls** in the module body — all DB work goes through the
  `Organizations` context. Dialyzer + credo clean.
- **Never raises** — verified by an explicit `assert_no_raise/1` test covering both
  error paths.
- 7 new Mox unit tests in `test/sigra/scope/hydration_test.exs`:
  1. nil pointer returns scope unchanged (zero repo calls)
  2. valid session + live membership returns populated scope
  3. revoked membership returns `{:error, :not_a_member}`
  4. deleted org returns `{:error, :org_not_found}`
  5. never raises on any error path
  6. purity — two calls yield `==` equal scopes
  7. nil org_id path makes zero Repo calls

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] SessionStore.update_active_organization/3 signature**
- **Found during:** Task 1.
- **Issue:** The plan's listed signature was 2-arg `(session, org_id)`, but every
  existing SessionStore callback takes `opts :: keyword()` as its final argument
  so the ecto impl can fetch `:repo` and `:session_schema`. The 2-arg signature
  is un-implementable without reaching for compile-time config or Application env,
  both of which are listed under "What NOT to Use" in CLAUDE.md.
- **Fix:** Added `opts :: keyword()` as arg 3. Matches every sibling callback.
  `lib/sigra/session_store.ex` + `lib/sigra/session_stores/ecto.ex` both use the
  3-arg form; tests reflect this.
- **Files modified:** `lib/sigra/session_store.ex`, `lib/sigra/session_stores/ecto.ex`, `test/sigra/session_stores/ecto_test.exs`
- **Commit:** `b0a62d9`

**2. [Rule 3 - Blocker] SessionStore meta-test hard-coded callback count**
- **Found during:** Task 3 verification (full `mix test` run).
- **Issue:** `test/sigra/session_test.exs` had `assert length(callbacks) == 7` which
  broke once Task 1 added an 8th callback.
- **Fix:** Bumped the assertion to `== 8` and added an `assert {:update_active_organization, 3} in callbacks` line.
- **Files modified:** `test/sigra/session_test.exs`
- **Commit:** `7cdbcb1` (bundled with Task 3 commit — the failure was surfaced during Task 3's full-suite run)

**3. [Rule 2 - Missing critical functionality] Added `fetch_organization/2`**
- **Found during:** Task 3.
- **Issue:** The plan's action block for Task 3 instructed the executor to verify
  whether a non-raising fetcher exists in `Sigra.Organizations` and to add one if
  not. It did not exist — only `get_organization!/2`. Without the non-raising
  fetcher, the hydrator would propagate `Ecto.NoResultsError` into request pipelines,
  violating the fail-closed contract (PITFALLS O-6, threat T-14-02).
- **Fix:** Added `fetch_organization/2` to `Sigra.Organizations` returning
  `{:ok, org} | {:error, :not_found}`, filtering soft-deleted rows at the query
  level to match the existing `get_organization!/2` semantics.
- **Files modified:** `lib/sigra/organizations.ex`, `test/sigra/organizations/context_test.exs`
- **Commit:** `876a2af`

### CONTEXT.md Drift

None discovered. All canonical refs held — the only departure from the plan's
suggested prose was the signature extension documented under Deviation 1, and it
is a pure conformance to existing SessionStore callback conventions.

## Requirements Progress

| Requirement | Status                           | Notes                                                                      |
| ----------- | -------------------------------- | -------------------------------------------------------------------------- |
| ORG-SCOPE-03 | primitive complete (plug pending) | `Sigra.Scope.Hydration.hydrate/3` contract + tests live; plug is Plan 02. |
| ORG-SCOPE-06 | primitive complete              | `select_active_organization/3` with full 0/1/2+ + resume-pointer semantics. |

## Threat Register Coverage

| Threat  | Status    | Evidence                                                                                                 |
| ------- | --------- | -------------------------------------------------------------------------------------------------------- |
| T-14-01 | mitigated | `hydration_test.exs` "revoked membership returns `{:error, :not_a_member}`" test — fail-closed surface. |
| T-14-02 | mitigated | `hydration_test.exs` "never raises" + "deleted org returns `{:error, :org_not_found}`" tests. `fetch_organization/2` is non-raising. |
| T-14-03 | mitigated | `context_test.exs` "forged resume pointer" test — only the user's actual org list is returned.          |
| T-14-04 | accepted  | Documented on the `@callback update_active_organization/3` docstring — caller-responsibility for authz. |
| T-14-05 | plan 02   | Audit on transition is Plan 02's job; Plan 01 surfaces the signals the orchestrator will audit.         |

## Verification Results

```
mix test test/sigra/scope/hydration_test.exs test/sigra/organizations/context_test.exs test/sigra/session_stores/ecto_test.exs
# 50 tests, 0 failures

mix test
# 33 doctests, 3 properties, 1450 tests, 0 failures

mix compile --warnings-as-errors
# clean

mix credo --strict lib/sigra/scope/hydration.ex lib/sigra/session_store.ex lib/sigra/session_stores/ecto.ex lib/sigra/plug/error_handler.ex lib/sigra/organizations.ex
# 69 mods/funs, found no issues

grep -c "Repo\." lib/sigra/scope/hydration.ex          # 0 — hydrator has no direct Repo calls
grep -c "get_organization!" lib/sigra/scope/hydration.ex # 1, in docstring only (acceptance criterion intent met)
git diff mix.exs                                        # empty — zero new deps
```

## Handoff Notes for Plan 02

Plan 02 (`14-02-library-plugs`) will orchestrate the primitives shipped here into
three plugs. The contracts to bind against are:

1. **`Sigra.Plug.LoadActiveOrganization`** — calls `Sigra.Scope.Hydration.hydrate/3`
   after `fetch_current_scope`. On `{:error, :not_a_member}` or `{:error, :org_not_found}`:
   1. Call `SessionStore.update_active_organization(session, nil, opts)` to clear
      the stale pointer (no-op-safe short-circuit will handle this cheaply if
      already cleared).
   2. Call `Organizations.select_active_organization(config, user, previous_active_organization_id: nil)`
      — pass `nil` explicitly so the stale pointer is NOT resumed (D-14).
   3. On `{:ok, org}` from the selector, call `Sigra.Plug.put_active_organization/2`
      (or its equivalent per CD-01 — decide in Plan 02) to write the new pointer
      and re-run `hydrate/3`.
   4. Emit `Sigra.Audit.log_safe("organization.active_auto_reassigned", ...)` on
      the transition (T-14-05 mitigation, D-14).
2. **`Sigra.Plug.PutActiveOrganization`** (or `Sigra.Plug.put_active_organization/2`
   as a standalone function) — verifies membership via `Organizations.get_membership/3`
   BEFORE invoking `SessionStore.update_active_organization/3`. This is the
   authz choke point referenced by T-14-04's `accept` disposition on the
   SessionStore callback itself.
3. **`Sigra.Plug.RequireMembership`** — calls the host app's `ErrorHandler.auth_error/3`
   with `:no_active_org` when `scope.active_organization == nil` and with
   `:insufficient_role` when the role is not in the required list. The typespec
   is already extended (Task 2).

**Nothing else Plan 02 needs is missing.** Every primitive, type, and test fixture
is in place. The on_mount side (Plan 03) uses the exact same `hydrate/3` call —
that is literally the collapse of the SC-3 parity matrix promised by D-23.

## Self-Check: PASSED

- `lib/sigra/scope/hydration.ex` — FOUND
- `test/sigra/scope/hydration_test.exs` — FOUND
- `lib/sigra/session_store.ex` — modified, `update_active_organization` callback present
- `lib/sigra/session_stores/ecto.ex` — modified, 2-clause impl present
- `lib/sigra/organizations.ex` — modified, `select_active_organization` + `fetch_organization` present
- `lib/sigra/plug/error_handler.ex` — modified, `:no_active_org` + `:insufficient_role` present
- `test/sigra/session_stores/ecto_test.exs` — modified, 5 new tests
- `test/sigra/organizations/context_test.exs` — modified, 10 new tests
- `test/sigra/session_test.exs` — modified, callback count bumped to 8
- Commit `b0a62d9` — FOUND (Task 1)
- Commit `876a2af` — FOUND (Task 2)
- Commit `7cdbcb1` — FOUND (Task 3)
- Full `mix test` — 1450 passing, 0 failing
- `mix credo --strict` on touched files — no issues
- `mix compile --warnings-as-errors` — clean
