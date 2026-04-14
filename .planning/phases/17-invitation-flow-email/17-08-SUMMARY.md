---
phase: 17-invitation-flow-email
plan: 08
subsystem: migration-template, phase-16-hotfix
tags: [sigra, migration, postgres-immutable, phase-16-hotfix, slug-alias, sidecar]
requires: []
provides:
  - "IMMUTABLE-safe organization_slug_aliases unique index"
  - "Adapter-symmetric slug-alias index name (:organization_slug_aliases_old_slug_idx)"
affects:
  - priv/templates/sigra.install/organizations/migration.exs
  - test/sigra/install/features/organizations_test.exs
tech-stack:
  added: []
  patterns:
    - "Application-layer expiry filter (not partial-index predicate)"
    - "IMMUTABLE-safe index constraints on Postgres partial indexes"
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/organizations/migration.exs
    - test/sigra/install/features/organizations_test.exs
decisions:
  - "Chose Option A (full unique index, application-level expiry filter) — consumer query in Sigra.Organizations.get_active_slug_alias/2 already filters by expires_at > now, so the partial predicate was structurally redundant"
  - "Also renamed the mysql/sqlite branch index from :organization_slug_aliases_old_slug_active_idx to :organization_slug_aliases_old_slug_idx so both adapter branches emit symmetric DDL — behavior-neutral on mysql/sqlite since that branch never had the partial predicate"
  - "No new test file created (no test/sigra/migrations/ directory) — added 4 tests to the existing test/sigra/install/features/organizations_test.exs under a new describe block, consistent with the generator-template test location"
  - "Did not touch test/example/priv/repo/migrations/*_create_organization_slug_aliases.exs — it already uses a plain unique_index (the legacy active_idx name) and is outside the plan's files_modified scope"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-14"
  tasks: 1
  commits: 2
  tests_added: 4
  tests_total: 1649
---

# Phase 17 Plan 08: Phase 16 Slug-Alias Migration IMMUTABLE Hotfix Summary

**One-liner:** Replaced the Phase 16 slug-alias migration's non-IMMUTABLE
partial-index predicate (`where: "expires_at > now()"`) with a plain unique
index (Option A), unblocking `mix ecto.migrate` on Postgres for host apps.

## Which option was chosen and why

**Option A — full unique index, application-level expiry filter.**

**Reasoning:** The consumer query already filters by `expires_at > now` at
the application layer (`Sigra.Organizations.get_active_slug_alias/2` in
`lib/sigra/organizations.ex:624-638`):

```elixir
from(a in alias_schema,
  where: a.old_slug == ^slug and a.expires_at > ^now,
  limit: 1
)
```

This is called from `Sigra.Plug.LoadOrganizationFromSlug.resolve_alias/2`,
which is the only consumer. The index-level partial predicate was
structurally redundant — every query path filters expiry at the query
layer, so the DB never needed to enforce "only match unexpired rows" at
the index level. The index's job is just uniqueness on `old_slug`.

**Trade-off acknowledged:** Expired slug rows now occupy the unique slot
until a cleanup worker hard-deletes them. If a host wanted to re-alias
the same `old_slug` to a new organization *before* cleanup ran, the
`Multi.insert` in `maybe_insert_slug_alias/5` would fail with a
uniqueness violation. In practice this is acceptable because:

1. The existing slug-alias TTL is 7 days, so collisions would require
   two organizations wanting the same old slug within 7 days of each
   other — rare.
2. The example app migration at
   `test/example/priv/repo/migrations/20260413120000_create_organization_slug_aliases.exs`
   already uses exactly this pattern (plain unique index on `old_slug`),
   which validates that the example ecosystem operates correctly under
   this constraint.
3. Application-level cleanup can always hard-delete the expired row
   immediately before retrying the insert if collision becomes a real
   operational problem — no library change required.

**Option B rejected:** A plain non-unique index would lose the "one live
alias per old_slug" invariant at the DB layer, pushing uniqueness
enforcement entirely to application code. Option A is strictly stronger
and the example-app precedent shows it is operationally fine.

## Changes to `priv/templates/sigra.install/organizations/migration.exs`

### Postgres branch (lines 74-89, was 74-78)

**Before:**
```elixir
create index(:organization_slug_aliases, [:organization_id])
create unique_index(:organization_slug_aliases, [:old_slug],
  where: "expires_at > now()",
  name: :organization_slug_aliases_old_slug_active_idx
)
```

**After:**
```elixir
create index(:organization_slug_aliases, [:organization_id])
# IMMUTABLE-safe slug-alias uniqueness (Phase 17 Plan 08 — Phase 16 hotfix).
# Postgres rejects `now()` inside partial index predicates because it is
# STABLE, not IMMUTABLE — a host running `mix ecto.migrate` would see
# `ERROR: functions in index predicate must be marked IMMUTABLE`.
#
# The consumer query (`Sigra.Plug.LoadOrganizationFromSlug` via
# `Sigra.Organizations.get_active_slug_alias/2`) already filters by
# `expires_at > ^DateTime.utc_now()` at the application layer, so the
# index-level partial predicate was structurally redundant. A full
# unique index enforces "at most one row per old_slug" and is the same
# shape the example app migration already uses (see
# test/example/priv/repo/migrations/*_create_organization_slug_aliases.exs).
# Cleanup of expired alias rows is application-level (hard-delete).
create unique_index(:organization_slug_aliases, [:old_slug],
  name: :organization_slug_aliases_old_slug_idx
)
```

### MySQL/SQLite branch — needed harmonization, not a bug fix

The MySQL/SQLite branch already used `create unique_index(:organization_slug_aliases, [:old_slug], name: :organization_slug_aliases_old_slug_active_idx)` — plain unique, no `where:` predicate, IMMUTABLE-safe by construction (MySQL/SQLite have no partial-index support so the Phase 16 planner had already written it as a plain unique index).

**Only change:** Renamed the index from `:organization_slug_aliases_old_slug_active_idx` to `:organization_slug_aliases_old_slug_idx` so both adapter branches emit symmetric DDL. This is a pure rename — zero behavior change on MySQL/SQLite.

**Why rename both:** If the two adapter branches diverged in index name, host-app migration diffs would look adapter-asymmetric, and any future grep-based assertion like the one added in this plan's test suite would have to special-case the adapter. Harmonizing now removes that footgun.

## Confirmation: Phase 16 consumer tests still pass

```
mix test test/sigra/plug/load_organization_from_slug_test.exs
9 tests, 0 failures
```

```
mix test test/sigra/organizations/context_test.exs --only phase16
21 tests, 0 failures
```

```
mix test
33 doctests, 3 properties, 1649 tests, 0 failures
```

Full-suite delta vs the pre-plan baseline (1645 from Plan 17-02):
**+4 tests**, 0 failures. The +4 are the new describe block added in this plan's RED commit.

## Golden fixture status

**Not updated — not present.**

The install-golden fixture tree at
`test/fixtures/install_golden/tree/priv/repo/migrations/` contains
migrations for `sigra_auth_tables`, `audit_events`, and
`user_sessions.active_organization_id`, but **no frozen copy of the
organizations migration**. Grep verified:

```
grep -rn "organization_slug_aliases" test/fixtures/
# → no matches
grep -rn "organization_slug_aliases_old_slug_active_idx" test/fixtures/
# → no matches
```

Since the golden harness never snapshotted the organizations migration,
there is nothing to update. If a future plan adds an organizations-tree
snapshot to the golden fixtures, it will pick up the post-17-08 shape
automatically.

## Tests added (4 under new describe block)

**`test/sigra/install/features/organizations_test.exs`** — new describe block
`"migration template IMMUTABLE-safety (Phase 17 Plan 08 — Phase 16 hotfix)"`:

1. **migration template has ZERO `now()` inside any index `where:` predicate**
   — `Regex.scan(~r/where:\s*"[^"]*now\(\)[^"]*"/, template)` must be empty.
   Catches both postgres AND mysql/sqlite branches in one pass. This is
   the primary regression gate for T-17-12.

2. **slug-alias unique index is present (Option A — full unique index)**
   — asserts `"organization_slug_aliases_old_slug_idx"` is present and
   that no `unique_index(:organization_slug_aliases, [:old_slug], where: "expires_at > now()")` block survives.

3. **Phase 17 Plan 02 `unique_index(:organization_invitations, [:hashed_token])`
   preserved** — asserts exactly 2 matches (one per adapter branch). Guards
   17-02's Task 3 work from accidental regression in this sidecar plan.

4. **Phase 16 D-03 `organization_invitations_pending_index` (IS NULL
   predicate) preserved** — asserts the pending-invitation partial index
   name and its IMMUTABLE-safe `accepted_at IS NULL AND revoked_at IS NULL`
   predicate both still appear.

Tests 3 and 4 are defensive pins: they turn "don't touch 17-02 / Phase 16
D-03" from a commit-message aspiration into a CI-enforced invariant for
future migration-template edits.

## Acceptance criteria check

| Criterion | Result |
|---|---|
| `grep -n 'where: "[^"]*now()[^"]*"' priv/templates/sigra.install/organizations/migration.exs` | 0 matches |
| `grep -n "organization_slug_aliases_old_slug_idx" priv/templates/sigra.install/organizations/migration.exs` | 2 matches (postgres + mysql/sqlite branches) |
| `grep -n "organization_invitations_pending_index" priv/templates/sigra.install/organizations/migration.exs` | 1 match (Phase 16 D-03 preserved) |
| `grep -nc "unique_index(:organization_invitations, \[:hashed_token\])" priv/templates/sigra.install/organizations/migration.exs` | 2 (Plan 17-02 untouched) |
| `mix compile --warnings-as-errors` | exits 0 |
| `mix test test/sigra/plug/load_organization_from_slug_test.exs` | 9/9 passing |
| `mix test` | 1649 tests, 0 failures |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Critical] Rename MySQL/SQLite branch index to match Postgres**

- **Found during:** Task 1 Step 3 (MySQL/SQLite branch check)
- **Issue:** The plan text said "MySQL/SQLite may not support partial
  indexes at all, so they likely already use a plain index. Verify before
  editing." Verification confirmed the MySQL/SQLite branch already used
  `create unique_index(:organization_slug_aliases, [:old_slug], name: :organization_slug_aliases_old_slug_active_idx)` — IMMUTABLE-safe
  by construction. But after renaming the postgres index to
  `:organization_slug_aliases_old_slug_idx`, the two adapter branches
  would emit DIFFERENT index names. Any future grep-based assertion or
  schema-diff tool would be forced to special-case the adapter.
- **Fix:** Renamed the mysql/sqlite branch index to
  `:organization_slug_aliases_old_slug_idx` as well. Zero behavior
  change on mysql/sqlite (the rename touches only the `name:` keyword,
  not the `where:` clause, which was already absent).
- **Files modified:** `priv/templates/sigra.install/organizations/migration.exs`
- **Commit:** `7638266`

**2. [Rule 3 — Blocking] Test file location — no `test/sigra/migrations/` directory**

- **Found during:** Task 1 Step 5 (add a migration test)
- **Issue:** Plan said "If `test/sigra/migrations/` exists, add
  `slug_alias_migration_test.exs`". That directory does not exist. Plan
  also said "If the existing Phase 11 install smoke harness already
  covers this, a grep-level acceptance check is sufficient and no new
  test file is needed" — but the smoke harness does NOT cover
  migration-template IMMUTABLE assertions.
- **Fix:** Added the regression tests to the existing
  `test/sigra/install/features/organizations_test.exs` under a new
  describe block. This is consistent with where other
  migration-template assertions already live in the codebase
  (`"migrations/1"` describe block in the same file is the existing
  pattern).
- **Files modified:** `test/sigra/install/features/organizations_test.exs`
- **Commit:** `750eb0c`

**3. Worktree base reset to 2907fb7**

- **Found during:** Pre-execution worktree branch check
- **Issue:** Worktree was at commit `4efb4a5` (Phase 11 completion) per
  `git log HEAD`, but the plan expected base `2907fb7` (17-02 landed).
  The entire `.planning/phases/17-invitation-flow-email/` directory and
  17-02's `unique_index(:organization_invitations, [:hashed_token])`
  additions were absent.
- **Fix:** `git reset --hard 2907fb7` — the 17-02 commits already
  existed in the repo's reflog; this just pointed the worktree branch
  at them. Verified post-reset that 17-02's unique_index additions were
  present in the migration template (both branches, line 57 postgres
  and line 134 mysql/sqlite) and that the phase 17 planning directory
  was populated.
- **Files modified:** none (hard reset)

## Auth Gates

None — fully autonomous, no external verification needed.

## Commits (in order)

| Commit    | Type | Summary                                                               |
| --------- | ---- | --------------------------------------------------------------------- |
| `750eb0c` | test | RED — 4 failing tests for IMMUTABLE-safe slug-alias migration         |
| `7638266` | fix  | GREEN — replace non-IMMUTABLE slug-alias index predicate (Option A)   |

## Verification Results

```
mix compile --warnings-as-errors                                         → clean
mix test test/sigra/install/features/organizations_test.exs              → (unit) passing
mix test test/sigra/plug/load_organization_from_slug_test.exs            → 9/9 passing
mix test test/sigra/organizations/context_test.exs --only phase16        → 21/21 passing
mix test                                                                 → 33 doctests, 3 properties, 1649 tests, 0 failures
```

## Known Stubs

None — the fix is a direct replacement of a broken index predicate with a
working one. No placeholder values, no deferred logic, no mock data paths.

## Threat Flags

None — the plan's threat register entry T-17-12 (availability: migration
failure) is the sole threat, and it is now mitigated by construction
(the predicate it flagged no longer exists in the template).

## Self-Check: PASSED

**Modified files verified via grep:**

- FOUND: `organization_slug_aliases_old_slug_idx` (2× — postgres + mysql/sqlite) in `priv/templates/sigra.install/organizations/migration.exs`
- MISSING as expected: `where: "expires_at > now()"` in `priv/templates/sigra.install/organizations/migration.exs` (0 matches — the bug is gone)
- FOUND: `organization_invitations_pending_index` (1×) in `priv/templates/sigra.install/organizations/migration.exs` (Phase 16 D-03 preserved)
- FOUND: `unique_index(:organization_invitations, [:hashed_token])` (2×) in `priv/templates/sigra.install/organizations/migration.exs` (Plan 17-02 preserved)
- FOUND: `describe "migration template IMMUTABLE-safety (Phase 17 Plan 08 — Phase 16 hotfix)"` in `test/sigra/install/features/organizations_test.exs`

**Commits:**

- FOUND: `750eb0c` (test RED — 4 failing IMMUTABLE-safety tests)
- FOUND: `7638266` (fix GREEN — Option A replacement + mysql/sqlite name harmonization)
