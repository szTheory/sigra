---
phase: 25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor
reviewed: 2026-04-15T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/sigra/upgrade.ex
  - test/sigra/upgrade_test.exs
  - test/upgrade_test.exs
  - priv/templates/sigra.upgrade/alter_add_owner_user_id.exs
findings:
  critical: 0
  warning: 3
  info: 7
  total: 10
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-04-15
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Phase 25 fix for the duplicate migration version bug in `mix sigra.upgrade`. The core fix — `next_migration_timestamp/2` scanning `priv/repo/migrations/` and bumping past the highest extant 14-digit prefix, threaded with a per-run counter — is sound and has a dedicated regression test. Git-dirty guard, version detection, zero-org detection, and backfill gating are all covered by unit tests.

Main concerns:

1. A `File.exists?/1` vs `File.dir?/1` inconsistency in `next_migration_timestamp/2` that can silently mis-behave if a non-directory file shadows the migrations path.
2. The HTTP login integration test calls `pkill -f phx.server` in an `after` block, which will kill any unrelated `phx.server` process on the developer's machine.
3. The `alter_add_owner_user_id.exs` template is PostgreSQL-specific (PL/pgSQL `DO $$`, `information_schema`, `pg_constraint`) with no adapter guard or comment, conflicting with the CLAUDE.md constraint "MySQL/SQLite support via conditional migrations."

No critical security issues. No hardcoded secrets. No obvious correctness bugs in the migration-timestamp fix itself.

## Warnings

### WR-01: Inconsistent filesystem check (`File.exists?` vs `File.dir?`) in `next_migration_timestamp/2`

**File:** `lib/sigra/upgrade.ex:341`
**Issue:** `next_migration_timestamp/2` uses `File.exists?(migrations_dir)` to decide whether to scan for existing migrations, then calls `File.ls!` on that path. `File.exists?/1` returns `true` for *any* filesystem entry — regular files, symlinks, directories. If a non-directory somehow occupies `priv/repo/migrations` (unlikely but possible on a broken host app), `File.ls!` raises `File.Error` and crashes the upgrade mid-run. The companion function `organizations_table_present?/0` already uses `File.dir?/1` at line 181 for the same path — these should agree.
**Fix:**
```elixir
highest_existing =
  if File.dir?(migrations_dir) do
    migrations_dir
    |> File.ls!()
    ...
```

### WR-02: `pkill -f phx.server` in integration test kills unrelated host processes

**File:** `test/upgrade_test.exs:389`
**Issue:** The `after` block in `assert_login_redirects_to_organizations!/1` runs `System.cmd("pkill", ["-f", "phx.server"], ...)`. This matches any process on the host whose command line contains "phx.server", including unrelated Phoenix apps the developer is running in another terminal. On a developer laptop this silently kills the user's running dev server. CI is slightly safer but CI runners are sometimes shared.
**Fix:** Track the pid of the spawned `mix phx.server` and kill it by pid, or pin `-f` to a path-specific pattern:
```elixir
# Option A: pid-scoped
{_, 0} = System.cmd("pkill", ["-P", to_string(os_pid)], stderr_to_stdout: true)

# Option B: scope the pattern to this tmp app dir
System.cmd("pkill", ["-f", "phx.server.*#{Path.basename(app_dir)}"], stderr_to_stdout: true)
```
Prefer Option B if capturing the child pid from `Task.async(fn -> System.cmd(...) end)` is awkward.

### WR-03: `alter_add_owner_user_id.exs` template is PostgreSQL-only with no adapter guard

**File:** `priv/templates/sigra.upgrade/alter_add_owner_user_id.exs:27-52`
**Issue:** The template emits a PL/pgSQL `DO $$ BEGIN ... END$$` block, and references `information_schema.columns` and `pg_constraint`. None of this parses on MySQL or SQLite. CLAUDE.md constraint explicitly states "MySQL/SQLite support via conditional migrations" and "Never use PostgreSQL-specific features in core library modules; isolate to `Sigra.Adapters.Postgres`." A host app installed against MySQL/SQLite will hit a hard DDL error on `mix ecto.migrate` after running `mix sigra.upgrade`. This is the main library's recommended upgrade path — silently breaking it on non-Postgres adapters is a correctness regression.
**Fix:** Either (a) add an adapter-detection branch in `Sigra.Upgrade.migrations_to_emit/1` that selects a Postgres vs. generic template, or (b) at minimum gate the raw-SQL block on adapter detection at migration runtime and fall back to `add_if_not_exists :owner_user_id, references(...)`:
```elixir
def up do
  if repo().__adapter__() == Ecto.Adapters.Postgres do
    execute(~S[DO $$ ... END$$;], "")
  else
    alter table(:organizations) do
      add_if_not_exists :owner_user_id,
        references(<%= inspect(table_name) %>, on_delete: :nilify_all, type: <%= if binary_id, do: ":binary_id", else: ":id" %>)
    end
  end
  ...
end
```
If Postgres-only is the deliberate v1.1 scope, document it in the template `@moduledoc` and have the Mix task raise a clear error when the host app's adapter is not `Ecto.Adapters.Postgres`.

## Info

### IN-01: `upgrade_binding/0` table_name / schema_alias are hardcoded

**File:** `lib/sigra/upgrade.ex:314-320`
**Issue:** `table_name: "users"` and `schema_alias: "User"` are hardcoded in the binding. If a host app installed Sigra with a custom user table name (a plausible v1.x option), the generated migration will reference a non-existent `users(id)`. Worth a `TODO` or an explicit lookup from host config.
**Fix:** Either read from host app config (`Application.get_env(otp_app, :sigra_user_schema, ...)`) or comment that the template is fixed to the generator defaults and cross-reference the install task.

### IN-02: `write_migration/3` base timestamp always scans `priv/repo/migrations/` even for data migrations

**File:** `lib/sigra/upgrade.ex:291-292`
**Issue:** When writing a data migration (`dest_dir = priv/repo/data_migrations`), the timestamp generator still scans `priv/repo/migrations/` for the highest prefix. This is intentional and keeps both directories monotonic relative to schema migrations, but is non-obvious. A future contributor could assume the scan is per-destination and break the invariant.
**Fix:** Add a one-line comment:
```elixir
# Timestamp sequence is shared across schema + data migrations so
# their relative order is deterministic. Always seed from schema dir.
migrations_dir = Path.join(["priv", "repo", "migrations"])
```

### IN-03: `check_git_dirty/1` swallows non-zero git exit codes

**File:** `lib/sigra/upgrade.ex:94-97`
**Issue:** The catch-all `{_, _} -> :ok` clause treats any non-zero git exit as "not a git repo." It will also hide permission errors, corrupted `.git`, or git not being installed. Benign on developer machines but could mask a real problem.
**Fix:** Log a debug message or narrow the branch:
```elixir
{output, code} when code != 0 ->
  if String.contains?(output, "not a git repository") do
    :ok
  else
    Mix.shell().info("warning: git status failed (#{code}); skipping dirty-tree check")
    :ok
  end
```

### IN-04: `organizations_table_present?/0` crashes on any unreadable migration file

**File:** `lib/sigra/upgrade.ex:188`
**Issue:** `File.read!` inside `Enum.any?/2` raises if any file in `priv/repo/migrations/` is unreadable (permissions, broken symlink). The whole upgrade aborts with an obscure `File.Error`.
**Fix:** Use `File.read/1` and treat errors as "no match":
```elixir
case File.read(path) do
  {:ok, body} -> String.contains?(body, "create table(:organizations")
  _ -> false
end
```

### IN-05: `write_migration/3` silently overwrites a pre-existing destination

**File:** `lib/sigra/upgrade.ex:300`
**Issue:** `File.write!(dest, content)` will clobber any file that happens to sit at the computed destination. The monotonic-timestamp fix makes a collision with existing migrations very unlikely, but a user who ran `mix sigra.upgrade` twice in the same run (bug or shell-loop) could still overwrite freshly-generated files.
**Fix:** Guard with `File.exists?/1` and raise a clear error, or use `File.write!/3` with `[:exclusive]` mode so the OS enforces non-overwrite.

### IN-06: Login integration test hardcodes password into an `-e` script via string interpolation

**File:** `test/upgrade_test.exs:398-401`
**Issue:** `seed_login_user!/3` builds a script via string interpolation of `email` and `password` directly into Elixir source. Today the callers pass literal `"CorrectHorse!1"` and `"login@example.test"`, so there is no injection risk, but the pattern is brittle — any future caller passing a password with an embedded `"` or `\` will produce malformed Elixir that fails opaquely.
**Fix:** Use single-quoted charlists or pass values via environment variables:
```elixir
script = ~S"""
{:ok, _} = Application.ensure_all_started(:__OTP__)
__MOD__.Accounts.register_user(%{
  email: System.get_env("SIGRA_TEST_EMAIL"),
  password: System.get_env("SIGRA_TEST_PASSWORD")
})
"""
|> String.replace("__OTP__", otp_atom)
|> String.replace("__MOD__", otp_module)

InstallFixture.run_mix(app_dir, ["run", "-e", script],
  env: [{"SIGRA_TEST_EMAIL", email}, {"SIGRA_TEST_PASSWORD", password}])
```

### IN-07: Random port allocation without retry in HTTP login test

**File:** `test/upgrade_test.exs:284`
**Issue:** `port = 4444 + :rand.uniform(1000)` picks a port with no collision check. Two `@moduletag :upgrade` tests running concurrently (or a developer with something listening on the chosen port) will get a bind error surfaced as a 30-second `wait_for_http` timeout with an unhelpful message.
**Fix:** Loop until `:gen_tcp.listen(0, [...])` yields a free port, capture its port number, and pass that to `PORT=`:
```elixir
{:ok, listener} = :gen_tcp.listen(0, [])
{:ok, port} = :inet.port(listener)
:gen_tcp.close(listener)
```

---

_Reviewed: 2026-04-15_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
