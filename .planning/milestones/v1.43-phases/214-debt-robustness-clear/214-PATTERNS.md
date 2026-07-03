# Phase 214: Debt & Robustness Clear — Pattern Map

**Mapped:** 2026-07-02
**Files analyzed:** 9 code-bearing files
**Analogs found:** 9 / 9

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/optional_deps.ex` | utility | request-response | itself (`oban_available?/0` at line 79) | exact |
| `lib/sigra/account/deletion.ex` | service | event-driven (Oban) | `lib/sigra/delivery.ex` lines 110-115 | exact |
| `lib/sigra/delivery.ex` | service | event-driven (Oban) | `lib/sigra/optional_deps.ex` (new SOT) | exact |
| `lib/sigra/audit/forwarders.ex` | service | event-driven (Oban) | `lib/sigra/optional_deps.ex` (new SOT) | exact |
| `lib/sigra/auth.ex` | service | request-response | `lib/sigra/session_stores/ecto.ex` lines 64-72 | role-match |
| `lib/sigra/admin/components.ex` | component | request-response | `lib/sigra/admin/live/user_sessions_live.ex` lines 212-238 | role-match |
| `config/test.exs` | config | — | existing stanzas in same file | exact |
| `test/test_helper.exs` | config | — | itself (existing `Code.ensure_loaded?` guard at line 8) | exact |
| `test/example/priv/static/assets/css/app.css` | utility | — | itself (clean `--vt-*` blocks) | exact |

---

## Pattern Assignments

### `lib/sigra/optional_deps.ex` — add `oban_running?/0` (DEBT-01 D-02)

**Action:** Add new public function directly below the existing `oban_available?/0` at line 79.

**Analog — existing sibling at lines 77-79:**
```elixir
@doc since: "0.1.0"
@spec oban_available?() :: boolean()
def oban_available?, do: Code.ensure_loaded?(Oban)
```

**New function to insert at line 80 (after `oban_available?/0`):**
```elixir
@doc """
Returns `true` when Oban is both available as a loaded module AND actively
supervised in the host application.

Use this guard — not `oban_available?/0` — before attempting to insert Oban
jobs. A host that compiles `{:oban, ...}` without wiring the supervisor will
have `oban_available?/0 == true` but `Process.whereis(Oban) == nil`; inserting
a job in that state causes a table-not-found crash at the store level.
"""
@doc since: "1.1.0"
@spec oban_running?() :: boolean()
def oban_running?, do: oban_available?() and Process.whereis(Oban) != nil
```

**Pattern source:** `lib/sigra/delivery.ex` lines 110-115 (the private `oban_running?/0` that becomes the SOT):
```elixir
# :auto must only route to :async when Oban is actually supervised in the
# host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
# mix.exs without wiring the supervisor would otherwise crash on insert.
defp oban_running? do
  Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
end
```

---

### `lib/sigra/account/deletion.ex` — fix bare guard (DEBT-01 D-01)

**Action:** Replace `oban_available?()` with `oban_running?()` at line 308.

**Buggy site (lines 307-330):**
```elixir
defp maybe_enqueue_deletion_job(repo, user, scheduled_at, opts) do
  with true <- Sigra.OptionalDeps.oban_available?(),   # <-- BUG: only checks compiled, not supervised
       true <- Code.ensure_loaded?(Sigra.Workers.AccountDeletion),
       {:ok, args} <- deletion_job_args(repo, user, opts),
       {:ok, changeset} <- build_deletion_job_changeset(args, scheduled_at),
       {:ok, _job} <- repo.insert(changeset) do
    :ok
  else
    false -> :ok
    {:error, :missing_job_context} -> :ok
    {:error, reason} ->
      Logger.warning("Sigra account deletion job was not enqueued: #{inspect(reason)}")
      :ok
  end
rescue
  error ->
    Logger.warning("Sigra account deletion job enqueue crashed: #{Exception.message(error)}")
    :ok
end
```

**Fix — change line 308 only:**
```elixir
  with true <- Sigra.OptionalDeps.oban_running?(),   # was oban_available?()
```

The `rescue` block and all else-branches are preserved as-is; they remain valid safety nets.

---

### `lib/sigra/delivery.ex` — replace private copy with SOT call (DEBT-01 D-02)

**Action:** Delete the private `oban_running?/0` (lines 110-115) and replace the call site with `Sigra.OptionalDeps.oban_running?()`.

**Current call site (line 105):**
```elixir
:auto -> if oban_running?(), do: :async, else: :sync
```

**Updated call site:**
```elixir
:auto -> if Sigra.OptionalDeps.oban_running?(), do: :async, else: :sync
```

**Delete lines 110-115** (private `oban_running?/0` — now duplicated by the SOT).

---

### `lib/sigra/audit/forwarders.ex` — wrap SOT call (DEBT-01 D-02)

**Action:** Update the `:error` branch of `oban_running?/1` (line 99) to delegate to the SOT instead of re-implementing the check.

**Current implementation (lines 89-101):**
```elixir
@spec oban_running?(keyword()) :: boolean()
def oban_running?(opts) do
  case Keyword.fetch(opts, :oban) do
    {:ok, oban_override} ->
      # Test override: skip Code.ensure_loaded? (override is a named process, not a module)
      Process.whereis(oban_override) != nil

    :error ->
      # Production path: mirrors lib/sigra/delivery.ex oban_running?/0:
      # Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
      Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
  end
end
```

**Updated `:error` branch only (line 99):**
```elixir
    :error ->
      # Production path: delegate to SOT (Sigra.OptionalDeps.oban_running?/0)
      Sigra.OptionalDeps.oban_running?()
```

The opts-override path for test injection (`{:ok, oban_override}` branch) is preserved unchanged — it serves a distinct purpose (mock process injection in tests) not covered by the no-args SOT.

---

### `lib/sigra/auth.ex` — add user_id guard to `delete_session/3` (DEBT-03 D-08)

**Action:** Insert a user_id ownership check between resolving the session store and calling `session_store.delete/2`. The guard fetches the session first; if `user_id` in opts does not match `session.user_id`, it no-ops without deleting.

**Current `delete_session/3` (lines 1495-1526):**
```elixir
@spec delete_session(Sigra.Config.t(), binary(), keyword()) :: :ok
def delete_session(config, hashed_token, opts \\ []) do
  {session_store, store_opts} = session_store_and_opts(config, opts)

  result =
    Telemetry.span([:sigra, :session, :delete], %{}, fn ->
      session_store.delete(hashed_token, store_opts)
    end)

  # D-26: session.delete audit row (standalone, D-28).
  user_id = Keyword.get(opts, :user_id)
  actor_id = Keyword.get(opts, :actor_id, user_id)
  ...
  result
end
```

**Guard pattern to insert** (before the `Telemetry.span` block):
```elixir
# D-08: If user_id is provided in opts, verify session ownership before delete.
# Callers that omit user_id (e.g. self-logout by cookie token) are unaffected.
user_id_constraint = Keyword.get(opts, :user_id)

result =
  Telemetry.span([:sigra, :session, :delete], %{}, fn ->
    case user_id_constraint do
      nil ->
        session_store.delete(hashed_token, store_opts)

      uid ->
        case session_store.fetch(hashed_token, store_opts) do
          {:ok, %{user_id: ^uid}} -> session_store.delete(hashed_token, store_opts)
          {:ok, _foreign} -> :ok   # user_id mismatch — no-op (foreign token protection)
          {:error, :not_found} -> :ok  # already gone
        end
    end
  end)
```

**Analog — `SessionStores.Ecto.delete/2` (lines 64-72)** shows the store's `get_by` pattern; the guard above uses `session_store.fetch/2` (a peer callback) to stay store-agnostic:
```elixir
@impl true
def delete(hashed_token, opts) do
  repo = Keyword.fetch!(opts, :repo)
  schema = Keyword.fetch!(opts, :session_schema)

  case repo.get_by(schema, hashed_token: hashed_token) do
    nil -> :ok
    record -> repo.delete!(record) && :ok
  end
end
```

**Audit log** (`Sigra.Audit.log_safe`) continues to read `user_id` from opts as before — no change needed there. The planner should log a `no-op` reason only if adding audit detail is desired; by default, the mismatch is silent (defense in depth, not a noisy warning).

---

### `lib/sigra/admin/components.ex` — promote session render helpers (DEBT-03 D-11)

**Action:** Add the five session helper functions as public functions to `Sigra.Admin.Components`. Both `UserSessionsLive` and `UserShowLive` already `import Sigra.Admin.Components` at line 6; after promotion the private copies are deleted from both LiveViews.

**Source — byte-identical implementations from `user_sessions_live.ex` (lines 212-238):**
```elixir
defp scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
  do: "Organization-scoped user operations for #{name}"

defp scope_copy(_admin_scope), do: "Global user operations"

defp session_type(%{type: type}), do: to_string(type)

defp activity_value(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M")

defp activity_value(_), do: "Not available"

# Coarse human-readable recency cue beside the absolute timestamp.
defp relative_activity(%DateTime{} = at) do
  diff = DateTime.diff(DateTime.utc_now(), at, :second)

  cond do
    diff < 60 -> "just now"
    diff < 3600 -> "#{div(diff, 60)}m ago"
    diff < 86_400 -> "#{div(diff, 3600)}h ago"
    true -> "#{div(diff, 86_400)}d ago"
  end
end

defp relative_activity(_), do: nil

defp pluralize(1, label), do: "1 #{label}"
defp pluralize(count, label), do: "#{count} #{label}s"
```

**Target module header pattern** (from `lib/sigra/admin/components.ex` lines 1-10):
```elixir
defmodule Sigra.Admin.Components do
  @moduledoc "..."
  use Phoenix.Component
  ...
```

**Promoted to `Sigra.Admin.Components` as `def` (not `defp`) — add `@doc false` for internal helpers:**
```elixir
@doc false
def scope_copy(%Scope{mode: :organization, organization: %{name: name}}),
  do: "Organization-scoped user operations for #{name}"

@doc false
def scope_copy(_admin_scope), do: "Global user operations"

@doc false
def session_type(%{type: type}), do: to_string(type)

@doc false
def activity_value(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M")

@doc false
def activity_value(_), do: "Not available"

@doc false
def relative_activity(%DateTime{} = at) do
  diff = DateTime.diff(DateTime.utc_now(), at, :second)
  cond do
    diff < 60 -> "just now"
    diff < 3600 -> "#{div(diff, 60)}m ago"
    diff < 86_400 -> "#{div(diff, 3600)}h ago"
    true -> "#{div(diff, 86_400)}d ago"
  end
end

@doc false
def relative_activity(_), do: nil

@doc false
def pluralize(1, label), do: "1 #{label}"
def pluralize(count, label), do: "#{count} #{label}s"
```

Both LiveViews' `import Sigra.Admin.Components` at line 6 already imports these, so no import change is needed. Remove `defp` copies from both files.

**Note for D-10 (`@return_to` cleanup):** In `user_sessions_live.ex`, `assign(:return_to, nil)` in `mount/3` can be dropped. The `return_to` value is already a local variable in `handle_params` (`return_to = sanitize_return_to(...)`) and only used to compute `@admin_breadcrumbs`. Remove the `assign(:return_to, ...)` call in mount and the `assign(socket, :return_to, nil)` initialization — `handle_params` always runs before render and breadcrumbs are stored in `@admin_breadcrumbs`.

---

### `config/test.exs` — suppress Chimeway.Repo startup noise (HEALTH-03 D-18)

**Action:** Add Chimeway.Repo config so it starts cleanly. No Sigra test uses Chimeway.Repo; this config merely satisfies the Repo's startup check.

**Existing pattern in `config/test.exs`** (full file, 12 lines):
```elixir
import Config

# Speed up Argon2 hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8

config :sigra, Sigra.Mailer, adapter: Swoosh.Adapters.Test
```

**Append at end of `config/test.exs`:**
```elixir
# Chimeway.Application unconditionally supervises Chimeway.Repo at boot.
# No Sigra test exercises Chimeway.Repo, but it needs valid config to start
# without connection errors (startup noise). Point it at the same test DB.
config :chimeway, Chimeway.Repo,
  hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("SIGRA_TEST_PG_PORT", "5432")),
  username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
  password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
  database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
  pool: Ecto.Adapters.SQL.Sandbox
```

**Analog — CLAUDE.md env var convention** (`SIGRA_TEST_PG_*` names) and `test/sigra/test/postgres_repo.ex` which uses the same env var names.

---

### `test/test_helper.exs` — upgrade test preflight skip (HEALTH-03 D-19)

**Action:** Add a conditional `ExUnit.configure(exclude: [:upgrade])` BEFORE `ExUnit.start()`, activated when the phx_new 1.8.8 archive is absent locally.

**Current `test/test_helper.exs` (lines 1-6):**
```elixir
# `mix test` here requires a live Postgres at localhost:5432 with
# postgres/postgres — this matches the CI `library_tests` job's postgres
# service. No default tag exclusions: every test that runs in CI also runs
# locally, so there's no "silently skipped" blind spot. See CLAUDE.md for
# the dev prereq docker one-liner.
ExUnit.start()
```

**Pattern to insert before `ExUnit.start()`:**
```elixir
# Graceful preflight skip for UpgradeIntegrationTest (D-19).
# The upgrade test shells out to `mix phx.new` — requires phx_new 1.8.8 archive.
# CI installs the archive; local dev without the archive gets a clean skip, not a crash.
# NOT a blanket :postgres exclusion — CLAUDE.md forbids that pattern.
phx_new_ok? =
  case System.cmd("mix", ["archive.list"], stderr_to_stdout: true) do
    {output, 0} -> String.contains?(output, "phx_new-1.8.8")
    _ -> false
  end

unless phx_new_ok? do
  ExUnit.configure(exclude: [:upgrade])
end
```

`ExUnit.configure(exclude: [...])` before `ExUnit.start()` is the correct ExUnit API for conditional module-level skip. It is NOT a blanket `:postgres` exclusion — it is specific to `:upgrade`-tagged tests that require the phx_new archive.

---

### `test/example/priv/static/assets/css/app.css` — orphan cleanup (DEBT-05 D-15)

**Action:** Delete the orphaned value fragments at the confirmed line ranges. Do NOT touch any `var(--sg-*)` references inside selector rules (lines 175+) — those are legitimate demo-app token references.

**Ranges to delete (RESEARCH.md lines 354-394, confirmed):**
- Lines 28-33: Three orphaned `--sg-elev-*` box-shadow value fragments (bare multi-line CSS values with no property name)
- Lines 39-43: Two orphaned `--sg-transition-*` value fragments
- Line 46: One orphaned `--sg-focus-ring` value fragment
- Lines 88-91 (dark-mode `:root`): Orphaned comment tails (`* …  */`) from removed `--sg-*` dark-mode declarations

Also remove the now-empty comment headers that frame these orphans (e.g. `/* Elevation ladder. ... */`, `/* Motion. ... */`, `/* Focus */`).

**Integrity check:** After cleanup, confirm the `--vt-*` token declarations (light + dark, fully paired) remain untouched. A browser `getComputedStyle` / `document.styleSheets[].cssRules` check is required to verify the CSS parser accepts the result — a clean-looking file does not prove parser acceptance (D-15/D-17 note).

**No analog needed** — this is a targeted deletion; the "correct" pattern is the existing clean `--vt-*` block in the same file.

---

## Shared Patterns

### Oban Guard Hierarchy

**Source:** `lib/sigra/optional_deps.ex` (new `oban_running?/0`) and `lib/sigra/delivery.ex` lines 110-115 (template)

**Rule:** Every site that inserts an Oban job must gate on `Sigra.OptionalDeps.oban_running?()`, not `oban_available?()`. The distinction: `oban_available?/0` checks compile-time presence; `oban_running?/0` checks runtime supervision.

**Apply to:** `deletion.ex`, `delivery.ex`, `forwarders.ex` (all three Oban enqueue sites)

```elixir
# Correct gate — use this everywhere:
Sigra.OptionalDeps.oban_running?()

# Incorrect gate — do NOT use for enqueue decisions:
Sigra.OptionalDeps.oban_available?()
```

### ExUnit Conditional Exclusion

**Source:** `test/test_helper.exs` (D-19 pattern)

**Rule:** Heavy-prerequisite tests use `ExUnit.configure(exclude: [:tag])` BEFORE `ExUnit.start()`, not blanket `:postgres` exclusions and not `setup_all` returning `:skip` (wrong API).

```elixir
# Correct pattern:
unless prereq_ok? do
  ExUnit.configure(exclude: [:upgrade])
end
ExUnit.start()
```

### Public vs Private in `Sigra.Admin.Components`

**Source:** Existing components in `lib/sigra/admin/components.ex` (all `def`, none `defp`)

**Rule:** All functions in `Sigra.Admin.Components` are `def` (public), tagged `@doc false` when they are internal/non-HEEx helpers. This allows `import Sigra.Admin.Components` in LiveViews to reach them without qualification.

---

## No Analog Found

All files in this phase have clear analogs. The table below records items with no close codebase match that required pattern inference from RESEARCH.md:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `scripts/ci/app-css-corruption-check.sh` (new, D-17) | utility/lint | — | No comparable CSS integrity guard script exists; planner to author from scratch using `awk` or `grep` |

---

## Metadata

**Analog search scope:** `lib/sigra/`, `test/`, `config/`, `test/example/priv/`
**Files scanned:** 11 (plus test_helper.exs and config/test.exs)
**Pattern extraction date:** 2026-07-02
