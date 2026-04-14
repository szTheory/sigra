---
phase: 17-invitation-flow-email
plan: 01
subsystem: auth, organizations, test-scaffolding
tags: [sigra, auth, organizations, ecto-multi, test-scaffolding]
requires: []
provides:
  - "Sigra.Auth.register_user_multi/2 pure Ecto.Multi builder"
  - "Sigra.Organizations.add_member_multi/5 pure Ecto.Multi builder"
  - "Sigra.InvitationsFixtures test fixture module"
  - "Sigra.OrganizationsFixtures test fixture module"
  - "Swoosh.Adapters.Test mailer configured for Sigra library test env"
affects:
  - lib/sigra/auth.ex
  - lib/sigra/organizations.ex
  - test/sigra/auth_test.exs
  - test/sigra/organizations/context_test.exs
  - test/support/mock_repo_behaviour.ex
  - test/support/fixtures/invitations_fixtures.ex
  - test/support/fixtures/organizations_fixtures.ex
  - config/test.exs
tech-stack:
  added: []
  patterns:
    - "Pure Ecto.Multi builder + thin wrapper that runs via repo.transact/1"
    - "{:changes_key, atom} user-ref shape for cross-Multi composition"
key-files:
  created:
    - test/support/fixtures/invitations_fixtures.ex
    - test/support/fixtures/organizations_fixtures.ex
  modified:
    - lib/sigra/auth.ex
    - lib/sigra/organizations.ex
    - test/sigra/auth_test.exs
    - test/sigra/organizations/context_test.exs
    - test/support/mock_repo_behaviour.ex
    - config/test.exs
decisions:
  - "Use Ecto 3.13 repo.transact/1 (not deprecated transaction/1) in register/3 and add_member/5 only; other functions stay on transaction/1 for now"
  - "add_member_multi accepts both %User{} struct and {:changes_key, atom} tuple for user_ref; resolved at runtime via Multi.run(:add_member_resolve_user)"
  - "When user_ref is {:changes_key, _}, audit metadata omits user_id (not resolvable at build time); membership row still carries user_id"
  - "Fixtures parameterized on schema_module+repo / config map so they are reusable from both lib suite (Mox) and host-app suites (real Repo)"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-14"
  tasks: 3
  commits: 5
  tests_added: 12
  tests_total: 1627
---

# Phase 17 Plan 01: Wave 0 — Pure Multi Builders + Fixture Scaffolding Summary

**One-liner:** Extracted pure `Ecto.Multi` builders from `Sigra.Auth.register/3` and `Sigra.Organizations.add_member/5` and landed Phase 17 shared test scaffolding (invitation + organization fixtures + Swoosh test mailer config).

## Function signatures shipped

```elixir
# lib/sigra/auth.ex
@spec register_user_multi(map(), keyword()) :: Ecto.Multi.t()
def register_user_multi(attrs, opts)

# lib/sigra/organizations.ex
@spec add_member_multi(map(), map(), struct(), struct() | {:changes_key, atom()}, atom()) ::
        Ecto.Multi.t()
def add_member_multi(config, scope, org, user_ref, role)
```

Wrappers `Sigra.Auth.register/3` and `Sigra.Organizations.add_member/5` now internally compose their multi builder and run it via `repo.transact/1`. Error tuple shape from `transact/1` on a failing `:user` step is `{:error, :user, %Ecto.Changeset{}, changes_so_far}`.

## Composition example (unlocked for plans 17-05 through 17-07)

```elixir
register_multi =
  Sigra.Auth.register_user_multi(attrs, changeset_fn: &User.registration_changeset/1)

member_multi =
  Sigra.Organizations.add_member_multi(
    config,
    scope,
    org,
    {:changes_key, :user},
    :member
  )

register_multi
|> Ecto.Multi.append(member_multi)
|> config.repo.transact()
```

This is exactly the composition `Sigra.Organizations.Invitations.accept_with_signup/3` will use in Plan 17-05 (D-07 atomicity).

## Fixture helper signatures

```elixir
# test/support/fixtures/invitations_fixtures.ex (Sigra.InvitationsFixtures)
invitation_attrs(opts \\ [])                            # keyword list, no insert
pending_invite(schema_module, repo, opts \\ [])         # inserted row
accepted_invite(schema_module, repo, opts \\ [])        # inserted row, accepted_at set
revoked_invite(schema_module, repo, opts \\ [])         # inserted row, revoked_at set
expired_invite(schema_module, repo, opts \\ [])         # inserted row, expires_at in past

# test/support/fixtures/organizations_fixtures.ex (Sigra.OrganizationsFixtures)
org_with_owner_and_admin(config, opts \\ [])            # => %{org: _, owner: _, admin: _}
user_fixture(config, attrs \\ %{})                      # stamps confirmed_at
organization_fixture(config, attrs \\ %{})              # bare org row
```

Required opts for `invitation_attrs/1` / `pending_invite/3`: `:organization_id`, `:invited_by_id`.

Required `config` keys for the organization fixtures: `:repo`, `:schemas.organization`, `:schemas.user`.

## Swoosh test mailer

Module name for downstream plans to reference: **`Sigra.Mailer`**. Configured in `config/test.exs`:

```elixir
config :sigra, Sigra.Mailer, adapter: Swoosh.Adapters.Test
```

The example test app already has `Example.Mailer` configured with `Swoosh.Adapters.Test` at `test/example/config/test.exs:25`; that stanza was left unchanged.

## Deviations from Plan

**1. [Rule 3 - Blocking] Extended `Sigra.MockRepo.Behaviour` with `transact/1` callback**

- **Found during:** Task 1 RED phase
- **Issue:** The library's auth_test.exs uses Mox-stubbed `Sigra.MockRepo` which implemented `transaction/1` but not `transact/1`. Refactoring `register/3` to use `repo.transact/1` would otherwise fail at `UndefinedFunctionError` when tests stub the new path.
- **Fix:** Added `@callback transact(Ecto.Multi.t()) :: ...` to `Sigra.MockRepo.Behaviour`. Existing `transaction/1` callback left in place so the rest of Organizations (which still uses `transaction/1`) stays compatible.
- **Files modified:** `test/support/mock_repo_behaviour.ex`
- **Commit:** `0406126`

**2. [Rule 3 - Blocking] Fixtures created as NEW files rather than extensions**

- **Found during:** Task 3
- **Issue:** Plan language said to "extend" `test/support/fixtures/organizations_fixtures.ex` and assumed `accounts_fixtures.ex` existed in the library test support tree. Neither file exists in `test/support/fixtures/` — only `email_fixtures.ex`. (Existing org/user fixtures live in `test/example/test/support/fixtures/` — a separate test app tree.)
- **Fix:** Created `Sigra.OrganizationsFixtures` as a NEW module under `test/support/fixtures/`, parameterized on the caller's `config` map. Included `user_fixture/2` and `organization_fixture/2` alongside `org_with_owner_and_admin/2` so the module is self-contained. No existing file was "extended."
- **Files modified:** `test/support/fixtures/organizations_fixtures.ex` (new)
- **Commit:** `1a48319`

**3. [Rule 3 - Blocking] Add `add_member_multi/5` tests added to `context_test.exs`, not a new `organizations_test.exs`**

- **Found during:** Task 2
- **Issue:** Plan referenced `test/sigra/organizations_test.exs` which does not exist. The library's Organizations tests are split by topic into `test/sigra/organizations/*.exs`.
- **Fix:** Added `describe "add_member/5"` and `describe "add_member_multi/5"` blocks to `test/sigra/organizations/context_test.exs` (the closest existing home — it already defines the Mox TestOrg/TestMembership/TestUser inline schemas and `@test_config`). Also added coverage for the refactored `add_member/5` wrapper stubbing `:transact`.
- **Files modified:** `test/sigra/organizations/context_test.exs`
- **Commit:** `f43413b`

**4. [Rule 2 - Critical] Audit metadata handled per user_ref shape**

- **Found during:** Task 2 design
- **Issue:** The old `add_member/5` stamped audit metadata `user_id: user.id` at build time. With `{:changes_key, :user}`, the user isn't resolvable until runtime.
- **Fix:** Added private helper `add_member_audit_metadata/2` that stamps `user_id` only when `user_ref` is a concrete struct. When it's `{:changes_key, _}`, metadata is just `%{role: to_string(role)}`; the inserted membership row itself still carries `user_id` for downstream queries.
- **Commit:** `b68b62d`

**5. Worktree base rebase**

- **Found during:** Pre-execution worktree branch check
- **Issue:** This worktree (`worktree-agent-adc085ba`) was based on commit `4efb4a5` (Phase 11), not on the expected base `2ac309c` (Phase 17 plans). Phases 12–17 did not exist on disk in the worktree.
- **Fix:** Hard-reset the branch to `2ac309c1a669166ce97b1918208d48681b0243ef` before beginning execution. All plan artifacts and library source for phases 12–16 were materialized by the reset. No library code was modified as part of the rebase itself.

## Auth Gates

None — fully autonomous, no external verification needed.

## Commits (in order)

| Commit    | Type    | Summary                                                           |
| --------- | ------- | ----------------------------------------------------------------- |
| `0406126` | test    | RED — failing tests for `register_user_multi/1` + MockRepo `transact` callback |
| `5c0057d` | feat    | GREEN — implement `register_user_multi/2`, refactor `register/3` to use `transact/1` |
| `f43413b` | test    | RED — failing tests for `add_member_multi/5` + refactored `add_member/5` |
| `b68b62d` | feat    | GREEN — implement `add_member_multi/5`, refactor `add_member/5` to use `transact/1` |
| `1a48319` | test    | Create `InvitationsFixtures` + `OrganizationsFixtures` + Swoosh test mailer config |

## Verification Results

```
mix compile --warnings-as-errors           → clean (test env)
mix test test/sigra/auth_test.exs          → 63/63 passing
mix test test/sigra/organizations/context_test.exs → 50/50 passing
mix test                                    → 33 doctests, 3 properties, 1627 tests, 0 failures
mix credo --strict lib/sigra/auth.ex lib/sigra/organizations.ex
   → no new issues introduced by this plan (all remaining warnings
     are pre-existing complexity/nesting flags in other functions)
```

## Known Stubs

None. The builders are the real implementation — they will be consumed directly by `Sigra.Organizations.Invitations.accept_with_signup/3` in Plan 17-05.

## Self-Check: PASSED

**Created files:**

- FOUND: test/support/fixtures/invitations_fixtures.ex
- FOUND: test/support/fixtures/organizations_fixtures.ex

**Modified files verified via grep:**

- FOUND: `def register_user_multi` in lib/sigra/auth.ex
- FOUND: `def add_member_multi` in lib/sigra/organizations.ex
- FOUND: `repo.transact` in lib/sigra/auth.ex (4 occurrences, one in register/3)
- FOUND: `config.repo.transact` in lib/sigra/organizations.ex add_member/5
- FOUND: `register_user_multi` in test/sigra/auth_test.exs (7 references)
- FOUND: `add_member_multi` in test/sigra/organizations/context_test.exs (6 references)
- FOUND: `{:changes_key, :user}` in test/sigra/organizations/context_test.exs
- FOUND: `Swoosh.Adapters.Test` in config/test.exs

**Commits:**

- FOUND: 0406126 (test RED — register_user_multi)
- FOUND: 5c0057d (feat GREEN — register_user_multi)
- FOUND: f43413b (test RED — add_member_multi)
- FOUND: b68b62d (feat GREEN — add_member_multi)
- FOUND: 1a48319 (test — fixtures + Swoosh config)
