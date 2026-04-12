---
phase: 14
plan: 2
subsystem: organizations + scope
tags: [organizations, scope, plug, fetch-plug, require-plug, library]
requires:
  - Phase 14 Plan 01 (Sigra.Scope.Hydration.hydrate/3, select_active_organization/3,
    fetch_organization/2, SessionStore.update_active_organization/3,
    ErrorHandler :no_active_org + :insufficient_role types)
  - Phase 13 (Sigra.Organizations context, get_membership/3, list_organizations_for_user/2)
  - Phase 12 (Sigra.Session + SessionStore behaviour)
provides:
  - Sigra.Plug.LoadActiveOrganization (Fetch plug — never halts, stale recovery inline)
  - Sigra.Plug.RequireMembership (Require plug — halts via error_handler on missing org or role mismatch)
  - Sigra.Plug.PutActiveOrganization (single authoritative write site for active org)
  - Sigra.Organizations wrapper accessor `__sigra_org_config__/0` (exposed so plugs reach config)
affects:
  - Phase 14 Plan 03 (generator templates + UserAuth.on_mount consuming these plugs)
  - Phase 16 (organization switcher controller → PutActiveOrganization)
  - Phase 17 (invitation accept → PutActiveOrganization)
tech-stack:
  added: []
  patterns:
    - Fetch vs Require split — LoadActiveOrganization hydrates + stale-recovers without
      halting; RequireMembership is the sole halt point, mirroring Sigra.Plug.RequireScopes.
    - Single authoritative write path (PutActiveOrganization) — every future caller
      (login, switcher, invitation accept, stale recovery) funnels through this one
      function, which enforces membership-before-write (T-14-06) and never touches
      the Plug session cookie or rotates the session token.
    - Dependency injection via explicit plug opts (`:organizations`, `:session_store`,
      `:scope_module`) matching `Sigra.Plug.FetchSession`'s existing `:config` model —
      no implicit conn.private accessors, no global Application env reads.
    - Host Organizations wrapper exposes a single `__sigra_org_config__/0` accessor
      so plugs + future on_mount callbacks can reach `select_active_organization/3`
      and `Hydration.hydrate/3` without duplicating config plumbing.
key-files:
  created:
    - lib/sigra/plug/load_active_organization.ex
    - lib/sigra/plug/require_membership.ex
    - lib/sigra/plug/put_active_organization.ex
    - test/sigra/plug/load_active_organization_test.exs
    - test/sigra/plug/require_membership_test.exs
    - test/sigra/plug/put_active_organization_test.exs
  modified:
    - lib/sigra/organizations.ex (exposed `__sigra_org_config__/0` accessor on the
      generated wrapper via the `__using__` macro)
decisions:
  - D-03 (no Plug session cookie mirror) — enforced by grep invariant across all 3 plugs
  - D-04 (Fetch plug never halts) — LoadActiveOrganization.call/2 returns conn on every path
  - D-05 (Require plug structural mimic) — RequireMembership twins RequireScopes.init/call shapes
  - D-06 (set-membership semantics) — admin does NOT imply owner; regression test T-14-11
  - D-07 (empty :roles means "any active membership OK") — default + explicit test
  - D-14 (fail-closed stale recovery with previous: nil) — LoadActiveOrganization passes
    `previous_active_organization_id: nil` to select_active_organization/3
  - D-16 (single write path) — PutActiveOrganization is the only caller of
    SessionStore.update_active_organization/3 that new Phase 14+ code will invoke directly
  - D-17 (no Plug-session write) — tests grep for `put_session` and assert `get_session/2` nil
  - D-18 (scope transition != trust transition) — no configure_session/renew_session calls
  - D-21 (RequireMembership reads scope.membership.role, zero DB queries) — tests prove
    by using BombErrorHandler to catch any re-query path
  - D-22 (all plugs live in the library) — three files under `lib/sigra/plug/`
  - CD-01 (PutActiveOrganization filepath) — settled on `lib/sigra/plug/put_active_organization.ex`
    alongside `fetch_session.ex`, mirroring library layout
metrics:
  duration: ~35 minutes
  tasks: 3
  commits: 3
  files_changed: 7
  tests_added: 27
  tests_total_passing: 1477
completed: 2026-04-12
---

# Phase 14 Plan 02: Library Plugs Summary

Three request-time plugs wire Plan 01's pure primitives into a Fetch/Require/Orchestrator
triad that Phase 14 Plan 03, Phase 16's switcher, and Phase 17's invitation flow will all
consume. The Fetch plug (`LoadActiveOrganization`) hydrates scope without halting and
handles stale-pointer recovery inline with an audit event. The Require plug
(`RequireMembership`) is a structural twin of `Sigra.Plug.RequireScopes` and the sole
halt point. The orchestrator (`PutActiveOrganization`) is the single authoritative
write site — every future caller funnels through this one function.

## Tasks Completed

### Task 1: Sigra.Plug.LoadActiveOrganization (Fetch — never halts)
**Commit:** `7caab84`

- Created `lib/sigra/plug/load_active_organization.ex`:
  - `init/1` validates `:organizations` and `:session_store` are present.
  - `call/2` is guaranteed-never-halt. Four branches: nil scope → pass-through,
    nil session → pass-through, nil pointer → hydrator pass-through,
    valid pointer → `Sigra.Scope.Hydration.hydrate/3`.
  - On `{:error, :not_a_member | :org_not_found}` enters `recover_from_stale_pointer/5`:
    clears the session column via `SessionStore.update_active_organization(session, nil, opts)`,
    re-runs `Organizations.select_active_organization/3` with `previous_active_organization_id: nil`
    (D-14 — the stale pointer must NOT be resumed), writes the selected org back via a
    second SessionStore call (or leaves nil on `:zero_orgs`/`:multiple`), and emits
    exactly one `Sigra.Audit.log_safe/2` event:
    `"organization.active_auto_reassigned"` with `%{from: stale_id, to: new_id_or_nil}`
    in metadata. No-op when `:audit_schema` is absent (by Audit design).
- **Exposed `__sigra_org_config__/0`** on the `use Sigra.Organizations` wrapper. Plan 01
  did not expose this and the plug literally could not reach the org config without it
  (Rule 3 blocker fix — see Deviations).
- **10 Mox-based unit tests** in `test/sigra/plug/load_active_organization_test.exs`:
  - 3 pass-through cases: nil scope, nil session, nil pointer
  - 1 happy-path hydration
  - 4 stale-recovery variants: reassign to remaining, zero remaining,
    multiple remaining (picker path), and `:org_not_found` recovery
  - 2 invariant tests: never-halts on every path, no `put_session` call

### Task 2: Sigra.Plug.RequireMembership (Require — halts via error_handler)
**Commit:** `903c556`

- Created `lib/sigra/plug/require_membership.ex`, structural twin of
  `Sigra.Plug.RequireScopes`:
  - `init/1` requires `:error_handler`, defaults `:roles` to `[]` (D-07 "any membership"),
    validates that `:roles` is a list of atoms and is a subset of `@role_universe`
    (`[:owner, :admin, :member]`), raising `ArgumentError` with a descriptive
    message on typos. Multiple raise branches: non-list, non-atom elements, unknown atoms.
  - `call/2` has three branches mirroring RequireScopes' cond shape: missing org →
    `error_handler.auth_error(conn, :no_active_org, opts)` + halt; role outside the
    required set → `error_handler.auth_error(conn, :insufficient_role, opts_with_required_roles)`
    + halt; otherwise pass-through.
- **Zero DB re-queries (D-21).** `call/2` reads `scope.membership.role` directly from
  assigns. The "no DB re-query" test uses a `BombErrorHandler` that raises if invoked —
  the test passes the plug a scope with `role: :owner` and asserts the plug honors
  that value (a phantom DB query would halt on a stale/different role).
- **Set-membership semantics (D-06, T-14-11).** The regression test explicitly asserts
  that `admin` does NOT imply `owner` when `:roles: [:owner]`.
- **12 unit tests**: 5 init cases (missing handler, default [], valid subset, unknown
  atoms, non-atom elements), 2 missing-org cases (nil scope, nil active_organization),
  4 role-filtering cases (empty :roles passes, matching role passes, mismatched role
  halts, admin-does-not-imply-owner halts), 1 no-DB-re-query invariant.

### Task 3: Sigra.Plug.PutActiveOrganization (single write path)
**Commit:** `58723e3`

- Created `lib/sigra/plug/put_active_organization.ex`. **NOT** a `Plug.call/2` — it is
  a function-call contract with signature `call(conn, org_or_nil, opts) :: {:ok, conn} | {:error, reason}`:
  - Two clauses: one for `nil` (clear active org), one for `%_{} = org` (set/change).
  - **The set clause verifies membership BEFORE writing** (T-14-06 authz choke point):
    `Organizations.get_membership/3` is called first; on `nil` the function returns
    `{:error, :not_a_member}` without ever calling `SessionStore.update_active_organization/3`.
    The "no-write on `:not_a_member`" invariant is enforced by Mox `verify_on_exit!` —
    the test does NOT set a `MockSessionStore` expectation, so any call would fail.
  - Writes three things on success: (1) DB column via `session_store.update_active_organization/3`,
    (2) `conn.private[:sigra_session]` via `Plug.Conn.put_private/3`, (3)
    `conn.assigns[:current_scope]` via the host `scope_module.put_active_organization/3` (D-15).
  - **Writes nothing else.** Grep invariants enforced: `put_session = 0`,
    `configure_session = 0`, `renew_session = 0`, `Repo. = 0` (everything goes through
    SessionStore and Organizations).
- **Scope module resolved via opts (`:scope_module`)**, not hardcoded to `Sigra.Scope`.
  The test uses a test-local `TestScope.put_active_organization/3` that records calls in
  the process dictionary; the test asserts exactly one recorded call after a successful
  set/clear, proving the orchestrator resolved the module via opts.
- **5 unit tests**: happy-path set + scope_module resolution (2), not_a_member no-write (1),
  clear path (1), D-17/D-18 no-cookie-write invariant (1).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Added `__sigra_org_config__/0` accessor on the generated wrapper**
- **Found during:** Task 1.
- **Issue:** Plan 01 shipped `Sigra.Organizations.select_active_organization/3` and
  `Sigra.Organizations.fetch_organization/2` as module-function primitives that take a
  `config` map. But the `use Sigra.Organizations` macro did NOT expose the validated
  `@sigra_org_config` via any public accessor — it was only used internally by the
  thin delegators. LoadActiveOrganization needs the config to call `Hydration.hydrate/3`
  AND `select_active_organization/3` directly; without an accessor, the plug literally
  could not reach it.
- **Fix:** Added a public `__sigra_org_config__/0` function to the `__using__` block
  of `Sigra.Organizations`. Documented as the Phase 14 plug/on_mount entry point.
  Plan 14-03's `on_mount` callback will use the same accessor.
- **Files modified:** `lib/sigra/organizations.ex` (the `__using__` macro).
- **Commit:** `7caab84` (bundled with Task 1).

**2. [Rule 3 - Blocker] PutActiveOrganization signature is `call/3`, not `call/2`**
- **Found during:** Task 3.
- **Issue:** The plan's `<interfaces>` block sketched `@spec call(Plug.Conn.t(), struct() | nil)`
  — a 2-arg function — and the example code used private helpers `config!(conn)` and
  `scope_module!(conn)` that called a nonexistent `Sigra.Plug.FetchSession.config(conn)`.
  `Sigra.Plug.FetchSession` does not expose a `config/1` accessor and stores nothing on
  `conn.private` beyond `:sigra_session`. There is literally no in-conn path to recover
  `:organizations`, `:session_store`, or `:scope_module`.
- **Fix:** Signature is `call(Plug.Conn.t(), struct() | nil, keyword()) :: {:ok, conn} | {:error, reason}`.
  Opts must include `:organizations`, `:session_store`, `:scope_module`; optional
  `:session_store_opts`. This mirrors every other Sigra plug's explicit-config model
  (FetchSession, RequireScopes, etc.) and mirrors Plan 01's `update_active_organization/3`
  opts-arg deviation (Plan 01 Deviation 1).
- **Files modified:** `lib/sigra/plug/put_active_organization.ex` + tests.
- **Commit:** `58723e3`.

**3. [Rule 2 - Missing critical functionality] `:session_store` + `:session_store_opts`
   + `:audit_opts` on LoadActiveOrganization**
- **Found during:** Task 1.
- **Issue:** The plan's `<interfaces>` sketch for LoadActiveOrganization listed only
  `init(opts), do: opts` and suggested reading config via a nonexistent
  `Sigra.Plug.FetchSession.config(conn)`. The plug needs the session store module,
  the store's `opts` (repo + session_schema), and — for the audit call — the audit
  schema. All three must be injected via plug init opts (same shape as FetchSession's
  existing pattern) since there is no in-conn accessor.
- **Fix:** Added `:session_store` (required), `:session_store_opts` (optional, default
  `[]`), and `:audit_opts` (optional, default `[]`) to the plug init contract. Documented
  in moduledoc. `Audit.log_safe/2` is no-op-safe when `:audit_schema` is absent, so
  default-empty `:audit_opts` means hosts without an audit table get zero audit writes
  (by Audit design — same semantic Plan 03 will exploit for login auditing).
- **Commit:** `7caab84` (Task 1).

### CONTEXT.md Drift

None encountered. All Phase 14 decisions cited in the plan (D-03/04/05/06/07/14/15/16/17/18/21/22
and CD-01) were implemented as specified modulo the signature blockers above. The
"shared hydrator contract" promise from D-01/D-23 is preserved: all three plugs consume
Plan 01's primitives through exactly the interfaces Plan 01 shipped. Plan 14-03 will
be able to call the same `Sigra.Scope.Hydration.hydrate/3` and `__sigra_org_config__/0`
accessor from `on_mount`.

## Requirements Progress

| Requirement | Status | Notes |
|-------------|--------|-------|
| ORG-SCOPE-03 | plug path complete | Fetch plug (`LoadActiveOrganization`) ships; pairs with Plan 01's pure hydrator. LiveView path (`on_mount`) is Plan 03. |
| ORG-SCOPE-04 | complete | `RequireMembership` ships with init-time role validation, set-membership semantics, and zero-DB-query invariant. |

## Threat Register Coverage

| Threat  | Status    | Evidence                                                                                                                   |
|---------|-----------|-----------------------------------------------------------------------------------------------------------------------------|
| T-14-06 | mitigated | PutActiveOrganization test "returns {:error, :not_a_member} when user has no membership — NO DB write": Mox `verify_on_exit!` fails if SessionStore is called on the reject path. |
| T-14-07 | mitigated | LoadActiveOrganization test "revoked membership triggers reset + selector re-run" — revoked membership → column cleared + reassigned + audit event, no halt, no 500. |
| T-14-08 | accepted  | Documented on RequireMembership moduledoc (D-21): scope tampering is inside BEAM trust boundary; mitigated by LoadActiveOrganization's upstream membership read from the Phase 13 tenant-scoped context. |
| T-14-09 | plan 03   | Redirect target lives in the generated `error_handler.ex` which Plan 03 emits. RequireMembership never composes redirect URLs. |
| T-14-10 | accepted  | Stale recovery performs 2 SessionStore writes + 1 selector call per affected request. Upstream Hammer config already throttles pathological traffic. |
| T-14-11 | mitigated | RequireMembership test "admin does NOT imply owner — hierarchical role confusion is rejected": `[:admin]` scope against `roles: [:owner]` halts with `:insufficient_role`. |
| T-14-12 | mitigated | Grep-based test invariants on all 3 plugs: `put_session = 0`, `configure_session = 0`, `renew_session = 0`. `get_session(conn, :active_organization_id)` asserted nil before/after in LoadActiveOrganization and PutActiveOrganization tests. |

## Verification Results

```
mix test test/sigra/plug/load_active_organization_test.exs
# 10 tests, 0 failures

mix test test/sigra/plug/require_membership_test.exs
# 12 tests, 0 failures

mix test test/sigra/plug/put_active_organization_test.exs
# 5 tests, 0 failures

mix test
# 33 doctests, 3 properties, 1477 tests, 0 failures  (+27 new tests vs Plan 01's 1450)

mix compile --warnings-as-errors
# clean (auto-removed the one default-arg warning surfaced during TDD green phase)

mix credo --strict lib/sigra/plug/load_active_organization.ex \
                   lib/sigra/plug/require_membership.ex \
                   lib/sigra/plug/put_active_organization.ex \
                   lib/sigra/organizations.ex
# found no issues (62 mods/funs across the 4 files)

# Invariant greps (all MUST be 0):
grep -c "Plug.Conn.halt"          lib/sigra/plug/load_active_organization.ex  # 0
grep -c "put_session"             lib/sigra/plug/load_active_organization.ex  # 0
grep -c "Plug.Conn.put_session"   lib/sigra/plug/put_active_organization.ex   # 0
grep -c "configure_session"       lib/sigra/plug/put_active_organization.ex   # 0
grep -c "renew_session"           lib/sigra/plug/put_active_organization.ex   # 0
grep -c "Repo\."                  lib/sigra/plug/put_active_organization.ex   # 0
grep -c "Repo\."                  lib/sigra/plug/require_membership.ex        # 0
grep -c "Organizations.get_membership" lib/sigra/plug/require_membership.ex   # 0

# Exact call sites:
grep -c "Sigra.Scope.Hydration.hydrate"  lib/sigra/plug/load_active_organization.ex  # 1 call + 1 alias
grep -c "error_handler.auth_error("      lib/sigra/plug/require_membership.ex        # 2
grep -c "Plug.Conn.halt"                 lib/sigra/plug/require_membership.ex        # 2
```

## Handoff Notes for Plan 03

Plan 03 (`14-03-integration-and-templates`) will:

1. **Wire the plug stack in the generated `UserAuth` / router pipeline.** The expected
   plug ordering (see `fetch_session.ex` + this plan's moduledocs):

   ```elixir
   plug Sigra.Plug.FetchSession, config: @sigra_config, scope_module: MyApp.Accounts.Scope
   plug Sigra.Plug.LoadActiveOrganization,
     organizations: MyApp.Organizations,
     session_store: Sigra.SessionStores.Ecto,
     session_store_opts: [repo: MyApp.Repo, session_schema: MyApp.Accounts.UserSession],
     audit_opts: [audit_schema: MyApp.AuditEvent, repo: MyApp.Repo]
   plug Sigra.Plug.RequireAuthenticated, error_handler: MyAppWeb.AuthErrorHandler
   plug Sigra.Plug.RequireMembership,
     error_handler: MyAppWeb.AuthErrorHandler,
     roles: [:owner, :admin]  # or omit for "any membership"
   ```

2. **Wire the login entry point to call `PutActiveOrganization.call/3`.** Login handlers
   (both HTTP + magic link) should, on successful session creation:
   - Call `Organizations.select_active_organization(config, user, previous_active_organization_id: nil)`.
   - On `{:ok, org}`, invoke `Sigra.Plug.PutActiveOrganization.call(conn, org, opts)` with
     the same `:organizations`/`:session_store`/`:scope_module` opts the plug pipeline uses.
   - On `{:none, :zero_orgs}` or `{:multiple, _}`, skip the call — the user either has no
     active org or will see the picker via RequireMembership on the next protected route.

3. **Generated `UserAuth.on_mount` must call `Sigra.Scope.Hydration.hydrate/3`** directly
   (D-23 parity matrix collapse), using `MyApp.Organizations.__sigra_org_config__()` as
   the config arg. On `{:error, :not_a_member | :org_not_found}`, the on_mount callback
   should halt the mount via `{:halt, redirect_to_picker}` or equivalent — NOT attempt
   the auto-reassignment flow, since the plug already handled that on the HTTP hit that
   preceded the LiveView mount. (Confirm this with Plan 03's planner — it may wish to
   duplicate the reassignment for robustness.)

4. **Add a `Sigra.Plug.PutActiveOrganization` usage example to the generated scope.ex
   template.** The host Scope module must implement `put_active_organization/3` — D-15.
   Signature: `put_active_organization(%Scope{} = scope, org_or_nil, membership_or_nil)`.
   Both clauses are exercised by this plan's tests (`TestScope` in
   `put_active_organization_test.exs`).

5. **Parity test between plug + on_mount paths.** D-23 promised a single collapsed
   SC-3 matrix via shared `hydrate/3`. Plan 03 should add an integration test that
   drives the same session + same config through both the plug pipeline and a fake
   on_mount conn/socket, asserting equal scopes out.

**Nothing Plan 03 needs from the library layer is missing.** The `__sigra_org_config__/0`
accessor, the three plugs, and the Plan 01 primitives they consume are all shipped and
green. The remaining work is template edits + login wiring + the parity test.

## Self-Check: PASSED

- `lib/sigra/plug/load_active_organization.ex` — FOUND
- `lib/sigra/plug/require_membership.ex` — FOUND
- `lib/sigra/plug/put_active_organization.ex` — FOUND
- `test/sigra/plug/load_active_organization_test.exs` — FOUND
- `test/sigra/plug/require_membership_test.exs` — FOUND
- `test/sigra/plug/put_active_organization_test.exs` — FOUND
- `lib/sigra/organizations.ex` — modified, `__sigra_org_config__/0` accessor present
- Commit `7caab84` — FOUND (Task 1: LoadActiveOrganization + org config accessor)
- Commit `903c556` — FOUND (Task 2: RequireMembership)
- Commit `58723e3` — FOUND (Task 3: PutActiveOrganization)
- Full `mix test` — 1477 passing, 0 failing (+27 new tests this plan)
- `mix credo --strict` on all 4 touched files — no issues
- `mix compile --warnings-as-errors` — clean
- All grep invariants: 0 as documented in Verification Results
