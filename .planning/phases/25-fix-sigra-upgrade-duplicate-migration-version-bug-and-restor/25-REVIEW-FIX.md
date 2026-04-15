---
phase: 25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor
fixed_at: 2026-04-15T00:00:00Z
review_path: .planning/phases/25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor/25-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 25: Code Review Fix Report

**Fixed at:** 2026-04-15
**Source review:** `.planning/phases/25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor/25-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (Critical + Warning)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: Inconsistent filesystem check (`File.exists?` vs `File.dir?`) in `next_migration_timestamp/2`

**Files modified:** `lib/sigra/upgrade.ex`
**Commit:** `2fbd428`
**Applied fix:** Changed `File.exists?(migrations_dir)` to `File.dir?(migrations_dir)` in `next_migration_timestamp/2` (line 341) so the guard agrees with `organizations_table_present?/0` and avoids a `File.ls!` crash if a non-directory occupies the migrations path.

### WR-02: `pkill -f phx.server` in integration test kills unrelated host processes

**Files modified:** `test/upgrade_test.exs`
**Commit:** `de37299`
**Applied fix:** Scoped the `pkill -f` pattern to `phx.server.*#{Path.basename(app_dir)}` so the kill only matches the `mix phx.server` process running inside this test's tmp app directory. Unrelated `phx.server` processes on the developer machine or shared CI runners are no longer affected. Added an explanatory comment.

### WR-03: `alter_add_owner_user_id.exs` template is PostgreSQL-only with no adapter guard

**Files modified:** `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs`
**Commit:** `da704b1`
**Applied fix:** Wrapped both the `up/0` PL/pgSQL `DO $$ ... END$$` block and the `down/0` drop block in `if repo().__adapter__() == Ecto.Adapters.Postgres do ... else ... end`. The non-Postgres branch uses Ecto's DSL (`alter table(:organizations) do add_if_not_exists(:owner_user_id, references(...)) end` for `up`, `remove_if_exists/1` for `down`), which is adapter-agnostic and satisfies CLAUDE.md's "MySQL/SQLite support via conditional migrations" constraint. Added a comment explaining why the Postgres branch needs raw SQL (duplicate-constraint crash on re-run) vs why the DSL is sufficient elsewhere.

## Skipped Issues

None.

---

_Fixed: 2026-04-15_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
