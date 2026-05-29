# Phase 138: mix sigra.doctor Operator Diagnostic - Pattern Map

**Mapped:** 2026-05-29
**Files analyzed:** 3 (task shell, library logic, test file)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/sigra.doctor.ex` | mix-task | request-response | `lib/mix/tasks/sigra.upgrade.ex` | exact |
| `lib/sigra/doctor.ex` | library-logic | transform (map inputs → structured result) | `lib/sigra/upgrade.ex` | role-match |
| `test/sigra/doctor_test.exs` | test | — | `test/sigra/upgrade_test.exs` + `test/sigra/install/purely_additive_test.exs` | role-match |

---

## Pattern Assignments

### `lib/mix/tasks/sigra.doctor.ex` (mix-task, request-response)

**Analog:** `lib/mix/tasks/sigra.upgrade.ex`

**Module header + use Mix.Task + @shortdoc/@moduledoc** (sigra.upgrade.ex lines 1-50):
```elixir
defmodule Mix.Tasks.Sigra.Doctor do
  @shortdoc "Diagnoses optional-dependency wiring and prints a per-feature status matrix"

  @moduledoc """
  ...
  Delegates to `Sigra.Doctor.run/1` after parsing flags.
  All diagnostic logic (matrix build, wiring checks, verdict) lives in the
  versioned library so fixes ship via `mix deps.update`.
  """

  use Mix.Task
```

**NimbleOptions schema + @switches** (sigra.upgrade.ex lines 52-87):
```elixir
  @options_schema [
    quiet: [
      type: :boolean,
      default: false,
      doc: "Suppress per-row hints; print only the summary verdict."
    ]
  ]

  @switches [quiet: :boolean]
```

**run/1 body: parse flags → validate → delegate** (sigra.upgrade.ex lines 88-93):
```elixir
  @impl Mix.Task
  def run(args) do
    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    validated = NimbleOptions.validate!(opts, @options_schema)
    Mix.Task.run("app.start")   # D-02: live OptionalDeps checks + config reads require booted app
    Sigra.Doctor.run(validated)
  end
```

Note: `sigra.fixture.rebless_golden.ex` lines 51-52 shows the existing precedent for
task-level `Mix.Task.run` calls before work begins:
```elixir
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")
```
Doctor uses `"app.start"` instead of `"compile"` because `OptionalDeps` predicates are live
un-memoized `Code.ensure_loaded?` calls and config reads require the booted app env (D-02).

**ANSI IO-data output style** (sigra.gen.oauth.ex lines 157, 333):
```elixir
    Mix.shell().info([:green, "* injecting ", :reset, path])
    Mix.shell().info([:yellow, "* skipping ", :reset, target_path, " (already exists)"])
```
Doctor should follow this exact `[color_atom, "text", :reset, ...]` IO-list form for
`Mix.shell().info/1` — auto-degrades to plain text in non-TTY/CI (D-01). Use
`Mix.shell().error/1` for the misconfiguration report (D-10).

**exit({:shutdown, n}) for CI-gate fail** (sigra.fixture.rebless_golden.ex lines 131-143):
```elixir
    cond do
      tree_diff == "" and stdout_equal? ->
        Mix.shell().info("OK: fixture is up-to-date (check mode).")
        :ok

      true ->
        Mix.shell().error("DRIFT DETECTED:")
        if tree_diff != "", do: Mix.shell().error(tree_diff)

        unless stdout_equal?,
          do: Mix.shell().error("  STDOUT.txt differs from regenerated output")

        exit({:shutdown, 2})
    end
```
Doctor's pattern (D-10): call `Mix.shell().error/1` with the full report first, then
`exit({:shutdown, 1})`. Never `System.halt/1` (kills VM, breaks CaptureIO). Never `Mix.raise/1`
for app misconfiguration — `Mix.raise` is only for usage/flag errors (sigra.install.ex lines
81, 94; sigra.gen.oauth.ex line 185).

---

### `lib/sigra/doctor.ex` (library logic, transform)

**Analog:** `lib/sigra/upgrade.ex` (structured result pattern) + `lib/sigra/optional_deps.ex`
(primary data source)

**Module shape — public entrypoint returns structured result** (sigra.upgrade.ex lines 62-71):
```elixir
  @spec run(opts()) :: :ok | {:halt, term()}
  def run(opts) do
    with :ok <- check_git_dirty(opts),
         {:ok, source, target} <- detect_versions(opts),
         ...
```
Doctor's analog: a single `run/1` (or `diagnose/1`) that accepts injected inputs and returns
`{:ok, result}` or `{:error, result}` carrying the per-feature row list, wiring-check list, and
overall `:ok | :fail` verdict. The Mix.Task calls this and formats/exits.

**Primary data source — OptionalDeps predicates** (lib/sigra/optional_deps.ex lines 78-170):

All nine availability predicates (verbatim signatures):
```elixir
  @spec oban_available?() :: boolean()
  def oban_available?, do: Code.ensure_loaded?(Oban)

  @spec bcrypt_available?() :: boolean()
  def bcrypt_available?, do: Code.ensure_loaded?(Bcrypt)

  @spec eqrcode_available?() :: boolean()
  def eqrcode_available?, do: Code.ensure_loaded?(EQRCode)

  @spec threadline_available?() :: boolean()
  def threadline_available?, do: Code.ensure_loaded?(Threadline)

  @spec assent_available?() :: boolean()
  def assent_available?, do: Code.ensure_loaded?(Assent)

  @spec swoosh_available?() :: boolean()
  def swoosh_available?, do: Code.ensure_loaded?(Swoosh)

  @spec joken_available?() :: boolean()
  def joken_available?, do: Code.ensure_loaded?(Joken)

  @spec hammer_available?() :: boolean()
  def hammer_available?, do: Code.ensure_loaded?(Hammer)

  @spec req_available?() :: boolean()
  def req_available?, do: Code.ensure_loaded?(Req)
```

Encryption posture predicate (non-raising, config-driven, lines 197-207):
```elixir
  @spec encryption_active?(keyword()) :: boolean()
  def encryption_active?(host_sigra) when is_list(host_sigra) do
    case encrypted_binary_module(host_sigra) do
      nil ->
        false

      module ->
        function_exported?(module, :__sigra_encryption_mode__, 0) and
          module.__sigra_encryption_mode__() != :stub
    end
  end
```
Doctor calls `Sigra.OptionalDeps.encryption_active?(host_sigra)` — NOT
`Sigra.Application.verify_vault!/1` (raises, would abort before full matrix prints, D-08).

**Audit forwarder supervision predicate with test-override seam**
(lib/sigra/audit/forwarders.ex lines 89-101):
```elixir
  @spec oban_running?(keyword()) :: boolean()
  def oban_running?(opts) do
    case Keyword.fetch(opts, :oban) do
      {:ok, oban_override} ->
        # Test override: skip Code.ensure_loaded? (override is a named process, not a module)
        Process.whereis(oban_override) != nil

      :error ->
        # Production path
        Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
    end
  end
```
Doctor reuses `Sigra.Audit.Forwarders.oban_running?/1` verbatim for both:
  - audit-forwarder wiring check (D-08, D-09 hard-fail #1)
  - async-email wiring check (`delivery_mode == :async` but Oban not supervised, D-09 hard-fail #2)

The test-override atom seam (`opts[:oban]`) is what enables unit tests to exercise the
supervised/not-supervised distinction without running a real Oban process.

**Email delivery mode check** (lib/sigra/delivery.ex lines 103-115):
```elixir
  defp delivery_mode(opts) do
    case Keyword.get(opts, :delivery_mode, :auto) do
      :auto -> if oban_running?(), do: :async, else: :sync
      mode -> mode
    end
  end

  defp oban_running? do
    Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
  end
```
Doctor checks: if `host_sigra[:email][:delivery_mode] == :async` AND NOT
`Sigra.Audit.Forwarders.oban_running?([])` → hard-fail (D-09 #2).

**Boot-wiring patterns doctor MIRRORS read-only** (lib/sigra/application.ex):

Forwarder-dep warn (lines 93-120) — condition doctor mirrors:
```elixir
    Enum.each(forwarders, fn forwarder_opts ->
      module = Keyword.fetch!(forwarder_opts, :module)

      unless Code.ensure_loaded?(module) do
        Logger.warning("[Sigra.Audit] Forwarder #{inspect(module)} is configured but its module is not loaded.")
      end
    end)
```
Doctor's mirror: check each configured forwarder's module via `Code.ensure_loaded?(module)` →
D-09 hard-fail #4 if any configured forwarder module is not loaded.

Async-forwarder raise condition (lines 135-152) — condition doctor mirrors WITHOUT raising:
```elixir
      if dispatch == :async and not Sigra.Audit.Forwarders.oban_running?(forwarder_opts) do
        raise ArgumentError, "[Sigra.Audit] Forwarder ... configured with dispatch: :async but Oban is not supervised"
```
Doctor's mirror: same condition check → D-09 hard-fail #1, but report via `Mix.shell().error/1`
+ `exit({:shutdown, 1})` instead of raising.

verify_vault! raise condition (lines 185-210) — condition doctor mirrors via `encryption_active?/1`:
```elixir
        if function_exported?(module, :__sigra_encryption_mode__, 0) and
             module.__sigra_encryption_mode__() == :stub do
          raise "..."
        end
```
Doctor's mirror: `Sigra.OptionalDeps.encryption_active?(host_sigra)` — returns `false` when
stub is active → D-09 hard-fail #3 if passkeys (or other encryption-requiring feature) is
configured but `encryption_active?` returns false.

**Two-hop config read pattern** (lib/sigra/application.ex lines 34-37, repeated at 94-103,
124-133, 173-180):
```elixir
    otp_app = Application.get_env(:sigra, :otp_app)

    host_sigra =
      case otp_app && Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) -> opts
        _ -> []
      end
```
Doctor uses this exact two-hop pattern to read host config when building the matrix in the
non-injected (production) call path. The injected-input path (for tests, D-04) bypasses this
and accepts `host_sigra` directly as a parameter.

**Config feature accessors** (lib/sigra/config.ex lines 937-941, 1036-1038):
```elixir
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    struct!(__MODULE__, validated)
  end

  @spec oauth_enabled?(t()) :: boolean()
  def oauth_enabled?(%__MODULE__{oauth: oauth}) do
    Keyword.get(oauth, :enabled, true) and Keyword.get(oauth, :providers, []) != []
  end
```
Doctor reads configuration state via direct keyword access on the raw `host_sigra` list
(pre-`new!/1` — not all hosts have `Sigra.Config.new!` available at doctor invocation time).
Feature-enabled checks mirror the same `Keyword.get(sub_key, :enabled, true)` pattern.

---

## Feature → Predicate Matrix (for planner)

| Feature row | Availability predicate(s) | Configured-check (host_sigra key) | Hard-fail condition (D-09) |
|-------------|---------------------------|-----------------------------------|---------------------------|
| TOTP/MFA | `eqrcode_available?/0` | `mfa[:enabled]` (default true) | no hard-fail on dep-absent |
| Password migration | `bcrypt_available?/0` | presence of bcrypt hash prefix in db; no explicit config flag | no hard-fail |
| OAuth | `assent_available?/0` | `oauth[:providers]` non-empty | no hard-fail (dep-absent, D-09) |
| Rate limiting | `hammer_available?/0` | `rate_limiting[:limiter]` set | no hard-fail |
| JWT | `joken_available?/0` | `jwt[:enabled]` | no hard-fail |
| Async email | `swoosh_available?/0` + `oban_available?/0` | `email[:delivery_mode] == :async` | HARD-FAIL: `:async` but Oban not supervised |
| Audit forwarding | `threadline_available?/0` + `oban_available?/0` | `audit[:forwarders]` non-empty | HARD-FAIL: `:async` dispatch but Oban not supervised; HARD-FAIL: forwarder module not loaded |
| Encryption | `encryption_active?/1` (config-driven) | passkeys/OAuth token storage enabled | HARD-FAIL: feature enabled but `encryption_active?` returns false |
| Enterprise connections | `req_available?/0` | `enterprise_connections` configured | no hard-fail |

---

## Shared Patterns

### Two-hop config read
**Source:** `lib/sigra/application.ex` lines 34-37 (also 94-103, 124-133, 173-180)
**Apply to:** `Sigra.Doctor.run/1` production (non-injected) path
```elixir
    otp_app = Application.get_env(:sigra, :otp_app)

    host_sigra =
      case otp_app && Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) -> opts
        _ -> []
      end
```

### Oban supervision check
**Source:** `lib/sigra/audit/forwarders.ex` lines 89-101
**Apply to:** async-email wiring check AND audit-forwarder wiring check in `Sigra.Doctor`
```elixir
  @spec oban_running?(keyword()) :: boolean()
  def oban_running?(opts) do
    case Keyword.fetch(opts, :oban) do
      {:ok, oban_override} -> Process.whereis(oban_override) != nil
      :error -> Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil
    end
  end
```

### Clean CI-gate exit (print full report, then non-zero exit)
**Source:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex` lines 136-143
**Apply to:** `Mix.Tasks.Sigra.Doctor.run/1` when verdict is `:fail`
```elixir
        Mix.shell().error("DRIFT DETECTED:")
        if tree_diff != "", do: Mix.shell().error(tree_diff)
        exit({:shutdown, 2})
```
Doctor uses exit code 1 (not 2). Error output precedes the `exit/1` call.

### ANSI IO-data form
**Source:** `lib/mix/tasks/sigra.gen.oauth.ex` lines 157, 333
**Apply to:** all `Mix.shell().info/1` calls in `Mix.Tasks.Sigra.Doctor`
```elixir
    Mix.shell().info([:green, "* loaded   ", :reset, "feature name"])
    Mix.shell().info([:yellow, "* available", :reset, "feature name (not configured)"])
    Mix.shell().info([:red,    "* MISSING  ", :reset, "feature name (configured but dep absent)"])
```

### Mix.Task.run before doing work
**Source:** `lib/mix/tasks/sigra.fixture.rebless_golden.ex` lines 51-52
**Apply to:** `Mix.Tasks.Sigra.Doctor.run/1` — call `Mix.Task.run("app.start")` before
delegating to `Sigra.Doctor.run/1` so OptionalDeps live checks and config reads see a booted app.

---

## Shared Patterns (Test)

### Structured-return assertion against injected inputs
**Source:** `test/sigra/upgrade_test.exs` lines 182-196
**Apply to:** `Sigra.Doctor` unit tests (no subprocess, no CaptureIO)
```elixir
  describe "build_plan/3 regression coverage" do
    test "produces an injection with config :sigra, :schema_version marker" do
      plan = Upgrade.build_plan([], "0.0.0", "0.1.0")
      assert [injection] = plan.injections
      assert injection.target == Path.join(["config", "config.exs"])
    end
  end
```
Doctor analog: `Sigra.Doctor.diagnose(host_sigra: [...], predicates: [...])` returns a
structured result; assert against `:rows`, `:wiring`, `:verdict` fields directly.

### CaptureIO for task-level smoke test
**Source:** `test/sigra/install/purely_additive_test.exs` lines 107-109
**Apply to:** `Mix.Tasks.Sigra.Doctor` task-level test
```elixir
      ExUnit.CaptureIO.capture_io(fn ->
        assert {:ok, _report} = Runner.run([FakeFeature], binding, [])
      end)
```
Doctor analog:
```elixir
      output = ExUnit.CaptureIO.capture_io(fn ->
        Mix.Tasks.Sigra.Doctor.run([])
      end)
      assert output =~ "missing"
```

### assert_raise for usage errors (Mix.Error / RuntimeError)
**Source:** `test/sigra/upgrade_test.exs` lines 130, 244-250
**Apply to:** Doctor task tests for bad flags
```elixir
      assert_raise Mix.Error, ~r/Refusing to run/, fn ->
        Upgrade.check_git_dirty([])
      end
```

### Inject stub modules for encryption-posture tests
**Source:** `test/sigra/upgrade_test.exs` lines 230-259
**Apply to:** `Sigra.Doctor` tests for the encryption hard-fail condition
```elixir
    defmodule VerifyVaultStub.Encrypted.Binary do
      def __sigra_encryption_mode__, do: :stub
    end

    defmodule VerifyVaultReal.Encrypted.Binary do
      def __sigra_encryption_mode__, do: :vault
    end

    test "raises when passkeys are enabled but the stub encryption module is loaded" do
      assert_raise RuntimeError, ~r/passkeys are enabled/, fn ->
        Sigra.Application.verify_vault!(user_schema: VerifyVaultStub.User, passkeys: [enabled: true])
      end
    end
```
Doctor analog: pass stub module atoms via the injection seam to test `encryption_active?`
returning false → verdict becomes `:fail` with `configured-but-missing` row state.

---

## No Analog Found

None. All three files have close analogs in the existing codebase.

---

## Metadata

**Analog search scope:** `lib/mix/tasks/`, `lib/sigra/`, `test/sigra/`
**Files scanned:** 8 source files read directly
**Pattern extraction date:** 2026-05-29
