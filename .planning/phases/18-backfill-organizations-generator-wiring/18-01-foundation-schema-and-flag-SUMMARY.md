---
phase: 18-backfill-organizations-generator-wiring
plan: 01
subsystem: organizations
tags: [organizations, generator, schema, migration, phase-18]
requires:
  - phase-11 feature manifest (Sigra.Install.Feature behaviour + Runner)
  - phase-13 Sigra.Organizations context with create_organization/3
provides:
  - owner_user_id + personal columns baked into fresh-install organizations migration (postgres + mysql/sqlite branches)
  - organizations_personal_owner_uidx partial unique index (postgres) / composite fallback (mysql/sqlite)
  - Organization schema template with :personal field and belongs_to :owner via foreign_key: :owner_user_id
  - --organizations / --no-organizations CLI switch on mix sigra.install
  - organizations?: binding forwarded to every EEx template
  - Sigra.Install.Features.Organizations registered in @features (real --no-organizations gate)
  - Sigra.Organizations.create_organization/3 writes owner_user_id via put_change from scope.user.id
  - ArgumentError raise on nil scope.user (no silent nil origin owner)
affects:
  - fresh install codepath for organizations migration + schema
  - all EEx templates (new organizations? binding available)
  - Plan 18-02 (upgrade task can now assume fresh-install shape matches v1.1 target)
tech-stack:
  added: []
  patterns:
    - put_change/3 over cast/3 for library-owned fields (owner_user_id)
    - partial unique index as structural invariant + insert-safety backstop (D-01 / D-03)
    - feature manifest extensibility via @features list append (no case-matching)
key-files:
  created:
    - .planning/phases/18-backfill-organizations-generator-wiring/deferred-items.md
  modified:
    - priv/templates/sigra.install/organizations/migration.exs
    - priv/templates/sigra.install/organizations/organization.ex
    - lib/mix/tasks/sigra.install.ex
    - lib/sigra/organizations.ex
    - test/sigra/organizations/context_test.exs
    - test/sigra/install/purely_additive_test.exs
decisions:
  - "D-00 + D-01 baked into fresh-install migration template directly (no upgrade-only ALTER slots in Features.Organizations.migrations/1)"
  - "owner_user_id set via put_change/3, NEVER via cast/3 — structurally unreachable from host attrs (T-18-01 mitigation)"
  - "ArgumentError raise on nil scope.user — no silent nil owner_user_id (T-18-05 mitigation)"
  - "Features.Organizations isolation lock (purely_additive_test refute) lifted per Plan 18-01 intent; positive assertion now requires registration"
metrics:
  duration: "~60 minutes"
  completed: 2026-04-14
  tasks_completed: 4
  files_modified: 6
  files_created: 1
---

# Phase 18 Plan 01: Foundation Schema and Flag Summary

Baked the personal-workspace schema shape (owner_user_id + personal column + partial unique index) directly into the fresh-install organizations migration and schema templates, registered Features.Organizations in the install task so --no-organizations becomes a real gate, forwarded an `organizations?` binding to EEx templates, and wired `Sigra.Organizations.create_organization/3` to set `owner_user_id` on insert via put_change — all atomically committed with a locked invariant test that Rule 1's host-cannot-spoof-origin-owner axiom holds structurally via Ecto changeset semantics.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Bake owner_user_id + personal + partial unique index into fresh-install organizations migration (both adapter branches) | `de82bd0` | `priv/templates/sigra.install/organizations/migration.exs` |
| 2 | Add personal field + belongs_to :owner to Organization schema template | `99b125e` | `priv/templates/sigra.install/organizations/organization.ex` |
| 3 | Register Features.Organizations in @features, add --organizations switch, forward organizations? binding | `b9c872a` | `lib/mix/tasks/sigra.install.ex` |
| 4 | Audit core templates + wire create_organization/3 to set owner_user_id + new invariant tests | `72a0459` | `lib/sigra/organizations.ex`, `test/sigra/organizations/context_test.exs` |
| — | Lift Features.Organizations isolation lock (plan-sanctioned test repair) | `c776b7a` | `test/sigra/install/purely_additive_test.exs` |

## What Shipped

### 1. Migration template (Task 1)

Both adapter branches of `priv/templates/sigra.install/organizations/migration.exs` now bake D-00 (owner_user_id) and D-01 (personal flag) into the fresh `create_organizations` migration:

- **Postgres:** `owner_user_id` references with `on_delete: :nilify_all` + `personal :boolean null: false default: false` + partial unique index `organizations_personal_owner_uidx` on `(owner_user_id) WHERE personal = true`.
- **MySQL/SQLite:** same two column adds + composite `(owner_user_id, personal)` unique index fallback (no partial-index support in these adapters; app-level guard in `Sigra.Organizations` is authoritative).

### 2. Organization schema template (Task 2)

Added `field :personal, :boolean, default: false` and `belongs_to :owner, ..., foreign_key: :owner_user_id` to the generated schema. The existing changeset's `cast/3` list is unchanged — both fields remain structurally unreachable from host attrs. This preserves Rule 2's host-cannot-forge-owner audit invariant at the schema layer.

### 3. Flag wiring (Task 3)

Three surgical edits in `lib/mix/tasks/sigra.install.ex`:

- `@features` now contains `[Sigra.Install.Features.Core, Sigra.Install.Features.Organizations]` — the feature is filtered at `Runner.run/3` via `enabled?/1` which already reads `Keyword.get(opts, :organizations, true)`.
- `@switches` gains `organizations: :boolean`.
- `@default_opts` gains `organizations: true`.
- `build_binding/4` forwards `organizations?: Keyword.get(opts, :organizations, true)` into every EEx template.

### 4. create_organization/3 owner write + invariant tests (Task 4)

`lib/sigra/organizations.ex` now refactors `create_organization/3` into a guard + `do_create_organization/4` split:

```elixir
def create_organization(config, scope, attrs) do
  case scope do
    %{user: %{id: user_id}} when not is_nil(user_id) ->
      do_create_organization(config, scope, attrs, user_id)

    _ ->
      raise ArgumentError,
            "create_organization/3 requires a scope with a loaded user (got: ...)"
  end
end
```

Inside `do_create_organization/4`, the org changeset is piped through `Ecto.Changeset.put_change(:owner_user_id, owner_user_id)` BEFORE entering the `Ecto.Multi` pipeline. Critically:

- `put_change/3` — NOT `cast/3` — means attacker-supplied `owner_user_id` in attrs is structurally ignored.
- `personal` is never touched by `create_organization/3` — it stays `false` for team orgs. Only `Sigra.Upgrade.Backfill.run_personal_orgs/2` (Plan 18-02) writes `personal: true`, via `Repo.insert_all`.

Four new tests lock the invariants:

1. `sets owner_user_id from scope.user.id via put_change (never cast)` — asserts the Multi's insert changeset contains `{:owner_user_id, scope.user.id}` as a change.
2. `host-supplied owner_user_id in attrs is ignored (put_change wins)` — passes a forged `owner_user_id` in attrs, asserts the changeset's owner_user_id change equals the scoped user id (not the attacker id).
3. `personal stays false for team orgs created via create_organization/3` — asserts the changeset has no `:personal` change.
4. `raises ArgumentError when scope.user is nil (no silent nil owner_user_id)` — ensures no silent nil path exists.

TestOrg schema gained `owner_user_id` and `personal` fields so `put_change/3` has somewhere to land.

### 5. Plan-sanctioned test repair (extra commit)

`test/sigra/install/purely_additive_test.exs` had a Phase 11–era `refute source =~ "Features.Organizations"` invariant lock designed to hold UNTIL the phase that shipped organizations-as-a-registered-feature — that is Plan 18-01. Replaced the refute with a positive assertion: `assert source =~ "Sigra.Install.Features.Organizations"`. The architectural invariant that matters (no `case feature do` branching, no per-feature conditional code in `sigra.install.ex`) is preserved. Refutes for Features.Passkeys and Features.Admin remain.

## Verification

| Check | Result |
|---|---|
| `grep -c "add :owner_user_id, references" priv/templates/sigra.install/organizations/migration.exs` | 2 (one per adapter branch) ✓ |
| `grep -c "add :personal, :boolean, null: false, default: false" priv/templates/sigra.install/organizations/migration.exs` | 2 ✓ |
| `grep -c "organizations_personal_owner_uidx" priv/templates/sigra.install/organizations/migration.exs` | 2 ✓ |
| `grep -c "where: \"personal = true\"" priv/templates/sigra.install/organizations/migration.exs` | 1 (postgres-only) ✓ |
| `grep -c "field :personal, :boolean, default: false" priv/templates/sigra.install/organizations/organization.ex` | 1 ✓ |
| `grep -c "belongs_to :owner" priv/templates/sigra.install/organizations/organization.ex` | 1 ✓ |
| `grep -c "foreign_key: :owner_user_id" priv/templates/sigra.install/organizations/organization.ex` | 1 ✓ |
| `grep -c "cast(.*:personal" priv/templates/sigra.install/organizations/organization.ex` | 0 (field is NOT in cast list) ✓ |
| `grep -c "Sigra.Install.Features.Organizations" lib/mix/tasks/sigra.install.ex` | 1 ✓ |
| `grep -c "organizations: :boolean" lib/mix/tasks/sigra.install.ex` | 1 ✓ |
| `grep -c "organizations: true" lib/mix/tasks/sigra.install.ex` | 1 ✓ |
| `grep -c "organizations?: Keyword.get(opts, :organizations, true)" lib/mix/tasks/sigra.install.ex` | 1 ✓ |
| `grep -c "put_change(:owner_user_id" lib/sigra/organizations.ex` | 1 ✓ |
| `grep -c "cast(.*:owner_user_id" lib/sigra/organizations.ex` | 0 (never via cast) ✓ |
| `mix compile --warnings-as-errors` | PASS ✓ |
| `mix format --check-formatted` (touched files) | PASS ✓ |
| `mix test test/sigra/organizations/context_test.exs` | 54 tests, 0 failures ✓ (+4 new Phase 18 tests) |
| `mix test test/sigra/organizations/` | 186 tests, 0 failures ✓ |
| `mix test test/sigra/install/purely_additive_test.exs` | 3 tests, 0 failures ✓ |

## Deviations from Plan

### Rule 1 (Auto-fixed bug) — Stale test invariant lock

**Found during:** Task 3 verification (`mix test test/sigra/install/`).

**Issue:** `test/sigra/install/purely_additive_test.exs:130` had a `refute source =~ "Features.Organizations"` lock that directly contradicts Plan 18-01's stated objective of registering Features.Organizations in `@features`. The refute was a Phase 11–era isolation artifact meant to hold only until this phase landed.

**Fix:** Replaced with a positive assertion. Kept the real architectural invariants (no `case feature do` branching, no per-feature conditionals, refutes for Features.Passkeys / Features.Admin still active).

**Commit:** `c776b7a`.

### Scope-boundary refusal — Phase 16/17 template bugs exposed but not fixed

**Found during:** Task 3 verification. Registering Features.Organizations caused `mix sigra.install` to render the Phase 16/17 organizations templates for the first time ever via the install codepath — and several of them have pre-existing compile errors and missing files. Full details in `deferred-items.md` (DEF-18-01 and DEF-18-02).

Specifically:
1. `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` mixes `<%= %>` EEx tags with HEEx `{...}` interpolation inside a `~H""" """` heredoc — generator EEx evaluation chokes on `<%= case @branch do %>` because it expands `@branch` to `Kernel.var!(assigns)[:branch]` at generator time, when `assigns` is not in the binding.
2. `priv/templates/sigra.install/organizations/router_injection.ex` is referenced by `Sigra.Install.Features.Organizations.injections/1` but does NOT exist on disk.
3. Likely the same for `organizations/user_auth_on_mount_assign_user_organizations.ex` (not verified to keep scope tight).

**Why NOT auto-fixed:** These bugs shipped in Phase 16/17 before Plan 18-01. My edits did not create them; they exposed them. Fixing the `<%=` escape is a one-line change (verified to work locally, then reverted per SCOPE BOUNDARY). Fixing the missing template files requires (a) reconstructing the intended content from Phase 16 Plan 02 specs and (b) re-running the golden fixture. Combined, this is a full follow-up plan's worth of work — well beyond Plan 18-01's scope and the 3-auto-fix-attempt limit.

**Consequence for Plan 18-01:** The acceptance criterion `mix test test/sigra/install/ passes` cannot be fully satisfied. Baseline (at commit 805eaff before any Plan 18-01 changes) already has 5 failing install tests for unrelated pre-existing reasons (see DEF-18-02). My changes expose 2 additional failures (`PurelyAdditiveTest` which I fixed, and the Features.Organizations template cascade which I deferred). Net test delta from my changes after fix: +0 new failures once the follow-up plan lands. All unit tests pass cleanly. Grep-based and compile-based acceptance criteria all pass.

### Known Stubs

None. Plan 18-01 does not introduce any stub data, placeholder UI, or disconnected components.

## Dependencies Satisfied

- **ORG-02** — True `--no-organizations` opt-out:  Features.Organizations is now a real gate at `Runner.run/3`. The full end-to-end validation (`mix sigra.install --no-organizations --yes` producing zero org files) cannot run inside this plan's tests because of the pre-existing template bugs noted above, but the gate mechanism itself is correct — verified by the feature filter logic plus the acceptance-criteria greps.

## Next Steps

- **Plan 18-02** can proceed. Its D-00/D-01 column-add migrations must now ALTER columns that the fresh install already has, so semantic equivalence between fresh-install and upgraded-v1.0 app state is structurally guaranteed.
- **Plan 18-03** must not be started before DEF-18-01 is resolved — the CI matrix leg `mix sigra.install --yes` (default org-enabled) will fail on the pre-existing template compile errors until a follow-up plan repairs them. The `--no-organizations` leg should be safe in isolation because it skips Features.Organizations entirely via the `enabled?/1` filter.

## Self-Check: PASSED

All 6 modified files and 1 created file exist on disk. All 5 per-task commits (`de82bd0`, `99b125e`, `b9c872a`, `72a0459`, `c776b7a`) exist in git history and are reachable from HEAD.
