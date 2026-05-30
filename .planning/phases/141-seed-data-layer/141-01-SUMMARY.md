---
phase: 141-seed-data-layer
plan: 01
subsystem: database
tags: [ecto, schema, migration, oauth, user-identities, example-app]

# Dependency graph
requires:
  - phase: 141-context
    provides: "UserIdentity field contract from list_identities/3 in Sigra.Admin.Users.Detail"
provides:
  - "Example.Accounts.UserIdentity Ecto schema with changeset/2 matching list_identities/3 contract"
  - "20260529000000_create_user_identities migration creating user_identities table with [:user_id, :provider] unique index"
affects: [141-03, 141-seed-carol-oauth-identity, admin-user-detail-identities-panel]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "De-templated schema from sigra.gen.oauth/user_identity.ex generator template: binary_id PK, Encrypted.Binary fields, changeset/2 (not create_changeset/2)"
    - "create_if_not_exists migration pattern for idempotency when dev DB has pre-existing table"

key-files:
  created:
    - test/example/lib/example/accounts/user_identity.ex
    - test/example/priv/repo/migrations/20260529000000_create_user_identities.exs
  modified: []

key-decisions:
  - "Used create_if_not_exists in migration — dev DB already had user_identities table from prior session; idempotent approach handles both fresh and existing DBs correctly"
  - "changeset/2 naming is load-bearing for plan 03 Carol seed upsert (NOT create_changeset/2)"
  - "utc_datetime (not utc_datetime_usec) for timestamps and token_expires_at — matches generator template and list_identities/3 field contract"

patterns-established:
  - "Example-app schemas follow binary_id PK + foreign_key_type :binary_id header convention from user_mfa_credential.ex / user_passkey.ex"
  - "OAuth identity schema is de-templated (not use Sigra.* macro) — owned by the example app, not the library"

requirements-completed: [SEED-02, SEED-03]

# Metrics
duration: 4min
completed: 2026-05-30
---

# Phase 141 Plan 01: Seed Data Layer — UserIdentity Schema + Migration Summary

**Example.Accounts.UserIdentity schema + idempotent create_user_identities migration wiring Carol's GitHub OAuth identity into the library admin detail panel via list_identities/3**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-30T01:31:34Z
- **Completed:** 2026-05-30T01:35:37Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `Example.Accounts.UserIdentity` Ecto schema de-templated from the library generator template, with `changeset/2` (load-bearing name for plan 03 Carol seed upsert) and the full field set satisfying `Sigra.Admin.Users.Detail.list_identities/3`'s query contract
- Created `20260529000000_create_user_identities.exs` migration with `[:user_id, :provider]` unique index (the required `on_conflict:` target for plan 03), using `create_if_not_exists` for idempotency across fresh and pre-existing dev DBs
- Migration applied cleanly in `MIX_ENV=dev`; re-run is a no-op; `mix compile --warnings-as-errors` exits 0

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Example.Accounts.UserIdentity schema** - `d8a38c6` (feat)
2. **Task 2: Create create_user_identities migration** - `cb89bc7` (feat)

## Files Created/Modified
- `test/example/lib/example/accounts/user_identity.ex` — OAuth identity Ecto schema; `changeset/2` casts provider/uid/tokens/profile/metadata, validates required `[:provider, :provider_uid, :user_id]`, normalizes provider to lowercase, enforces unique constraints; exposes `provider`, `provider_uid`, `provider_email`, `user_id`, `inserted_at` for `list_identities/3`
- `test/example/priv/repo/migrations/20260529000000_create_user_identities.exs` — creates `user_identities` table with binary_id PK, FK to users with `on_delete: :delete_all`, unique index on `[:user_id, :provider]` (plan 03 on_conflict target), unique index on `[:provider, :provider_uid]`, non-unique index on `[:user_id]`

## Decisions Made
- **create_if_not_exists migration**: The dev database already contained a `user_identities` table with the correct structure from a prior development session. Using `create_if_not_exists` makes the migration idempotent — it works on both a fresh database (Ecto creates the table) and the pre-existing dev database (Ecto skips the existing table and indexes). This is the correct Ecto migration pattern for this situation.
- **changeset/2 naming**: The function is deliberately named `changeset/2` (not `create_changeset/2`) to match the generator template convention. This is load-bearing: plan 03's Carol seed call will use `changeset/2` for the identity upsert.
- **utc_datetime (not utc_datetime_usec)**: Matches the generator template and the `list_identities/3` query contract. The MFA credential and passkey schemas use `utc_datetime_usec` for their own reasons, but the OAuth identity template uses `utc_datetime` — the example app follows the template.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Migration failure due to pre-existing user_identities table in dev DB**
- **Found during:** Task 2 (migration apply)
- **Issue:** `MIX_ENV=dev mix ecto.migrate` failed with `ERROR 42P07 (duplicate_table) relation "user_identities" already exists` — the dev DB had the table from a prior session, not tracked in schema_migrations
- **Fix:** Changed all three `create` calls to `create_if_not_exists` in the migration — table and all three indexes. The structure was verified to match exactly (same columns, same types, same indexes). Migration now applies cleanly on both fresh and pre-existing DBs.
- **Files modified:** `test/example/priv/repo/migrations/20260529000000_create_user_identities.exs`
- **Verification:** `MIX_ENV=dev mix ecto.migrate` exits 0; second run returns "Migrations already up"
- **Committed in:** cb89bc7 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug fix)
**Impact on plan:** Required for the migration to work on the existing dev DB. No scope creep. The fix makes the migration more robust for any dev environment where the table already exists.

## Issues Encountered
- Dev DB had pre-existing `user_identities` table with correct structure but not recorded in schema_migrations. Resolved with `create_if_not_exists` (see Deviations above).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `Example.Accounts.UserIdentity` is now available for `optional_schema(accounts_module, :UserIdentity)` auto-detection in `Sigra.Admin.Users.Detail` — the Identities panel will show real data instead of the "not available" fallback once a row is seeded
- The `[:user_id, :provider]` unique index is in place — plan 03 can use `on_conflict: {:replace, [...]}` keyed on this index for Carol's GitHub OAuth upsert
- No blockers for subsequent plans (141-02 through 141-04)

## Self-Check: PASSED

- FOUND: `test/example/lib/example/accounts/user_identity.ex`
- FOUND: `test/example/priv/repo/migrations/20260529000000_create_user_identities.exs`
- FOUND: `.planning/phases/141-seed-data-layer/141-01-SUMMARY.md`
- FOUND commit: `d8a38c6` (Task 1 — UserIdentity schema)
- FOUND commit: `cb89bc7` (Task 2 — migration)

---
*Phase: 141-seed-data-layer*
*Completed: 2026-05-30*
