# Phase 25: fix Sigra.Upgrade duplicate-migration-version bug and restore upgrade integration tests — Research

**Researched:** 2026-04-15
**Domain:** Elixir / Ecto migration filename generation; ExUnit integration-test plumbing for code generated into tmp apps
**Confidence:** HIGH

## Summary

Phase 25 un-skips `Sigra.UpgradeIntegrationTest` (the 3 tests in `test/upgrade_test.exs`) by fixing two latent bugs that PR #9 surfaced when it renamed the shadowed integration module. The bugs are fully scoped, both are small, and both have known-good fix shapes already present elsewhere in this codebase.

**Bug B** is a real product defect in `Sigra.Upgrade.write_migration/2` (`lib/sigra/upgrade.ex:285`). The upgrade task stamps migrations with `Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")` — a wall-clock, 1-second-granularity string. Meanwhile `Sigra.Install` uses a **deterministic slot allocator** (`Sigra.Install.MigrationTimestamps.allocate/2`) that takes a `base_time` and produces `base_time + N seconds` for each of N slots (4 under `--no-organizations`, 6 with orgs). When `mix sigra.upgrade` runs back-to-back with `mix sigra.install`, `utc_now()` falls inside the `[base_time, base_time + N-1s]` range that install already consumed — Ecto rejects the directory with `migration version NNNN is duplicated`. The in-code comment at line 284 ("microsecond bump") is aspirational and does not actually disambiguate anything.

**Bug A** is a 1-character-wide test helper defect. `organizations_table_exists?/1` (`test/upgrade_test.exs:224`) and `count_personal_orgs!/1` (`test/upgrade_test.exs:200`) both use `mix run -e` → `String.split("\n") |> List.last() |> String.to_integer()`. The problem is that Ecto's default `:log` level prints the echoed SQL plus its param list as the final line of stdout (e.g. `SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations' []`), which comes **after** the `IO.puts(count)` line. `List.last()` grabs the SQL trace, not the integer.

**Primary recommendation:** Fix Bug B with **"scan existing `priv/repo/migrations/` and bump past the highest extant 14-digit prefix"** (Option 2 from the prompt) — it mirrors the existing `Sigra.Install.MigrationTimestamps` philosophy, survives multi-task bursts, needs no clock fiddling, and is trivially unit-testable in `test/sigra/upgrade_test.exs`. Fix Bug A by replacing the `IO.puts → String.split → List.last` pattern with a deterministic `"SIGRA_RESULT: #{count}"` sentinel prefix plus a `Regex.run/2` extractor. This is cheaper than plumbing Postgrex directly (which would require starting the tmp app's Repo from the library's test process — risky for env pollution).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Migration filename generation (upgrade) | Library (`Sigra.Upgrade`) | — | Library must own the timestamp contract; host app never reaches into `priv/repo/migrations/` itself |
| Migration filename generation (install) | Library (`Sigra.Install.MigrationTimestamps`) | — | Already correct — deterministic slot allocator |
| Collision avoidance between install and upgrade | Library (`Sigra.Upgrade`) | — | Upgrade is the newer actor; it MUST observe existing prefixes before writing |
| Integration test harness (`mix sigra.install` → `mix sigra.upgrade` → assertions) | Test suite (`test/upgrade_test.exs`) | `Sigra.Test.InstallFixture` (test support) | Lives in test/, not lib/; exercises the public Mix task surface via `System.cmd` |
| Table introspection from integration test | Test suite | — | Must cross the tmp-app boundary — only viable path is `mix run -e` or opening a second Postgrex connection from the library test process |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | ~> 1.18 | Language | Project minimum per `CLAUDE.md`; both fixes use only stdlib (`Calendar`, `DateTime`, `Regex`, `File`, `Path`) |
| Ecto | ~> 3.13 | Migration DSL | `Ecto.MigrationError` is the exception raised on duplicate version; 14-digit numeric prefix convention is Ecto's |
| ExUnit | stdlib | Test framework | `@moduletag skip: "reason"` is the exact construct PR #9 used; removing it is the success criterion |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Install.MigrationTimestamps` | (internal) | Deterministic slot allocator used by install | Reference implementation / precedent for upgrade fix |
| `Sigra.Test.InstallFixture` | (internal, `test/support/install_fixture.ex`) | Spawns tmp apps, runs `mix sigra.install`/`sigra.upgrade` via `System.cmd` | Already wired; no changes needed in Phase 25 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Scan-and-bump (Option 2) | `System.unique_integer([:monotonic, :positive])` suffix | Produces non-14-digit filenames — Ecto's regex-based migration loader would reject them. Rejected. |
| Scan-and-bump (Option 2) | `Process.sleep(1000)` until next second | Slows every upgrade invocation by up to 1s; does not survive burst scenarios in CI where install+upgrade+upgrade might all land inside 1s. Rejected as primary; keep as last-resort. |
| Regex sentinel (Bug A fix) | Start a second Postgrex connection from the library test process targeting the tmp app's DB | Requires duplicating repo config lookup; pollutes the library test env with the tmp app's schema; creates a second connection pool that outlives the `mix run` subprocess. Rejected. |
| Regex sentinel (Bug A fix) | Write the count to a temp file and read it back | More moving parts than a sentinel regex; needs cleanup. Rejected. |

**Installation:** No new deps required. This phase adds zero Hex entries.

**Version verification:** N/A (stdlib-only fixes).

## Architecture Patterns

### System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│ Sigra.UpgradeIntegrationTest (test/upgrade_test.exs)                 │
│                                                                      │
│  ┌──────────────────────┐                                            │
│  │ setup_tmp_app        │──┐                                         │
│  └──────────────────────┘  │                                         │
│                            ▼                                         │
│  ┌──────────────────────┐   System.cmd("mix", ["sigra.install"])     │
│  │ run_sigra_install    │───────────────────────────────────────┐    │
│  └──────────────────────┘                                       │    │
│                                                                 ▼    │
│  ┌──────────────────────┐  writes priv/repo/migrations/         ┌──┐ │
│  │ seed_users!          │◄──(ecto.drop/create/migrate/run -e)───┤DB│ │
│  └──────────────────────┘                                       └──┘ │
│                            │                                         │
│                            ▼                                         │
│  ┌──────────────────────┐   System.cmd("mix", ["sigra.upgrade"])     │
│  │ run_sigra_upgrade    │────────► Sigra.Upgrade.run/1               │
│  └──────────────────────┘          │                                 │
│                                    ▼                                 │
│                         write_migration/2 ◄── [BUG B lives here]     │
│                                    │                                 │
│                                    ▼                                 │
│                         Calendar.strftime(utc_now, ...)              │
│                                    │                                 │
│                                    ▼                                 │
│                         priv/repo/migrations/NNNN_alter_*.exs        │
│                                    │                                 │
│                  ┌─────────────────┴─────────────────┐               │
│                  │  collision: NNNN already owned    │               │
│                  │  by an install slot               │               │
│                  └─────────────────┬─────────────────┘               │
│                                    ▼                                 │
│                        mix ecto.migrate                              │
│                              │                                       │
│                              ▼                                       │
│                 ** (Ecto.MigrationError)                             │
│                 migration version NNNN is duplicated                 │
│                                                                      │
│  ┌──────────────────────┐                                            │
│  │ organizations_table_ │  mix run -e "... IO.puts(length(rows))"    │
│  │ exists?/1            │───► stdout:                                │
│  └──────────────────────┘     "1\n                                   │
│    [BUG A lives here]           SELECT 1 FROM information_schema...  │
│                                  [...] []"                           │
│                                   │                                  │
│                                   ▼                                  │
│                       String.split("\n") |> List.last()              │
│                                   │                                  │
│                                   ▼                                  │
│                       "SELECT 1 FROM ..."                            │
│                                   │                                  │
│                                   ▼                                  │
│                       String.to_integer/1  ← ArgumentError           │
└──────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

No structural changes. Fixes live in:

```
lib/sigra/upgrade.ex            # Bug B fix (write_migration/2 + new helper)
test/sigra/upgrade_test.exs     # NEW regression test describe block for Bug B
test/upgrade_test.exs           # Bug A fix (helper rewrites); remove @moduletag skip
```

### Pattern 1: Scan-and-bump migration timestamps

**What:** Before stamping a migration, read `priv/repo/migrations/`, extract the 14-digit prefixes of existing files, take the max, and compute `max(now, highest_existing + 1s)` as the seed. Then allocate subsequent migrations in the same upgrade run as `seed, seed+1s, seed+2s, ...`.

**When to use:** Any mix task that writes migration files into a directory that another task may have recently written to.

**Example:**
```elixir
# lib/sigra/upgrade.ex — proposed shape

@spec next_migration_timestamp(Path.t(), DateTime.t()) :: String.t()
def next_migration_timestamp(migrations_dir, now \\ DateTime.utc_now()) do
  now_stamp = Calendar.strftime(now, "%Y%m%d%H%M%S")

  highest =
    migrations_dir
    |> existing_prefixes()
    |> Enum.max(fn -> "00000000000000" end)

  if highest >= now_stamp do
    bump_one_second(highest)
  else
    now_stamp
  end
end

defp existing_prefixes(dir) do
  if File.dir?(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn filename ->
      case Regex.run(~r/^(\d{14})_/, filename) do
        [_, prefix] -> [prefix]
        _ -> []
      end
    end)
  else
    []
  end
end

defp bump_one_second(stamp) do
  # Parse 14-digit stamp back to DateTime, add 1 second, reformat.
  <<y::binary-4, mo::binary-2, d::binary-2,
    h::binary-2, mi::binary-2, s::binary-2>> = stamp

  {:ok, dt, _} =
    DateTime.from_iso8601("#{y}-#{mo}-#{d}T#{h}:#{mi}:#{s}Z")

  dt
  |> DateTime.add(1, :second)
  |> Calendar.strftime("%Y%m%d%H%M%S")
end
```

Source: `lib/sigra/install/migration_timestamps.ex` (existing slot allocator precedent).

Then `write_migration/2` is updated to thread a per-upgrade-run counter so that when the upgrade emits multiple migrations (the normal case: 2 or 3 files), each subsequent file is stamped `base + N` where `base` comes from `next_migration_timestamp/2`. In practice the simplest shape is to compute `base` once in `emit_migrations/1`, then pass an index into `write_migration/3`.

### Pattern 2: Sentinel-prefixed `mix run -e` output

**What:** When scraping numeric values out of `mix run -e` stdout, tag the output line with a unique prefix and extract with a regex. Never rely on line ordering.

**When to use:** Any integration test that invokes `mix run -e` against a tmp app and parses stdout.

**Example:**
```elixir
# test/upgrade_test.exs — proposed shape

@sigra_result_marker "SIGRA_TEST_RESULT"

defp organizations_table_exists?(app_dir) do
  otp_atom = otp_app_atom(app_dir)
  otp_module = otp_app_module(app_dir)

  script = """
  {:ok, _} = Application.ensure_all_started(:#{otp_atom})
  result =
    Ecto.Adapters.SQL.query!(
      #{otp_module}.Repo,
      "SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations'",
      []
    )
  IO.puts("#{@sigra_result_marker}:\#{length(result.rows)}")
  """

  case InstallFixture.run_mix(app_dir, ["run", "-e", script]) do
    {:ok, out} -> extract_sentinel_int(out) > 0
    _ -> false
  end
end

defp extract_sentinel_int(out) do
  case Regex.run(~r/#{@sigra_result_marker}:(\d+)/, out) do
    [_, int_str] -> String.to_integer(int_str)
    nil -> raise "no #{@sigra_result_marker} sentinel in output:\n#{out}"
  end
end
```

Source: standard pattern for subprocess output scraping; already used implicitly by `parse_http_status/1` at test/upgrade_test.exs:372 which uses a regex on multi-line HTTP response output.

### Anti-Patterns to Avoid

- **`List.last(String.split(out, "\n"))` for subprocess output:** stdout is unordered-by-source. Ecto query logging, warnings, and `IO.puts` all interleave. Always use a sentinel or named marker.
- **`DateTime.utc_now()` for migration filenames when other tasks may write to the same dir:** Wall-clock, 1-second granularity, no coordination. Use scan-and-bump.
- **Fixing Bug B by adding microseconds to the format string (`%Y%m%d%H%M%S%f`):** Would produce 20-digit prefixes that Ecto's migration loader will either reject or parse as way-future versions. Ecto expects exactly 14 digits.
- **Fixing Bug A by passing `--no-start` to `mix run -e`:** The test scripts intentionally start the app (`Application.ensure_all_started`) because they need the Repo. Suppressing Ecto logs via `Logger.configure(level: :warning)` inside the script works but is indirect; a sentinel is more robust.
- **Attempting to suppress Ecto's SQL echo via `Application.put_env(:logger, :level, :error)`:** Fragile across Ecto versions; leaks test knowledge into the script; does not help if the script has other IO.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Duplicate migration detection | Custom "check if this filename exists" loop | Scan-and-bump helper that reads the directory once and takes max | Race-safe (writes are single-process within the mix task), handles bursts |
| stdout line extraction | `String.split |> Enum.at(-2)` or similar positional hacks | Regex sentinel | Log output interleaves; positional assumptions break silently |
| 14-digit timestamp parsing | `Integer.parse` on the prefix and arithmetic on the int | Parse back to `DateTime`, add seconds, reformat | Month/day/hour rollover correctness (`20260415235959 + 1s` must become `20260416000000`, not `20260415236000`) |

**Key insight:** Both bugs are the same archetype — "fragile string munging where a structured representation would be safer." The fixes should mirror patterns already present in the codebase (`Sigra.Install.MigrationTimestamps` for B; `parse_http_status/1` for A).

## Runtime State Inventory

This is not a rename/refactor/migration phase — it is a bug fix inside existing code paths. No runtime state inventory required.

**Stored data:** None — fixes don't touch any database content.
**Live service config:** None.
**OS-registered state:** None.
**Secrets and env vars:** None.
**Build artifacts / installed packages:** None. After the fix, recompilation is automatic via `mix compile`.

## Common Pitfalls

### Pitfall 1: Testing Bug B with a mock clock instead of real filesystem state
**What goes wrong:** If the unit regression test stubs `DateTime.utc_now/0` to return a fixed value and asserts "two consecutive calls produce distinct outputs," it does NOT actually exercise the collision scenario. The real collision is upgrade stamping inside install's already-allocated range, not two upgrade calls fighting each other.
**Why it happens:** "Two calls in the same second" is easy to unit-test with a stub; "upgrade stamping into install's allocator range" requires setting up a real `priv/repo/migrations/` directory first.
**How to avoid:** The regression test should write two fake files (`20260415120000_foo.exs`, `20260415120001_bar.exs`) into a tmp `priv/repo/migrations/` dir, then call `Sigra.Upgrade.next_migration_timestamp/2` with `DateTime.utc_now()` frozen at `2026-04-15 12:00:00Z`, and assert the result is `20260415120002` (strictly greater than the highest existing). The existing `Sigra.UpgradeTest` test module already sets up a tmp-cwd for exactly this kind of filesystem-backed test (`lib/sigra/upgrade_test.exs:7-19`).
**Warning signs:** Test uses `:meck` or `Mox` for `DateTime`; test passes but integration tests still fail.

### Pitfall 2: Forgetting that the integration test DB is long-lived across runs
**What goes wrong:** The `seed_users!/2` helper (test/upgrade_test.exs:172) already calls `ecto.drop --force` because the fixture uses **fixed app names** per test (upgrade_zero_org, upgrade_default_org, upgrade_with_backfill) against a **persistent** local postgres. If a previous run leaked state, it's cleaned up. But if Bug B fix is wrong and leaves a stale migration file in `priv/repo/migrations/`, the *next* run of the same test will see that file and think the upgrade has already been applied (idempotent no-op path).
**Why it happens:** Tmp app dirs under `System.tmp_dir!()` may or may not be garbage-collected between test runs; `InstallFixture.setup_tmp_app_without_install/1` almost certainly creates a fresh dir (verify in `test/support/install_fixture.ex`) but locally-run tests can leave stale state.
**How to avoid:** Trust the fixture's tmp-dir contract; do not try to delete `priv/repo/migrations/` from inside the test body. If the fixture is NOT using a fresh tmp dir per test, that is a separate defect to surface.
**Warning signs:** Tests pass on first run but fail on re-run; or pass locally but fail in CI.

### Pitfall 3: Bumping the stamp by 1 second can overflow into a future slot the install already allocated
**What goes wrong:** If `sigra.install` allocated slots `[N, N+1, N+2, N+3]` and upgrade collides at `N`, naive "bump by 1" gives `N+1` — still a collision. Must take `max(highest_existing + 1s, now_stamp)`.
**Why it happens:** The allocator is counter-based up to N slots; the "highest existing" is the correct signal, not "current collision".
**How to avoid:** Use `Enum.max` across all existing 14-digit prefixes in the directory, not `Enum.find` on the specific collision.
**Warning signs:** Fix works when upgrade is called immediately after install but fails when called during a burst.

### Pitfall 4: Emitting 2 or 3 migrations from a single upgrade run
**What goes wrong:** `Sigra.Upgrade.migrations_to_emit/1` returns up to 3 entries (`alter_add_owner_user_id`, `alter_add_personal`, `data_migration`). If scan-and-bump is called fresh for each entry but all three calls happen in the same upgrade run, they all compute the same base and overwrite each other (or collide among themselves).
**Why it happens:** Each write calls `next_migration_timestamp/2` independently; filesystem hasn't been re-read between calls because all three writes happen in one pass.
**How to avoid:** Compute the base once at the start of `emit_migrations/1`, then pass `base + index` into each `write_migration/3` call. OR re-scan the directory after each write (slower but simpler).
**Warning signs:** Integration test for the backfill path fails with duplicate-version error; unit test for single migration passes.

### Pitfall 5: Un-skipping the integration test before both fixes land
**What goes wrong:** If Plan 25-01 lands Bug B's fix and removes `@moduletag skip:` in the same commit, the test still fails on Bug A. CI goes red.
**Why it happens:** Two independent bugs gated by a single skip tag.
**How to avoid:** Land both fixes before removing the skip. Either: (a) single PR with both fixes, or (b) sequenced plans where Plan 25-01 fixes Bug B + adds the unit regression test but LEAVES the skip tag; Plan 25-02 fixes Bug A AND removes the skip tag atomically.
**Warning signs:** CI red after an early merge; partial un-skip.

## Code Examples

### Example 1: Existing deterministic slot allocator (precedent for Bug B fix)

```elixir
# lib/sigra/install/migration_timestamps.ex
def allocate(features, %DateTime{} = base_time) when is_list(features) do
  {result, _counter} =
    Enum.reduce(features, {%{}, 0}, fn feature_mod, {acc, counter} ->
      slots = feature_mod.migrations([])

      {slot_map, new_counter} =
        Enum.reduce(slots, {%{}, counter}, fn {slot_key, _template, _basename}, {map, c} ->
          ts = format_timestamp(base_time, c)
          {Map.put(map, slot_key, ts), c + 1}
        end)

      {Map.put(acc, feature_mod, slot_map), new_counter}
    end)

  result
end

defp format_timestamp(%DateTime{} = base, offset_seconds) do
  base
  |> DateTime.add(offset_seconds, :second)
  |> Calendar.strftime("%Y%m%d%H%M%S")
end
```

Key insight: the installer picks a single `base_time` for the whole run and advances a counter. The upgrade should do the same, but anchor its `base_time` at `max(now, highest_existing_prefix + 1s)`.

### Example 2: Existing regex-based output parser (precedent for Bug A fix)

```elixir
# test/upgrade_test.exs:372 — the HTTP helper already does exactly this
defp parse_http_status(raw) do
  case Regex.run(~r/^HTTP\/[\d.]+\s+(\d+)/m, raw) do
    [_, code] -> String.to_integer(code)
    _ -> 0
  end
end
```

The same file already has a regex-based stdout scraper for HTTP status codes. Bug A fix should use the same shape but scan for a `SIGRA_TEST_RESULT:\d+` sentinel written deliberately by the `mix run -e` script.

### Example 3: The broken `organizations_table_exists?/1` (exactly what to replace)

```elixir
# test/upgrade_test.exs:224-251 — BROKEN
defp organizations_table_exists?(app_dir) do
  otp_atom = otp_app_atom(app_dir)
  otp_module = otp_app_module(app_dir)

  script = """
  {:ok, _} = Application.ensure_all_started(:#{otp_atom})
  result =
    Ecto.Adapters.SQL.query!(
      #{otp_module}.Repo,
      "SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations'",
      []
    )
  IO.puts(length(result.rows))   # ← Ecto's :debug log line prints AFTER this
  """

  case InstallFixture.run_mix(app_dir, ["run", "-e", script]) do
    {:ok, out} ->
      out
      |> String.trim()
      |> String.split("\n")
      |> List.last()               # ← grabs "SELECT 1 FROM ... []", not the count
      |> String.to_integer()       # ← raises ArgumentError
      |> Kernel.>(0)
    _ -> false
  end
end
```

### Example 4: The broken `count_personal_orgs!/1` (same archetype, same fix)

```elixir
# test/upgrade_test.exs:200-222 — BROKEN by the same pattern
defp count_personal_orgs!(app_dir) do
  # ...
  script = """
  import Ecto.Query
  {:ok, _} = Application.ensure_all_started(:#{otp_atom})
  count =
    #{otp_module}.Repo.aggregate(
      from(o in "organizations", where: o.personal == true),
      :count
    )
  IO.puts(count)                   # ← same trailing-SQL issue
  """

  {:ok, out} = InstallFixture.run_mix(app_dir, ["run", "-e", script])

  out
  |> String.trim()
  |> String.split("\n")
  |> List.last()                   # ← broken
  |> String.to_integer()
end
```

**Confirmation:** both helpers use the same broken pattern. Both must be fixed in Plan 25-02. No other `String.to_integer` calls on subprocess output exist in `test/upgrade_test.exs`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DateTime.utc_now |> strftime` for migration stamps | Counter-based slot allocator (install) / scan-and-bump (upgrade, proposed) | Phase 11 (install), Phase 25 (upgrade) | Eliminates timing-dependent cross-task collisions |
| `List.last(String.split)` for subprocess output | Sentinel-prefixed regex extraction | Phase 25 | Robust against Ecto log interleaving |

**Deprecated/outdated:**
- The in-source comment at `lib/sigra/upgrade.ex:283-284` ("microsecond bump") describes behavior the code does NOT implement. Update the comment as part of the fix.
- The module shadowing blind spot (`Sigra.UpgradeTest` defined twice) was closed by PR #9 (`63ea853`, 2026-04-15) via rename to `Sigra.UpgradeIntegrationTest`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sigra.install` currently allocates 4 core slots under `--no-organizations` and 6 slots with orgs | Summary | Low — only affects how we explain the collision window; fix works regardless of slot count [VERIFIED: lib/sigra/install/features/core.ex:85 + features/organizations.ex:166] — actually VERIFIED, promote to VERIFIED |
| A2 | Ecto.MigrationError's "duplicated version" message is raised by `Ecto.Migrator` when it finds two files with the same 14-digit prefix | Summary | Low — even if message differs in newer Ecto, the duplicate rejection is a core Ecto contract [ASSUMED from training + code comment in test/upgrade_test.exs:34] |
| A3 | `mix run -e` output interleaves `IO.puts` and Ecto's SQL echo such that the echo is the last line | Bug A | Medium — if the actual failure mode is different (e.g., warning, startup log, not SQL echo), the sentinel fix still works but the diagnosis is wrong. The prompt confirms the SQL echo line content, so this is [CITED: prompt additional_context] |
| A4 | The fixture at `test/support/install_fixture.ex` creates a fresh tmp dir per test (no state leak between runs) | Pitfall 2 | Medium — if false, tests may be flaky on re-run. Verify during planning by reading install_fixture.ex |
| A5 | `Sigra.Upgrade.write_migration/2` is only called from `emit_migrations/1` (no other call sites) | Pattern 1 | Low — grep confirmed only one call site in lib/sigra/upgrade.ex:268 [VERIFIED: Read tool, lib/sigra/upgrade.ex] |
| A6 | Ecto's default dev-env `log: :debug` on the host app's Repo is responsible for the SQL echo in `mix run -e` output | Bug A | Low — regardless of cause, the sentinel fix sidesteps the issue. If Ecto is NOT the source, whatever else is writing to stdout would still be filtered out by the regex |

**Verified/Cited counts:** A1 verified, A5 verified, A3 cited — promote those. A2, A4, A6 remain assumed but are low-risk.

## Open Questions

1. **Should Plan 25-01 and Plan 25-02 be separate plans or one?**
   - What we know: Bugs are independent; Bug B fix has a unit regression test, Bug A fix only has integration coverage. Each fix is small (<30 lines of production/test code).
   - What's unclear: Whether the planner prefers atomic "bug → fix → test → un-skip" cycles or allows staged landings.
   - Recommendation: **Two plans.** Plan 25-01 = Bug B fix + unit regression test in `test/sigra/upgrade_test.exs` (no integration touch, skip tag stays). Plan 25-02 = Bug A fix + remove skip tag + verify 3/3 integration tests green against local postgres. This keeps each plan's blast radius tiny and lets Plan 25-01 land even if Plan 25-02 discovers a third latent bug. Success criterion #4 (unit regression test) is covered by Plan 25-01; SC #1/#2/#3/#5 are covered by Plan 25-02; SC #6 (full suite stays green) is verified on every commit in both plans.

2. **Should `next_migration_timestamp/2` be a public or private function in `Sigra.Upgrade`?**
   - What we know: It needs to be callable from the unit regression test in `test/sigra/upgrade_test.exs`.
   - What's unclear: Whether exposing it widens the library's public API surface in a way Phase 18's D-08 contract prohibits.
   - Recommendation: Use `@doc false` like the existing `check_git_dirty/1`, `detect_versions/1`, `build_plan/3`, etc. in the same file. These are all "public for testability, not for users" — the module already has this convention.

3. **Should Bug A's fix also set `Logger.configure(level: :warning)` in the `mix run -e` script as belt-and-suspenders?**
   - What we know: Sentinel regex alone is sufficient for correctness.
   - What's unclear: Whether test output noise matters for diagnosis.
   - Recommendation: No — stay minimal. If future diagnostic needs arise, add it then.

4. **What happens if `mix sigra.upgrade` is run twice in quick succession against the same host app?**
   - What we know: Current bug allows it to collide with install. After fix, first upgrade emits files at `base + [0..N-1]`; second upgrade scans, sees those files, and stamps past them.
   - What's unclear: Whether the second upgrade should be a no-op (Phase 18 D-08 may have idempotency semantics) or re-emit with new prefixes.
   - Recommendation: Out of scope for Phase 25. The existing `migrations_to_emit/1` logic gates on `organizations_table_present?/0` which is a disk scan, so re-runs already bypass re-emission in the BLOCKER-1 no-orgs path. The org-enabled path may re-emit, which matches current behavior; do not change it in this phase.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (local) | Integration tests (`test/upgrade_test.exs`) | ✓ (per CLAUDE.md prereq docs) | 15+ | — |
| `mix` (Elixir/OTP) | All of it | ✓ | Elixir ~> 1.18, OTP ~> 27 | — |
| `git` CLI | `Sigra.Upgrade.check_git_dirty/1` + existing unit tests | ✓ | any recent | — |
| `curl` CLI | `assert_login_redirects_to_organizations!/1` (existing, not touched by this phase) | ✓ (macOS + Linux stdlib) | any | — |
| `postgres:15` Docker service | CI `library_tests` job | ✓ | 15 | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (stdlib, Elixir ~> 1.18) |
| Config file | `test/test_helper.exs` + per-module `use ExUnit.Case` |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/upgrade_test.exs` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| Bug B regression | Two timestamp calls with existing files produce strictly-monotonic prefixes | unit | `mix test test/sigra/upgrade_test.exs --only describe:"next_migration_timestamp/2"` | Wave 0 needed (new describe block) |
| Bug A fix + SC #2 | `organizations_table_exists?/1` returns true after a default install | integration | `mix test test/upgrade_test.exs:95` (org-enabled test) | ✅ (lives in already-quarantined describe) |
| Zero-org path — SC #2 | `mix sigra.upgrade` on `--no-organizations` install emits zero ALTERs, no collisions | integration | `mix test test/upgrade_test.exs:45` | ✅ |
| Default-org path — SC #2 | Upgrade + login redirects to `/organizations`, no 5xx | integration | `mix test test/upgrade_test.exs:96` | ✅ |
| Backfill path — SC #2 | Backfill assigns personal orgs, re-run is no-op | integration | `mix test test/upgrade_test.exs:136` | ✅ |
| SC #5 | Full `mix test` on test/upgrade_test.exs has 0 failures, 0 skipped | integration (suite-level) | `mix test test/upgrade_test.exs` | ✅ |
| SC #6 | Full `mix test` stays green | suite | `mix test` | ✅ |

### Sampling Rate
- **Per task commit:** `mix test test/sigra/upgrade_test.exs` (fast — no tmp app spawning)
- **Per wave merge:** `mix test test/upgrade_test.exs test/sigra/upgrade_test.exs` (integration + unit)
- **Phase gate:** Full `mix test` green locally AND full CI `library_tests` job green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Add new `describe "next_migration_timestamp/2 (Phase 25 Bug B regression)"` block to `test/sigra/upgrade_test.exs` — must include a test that seeds `priv/repo/migrations/20260415120000_fake.exs` and asserts that a call with `now = ~U[2026-04-15 12:00:00Z]` produces `"20260415120001"` (strictly greater than the highest existing prefix).
- [ ] No framework install needed — ExUnit is stdlib.
- [ ] No shared fixtures needed — existing `setup` block in `test/sigra/upgrade_test.exs` already provides a tmp cwd (`lib/sigra/upgrade_test.exs:7-19`).

## Security Domain

Not applicable. This phase fixes a test-infrastructure bug and a migration-naming collision. No authentication, session, token, password, or input-validation code is touched. No ASVS categories apply.

`security_enforcement` check: this phase adds no new code paths that handle user input, secrets, or cryptography. The `organizations_table_exists?/1` helper runs a hardcoded `SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations'` — no user-supplied SQL. The `next_migration_timestamp/2` helper reads filenames from a local directory and does `Regex.run` on them — no network, no user input, no crypto.

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.13 — fixes must compile under `mix compile --warnings-as-errors` on this combo.
- **Database:** PostgreSQL primary (local postgres is a documented dev prereq). CI `library_tests` job runs against `postgres:15`.
- **Dependencies:** Minimal transitive deps — **this phase adds zero new deps**. Both fixes are stdlib-only.
- **Testing:** AAA style, flat, self-contained, happy path + main error cases + boundary conditions. The new unit regression test for Bug B should cover: (a) no existing files → stamps at `now`, (b) existing files with prefixes older than `now` → stamps at `now`, (c) existing files with prefixes newer than `now` → stamps at `max + 1s`, (d) existing file at exactly `now` → stamps at `now + 1s`, (e) month-boundary rollover (`20260430235959 + 1s → 20260501000000`).
- **GSD workflow enforcement:** All edits must flow through `/gsd-execute-phase` or `/gsd-quick`. Direct edits prohibited.
- **No macro-heavy injection, no Application.get_env for config:** Both irrelevant to this phase — the fixes are pure functions on pure data.

## Sources

### Primary (HIGH confidence)
- `lib/sigra/upgrade.ex:267-295` (`emit_migrations/1`, `write_migration/2`) — VERIFIED the exact collision site
- `lib/sigra/install/migration_timestamps.ex` — VERIFIED the precedent allocator pattern
- `lib/sigra/install/runner.ex:45-56` — VERIFIED that install uses `DateTime.utc_now()` as base_time with counter-based allocation
- `lib/sigra/install/features/core.ex:85-100` — VERIFIED 4 core slots
- `lib/sigra/install/features/organizations.ex:166-174` — VERIFIED 2 org slots
- `test/upgrade_test.exs:200-251` — VERIFIED both `count_personal_orgs!/1` and `organizations_table_exists?/1` share the broken pattern
- `test/upgrade_test.exs:39-41` — VERIFIED the `@moduletag skip:` block that must be removed in Plan 25-02
- `test/sigra/upgrade_test.exs:1-170` — VERIFIED the unit test file structure and existing tmp-cwd setup pattern
- `test/upgrade_test.exs:372-383` — VERIFIED the existing `parse_http_status/1` regex pattern (precedent for Bug A fix shape)
- `.planning/ROADMAP.md:357-381` — VERIFIED Phase 25 goal, context, requirements, and success criteria

### Secondary (MEDIUM confidence)
- PR #9 (`63ea853`, 2026-04-15) — CITED via prompt additional_context: module rename, `--no-mailer` removal, `--allow-dirty` injection, `ecto.drop --force` addition. Not independently inspected in this session.

### Tertiary (LOW confidence)
- Ecto's exact error message format (`"migration version NNNN is duplicated"`) — ASSUMED from training data + the test/upgrade_test.exs:32 comment that paraphrases it. Not verified against current Ecto source. Impact low: the fix eliminates the error regardless of exact wording.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — stdlib only, no version-dependent behavior
- Architecture: HIGH — fix mirrors existing in-codebase precedent (`Sigra.Install.MigrationTimestamps`)
- Pitfalls: HIGH — diagnosed by reading the broken code, not inferring from training data
- Bug A diagnosis: HIGH — confirmed by grep of both broken helpers, regex-extraction precedent already exists in the same file
- Bug B diagnosis: HIGH — confirmed by reading `write_migration/2` and the install-side allocator that consumes the same timestamp space
- Plan split recommendation: MEDIUM — 2-plan split is recommended but planner discretion applies; 1-plan is also defensible

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (30 days; stable stdlib surface, no fast-moving deps)
