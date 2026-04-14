---
phase: 18-backfill-organizations-generator-wiring
plan: 03
type: execute
wave: 2
depends_on: [01]
files_modified:
  - test/support/install_fixture.ex
  - test/upgrade_test.exs
  - .github/workflows/ci.yml
autonomous: true
requirements: [ORG-UPGRADE-02, ORG-UPGRADE-03, GEN-03]
tags: [testing, ci, matrix, integration]
must_haves:
  truths:
    - "test/upgrade_test.exs has a zero-org describe block that installs with --no-organizations, runs `mix sigra.upgrade --yes`, asserts zero ALTER migrations emitted, migrate succeeds, app boots"
    - "test/upgrade_test.exs has an org-enabled describe block that installs default, runs upgrade, performs HTTP login via curl against `mix phx.server`, asserts login returns 2xx/3xx, redirect terminates at `/organizations`, and no 5xx anywhere (ORG-UPGRADE-02 proof)"
    - "test/upgrade_test.exs also runs `mix sigra.upgrade --backfill-personal-orgs --yes` and asserts every user has a personal org (COUNT matches seeded user count) AND re-running the backfill command is a no-op"
    - "Sigra.Test.InstallFixture exposes run_sigra_install/2 and run_sigra_upgrade/2 helpers reusable by both the upgrade test and any future fixture-based test"
    - ".github/workflows/ci.yml has an install_matrix job with strategy.matrix.flags = [\"\", \"--no-organizations\"] that compiles, migrates, and tests a tmp app for each flag combination"
    - "The existing golden_diff_test continues to pass after InstallFixture is extended (byte-identity preservation)"
  artifacts:
    - path: "test/support/install_fixture.ex"
      provides: "run_sigra_install/2 + run_sigra_upgrade/2 reusable subprocess helpers"
      contains: "def run_sigra_upgrade"
    - path: "test/upgrade_test.exs"
      provides: "Two-path upgrade regression test (backfill-on and backfill-off)"
      contains: "backfill-on"
    - path: ".github/workflows/ci.yml"
      provides: "install_matrix CI job with extensible list-of-flags matrix shape"
      contains: "install_matrix"
  key_links:
    - from: "test/upgrade_test.exs"
      to: "Sigra.Test.InstallFixture.run_sigra_install/2"
      via: "module alias + function call"
      pattern: "InstallFixture\\.run_sigra_install"
    - from: ".github/workflows/ci.yml install_matrix"
      to: "mix sigra.install with matrix.flags"
      via: "shell interpolation ${{ matrix.flags }}"
      pattern: "matrix\\.flags"
---

<objective>
Extend `Sigra.Test.InstallFixture` with reusable `run_sigra_install/2` and `run_sigra_upgrade/2` subprocess helpers (additive — do NOT edit existing `setup_tmp_app/1` inline install block to preserve byte-identity with the golden diff test), create `test/upgrade_test.exs` that exercises BOTH upgrade paths (backfill-off → users land on zero-org page, backfill-on → every user gets a personal org + rerun is a no-op), and add a CI matrix job `install_matrix` that runs `mix sigra.install ${{ matrix.flags }}` for both `""` (default org-enabled) and `"--no-organizations"` with a list-of-flags matrix shape that Phase 19+ can extend.

Purpose: Closes ORG-UPGRADE-02 (backfill-off path regression lock), ORG-UPGRADE-03 (upgrade test fixture ship requirement), and GEN-03 (combinatorial CI smoke testing — org axis). Phase 18's three-plan close.

Output: Passing `test/upgrade_test.exs`, extended `InstallFixture` with two new public helpers, new `install_matrix` CI job in `.github/workflows/ci.yml`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-RESEARCH.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-01-foundation-schema-and-flag-PLAN.md
@.planning/phases/18-backfill-organizations-generator-wiring/18-02-upgrade-task-and-backfill-PLAN.md
@test/support/install_fixture.ex
@test/sigra/install/golden_diff_test.exs
@.github/workflows/ci.yml

<interfaces>
<!-- Extracted from existing files — use directly -->

Sigra.Test.InstallFixture.setup_tmp_app/1 (current public contract — PRESERVE):
```elixir
@spec setup_tmp_app(keyword()) :: {:ok, %{app_dir: String.t(), ...}}
def setup_tmp_app(opts \\ [])
# Runs mix phx.new + patches mix.exs to path-dep sigra + mix sigra.install with defaults + --yes
```

Existing install_smoke CI job skeleton (reference for new install_matrix job):
See .github/workflows/ci.yml lines ~104-149 (install_smoke job).
Key fields: services.postgres, steps.actions/checkout, erlef/setup-beam, phx_new archive install,
mix phx.new tmp_app, patch in path dep, mix sigra.install ... --yes.

Test module convention (from existing test/sigra/install/golden_diff_test.exs):
```elixir
use ExUnit.Case, async: false
@moduletag timeout: 300_000
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend Sigra.Test.InstallFixture with run_sigra_install/2 and run_sigra_upgrade/2 subprocess helpers</name>
  <files>test/support/install_fixture.ex</files>
  <read_first>
    - test/support/install_fixture.ex (full file — especially setup_tmp_app/1 lines 40–107)
    - test/sigra/install/golden_diff_test.exs (understand the golden-diff byte-identity contract)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md "Key Integration Nuances" #6 (byte-identity preservation rule)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for install_fixture.ex
  </read_first>
  <action>
Open `test/support/install_fixture.ex` and ADD two new public functions WITHOUT modifying the existing `setup_tmp_app/1` body. The existing inline `mix sigra.install` block inside `setup_tmp_app/1` must remain byte-for-byte identical so the golden_diff_test.exs keeps passing. DO NOT refactor `setup_tmp_app/1` to call the new helpers.

Add at an appropriate position in the module (after `setup_tmp_app/1`):

```elixir
@doc """
Runs `mix sigra.install` in an already-prepared tmp app with the given flags.

Used by upgrade_test.exs to install with non-default flags (e.g. `--no-organizations`)
in a tmp app that was set up with `setup_tmp_app(run_install: false)` or equivalent.

Returns `{:ok, stdout}` on success; raises with captured stdout on failure.
"""
@spec run_sigra_install(String.t(), [String.t()]) :: {:ok, String.t()}
def run_sigra_install(app_dir, flags) when is_list(flags) do
  args = ["sigra.install", "Accounts", "User", "users"] ++ flags ++ ["--yes"]

  {out, status} =
    System.cmd("mix", args,
      cd: app_dir,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0 do
    raise """
    mix sigra.install #{Enum.join(flags, " ")} failed in #{app_dir}:

    #{out}
    """
  end

  {:ok, out}
end

@doc """
Runs `mix sigra.upgrade` in a tmp app. Mirror of `run_sigra_install/2`.

Used by upgrade_test.exs to exercise the upgrade path after an initial
v1.0-shape install.

Returns `{:ok, stdout}` on success; raises with captured stdout on failure.
"""
@spec run_sigra_upgrade(String.t(), [String.t()]) :: {:ok, String.t()}
def run_sigra_upgrade(app_dir, flags) when is_list(flags) do
  args = ["sigra.upgrade"] ++ flags ++ ["--yes"]

  {out, status} =
    System.cmd("mix", args,
      cd: app_dir,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0 do
    raise """
    mix sigra.upgrade #{Enum.join(flags, " ")} failed in #{app_dir}:

    #{out}
    """
  end

  {:ok, out}
end

@doc """
Runs a raw `mix` command in a tmp app — escape hatch for seed helpers,
`mix ecto.migrate`, etc. from upgrade_test.exs.
"""
@spec run_mix(String.t(), [String.t()]) :: {:ok, String.t()}
def run_mix(app_dir, args) when is_list(args) do
  {out, status} =
    System.cmd("mix", args,
      cd: app_dir,
      stderr_to_stdout: true,
      env: [{"MIX_ENV", "dev"}]
    )

  if status != 0 do
    raise """
    mix #{Enum.join(args, " ")} failed in #{app_dir}:

    #{out}
    """
  end

  {:ok, out}
end
```

**WARNING 5 — PATTERNS.md heads-up #6 (byte-identity): DEFAULT PATH IS ADDITIVE, NOT FLAG-WRAP.**

Preferred (default) approach: add a NEW helper `setup_tmp_app_without_install/1` alongside existing `setup_tmp_app/1`. The new helper does everything `setup_tmp_app/1` does EXCEPT the inline `mix sigra.install` invocation — `phx.new`, path-dep patching, `deps.get`, `ecto.create`. Callers then invoke `run_sigra_install/2` with their own flags. This preserves byte-identity of `setup_tmp_app/1` (golden_diff_test is unaffected) and introduces zero risk to the existing fixture surface.

Implementation sketch:
```elixir
@spec setup_tmp_app_without_install(keyword()) :: {:ok, %{app_dir: String.t()}}
def setup_tmp_app_without_install(opts \\ []) do
  # Mirror the prep steps of setup_tmp_app/1 but skip the inline mix sigra.install.
  # Extract the common prep (phx.new + path-dep patch + deps.get) into a private
  # helper prep_tmp_app/1 that BOTH setup_tmp_app/1 and setup_tmp_app_without_install/1
  # call. The extraction of prep_tmp_app/1 is byte-neutral for setup_tmp_app/1 as
  # long as the extracted block is verbatim and the call site substitutes cleanly.
end
```

**Fallback only if the default path proves too verbose:** wrap the existing inline install block in `if Keyword.get(opts, :run_install, true) do ... end`. Document this as the fallback, NOT the default.

**Either path MUST:** run `mix test test/sigra/install/golden_diff_test.exs` after edits and verify zero byte drift in the fixture's install output.
  </action>
  <verify>
    <automated>mix test test/sigra/install/golden_diff_test.exs test/support/install_fixture.ex</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def run_sigra_install(app_dir, flags)" test/support/install_fixture.ex` returns 1
    - `grep -c "def run_sigra_upgrade(app_dir, flags)" test/support/install_fixture.ex` returns 1
    - `grep -c "def run_mix(app_dir, args)" test/support/install_fixture.ex` returns 1
    - `grep -c "def setup_tmp_app_without_install" test/support/install_fixture.ex` returns 1 (WARNING 5 — additive helper, not flag-wrap)
    - `grep -c "def setup_tmp_app(opts \\\\ \\[\\])" test/support/install_fixture.ex` returns 1 AND the inline `mix sigra.install` block inside its body is byte-identical to pre-revision (golden_diff_test passes without regenerating fixtures)
    - `grep -c "System.cmd(\"mix\"" test/support/install_fixture.ex` returns ≥ 4 (existing + 3 new)
    - `mix test test/sigra/install/golden_diff_test.exs` exits 0 (byte-identity preserved)
    - `mix test test/support/install_fixture.ex` exits 0 (if doctests exist)
    - `mix compile --warnings-as-errors` exits 0
    - `mix format --check-formatted test/support/install_fixture.ex` exits 0
  </acceptance_criteria>
  <done>InstallFixture has three new public helpers; golden_diff_test still passes; existing `setup_tmp_app/1` behavior is unchanged.</done>
</task>

<task type="auto">
  <name>Task 2: Create test/upgrade_test.exs — two-path upgrade regression test (backfill-off + backfill-on)</name>
  <files>test/upgrade_test.exs</files>
  <read_first>
    - test/sigra/install/golden_diff_test.exs (tmp-app-fixture integration test skeleton)
    - test/support/install_fixture.ex (AFTER Task 1 edits — understand the new helpers)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-06 (semantic equivalence reasoning + the exact 6-step test flow)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for test/upgrade_test.exs
  </read_first>
  <action>
Create `test/upgrade_test.exs` at the project test root (not under `test/sigra/`) to reflect its role as a top-level integration regression test. Full skeleton:

```elixir
defmodule Sigra.UpgradeTest do
  @moduledoc """
  Phase 18 D-06: semantic-equivalence upgrade regression test.

  Treats `mix sigra.install --no-organizations` as the v1.0 state by definition.
  Exercises both upgrade paths:

    * backfill-off (ORG-UPGRADE-02): users land on zero-org create/accept page, no 500s
    * backfill-on  (ORG-UPGRADE-01): every user gets a personal org, re-run is a no-op
  """

  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :upgrade
  @moduletag timeout: 600_000

  describe "upgrade after --no-organizations install (zero-org path — ORG-02 + GEN-03 org-axis)" do
    @tag :tmp_dir
    test "mix sigra.upgrade --yes on a --no-organizations install emits zero ALTERs and leaves the app bootable" do
      # BLOCKER 1: treats `mix sigra.install --no-organizations` as v1.0 fixture.
      # The upgrade task MUST detect the missing organizations table and emit ZERO
      # ALTER migrations (no crash on `mix ecto.migrate`).
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: "upgrade_zero_org")

      {:ok, _install_out} = InstallFixture.run_sigra_install(app_dir, ["--no-organizations"])

      seed_users!(app_dir, 3)
      {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

      # Snapshot priv/repo/migrations/ before upgrade.
      migrations_before =
        Path.join([app_dir, "priv", "repo", "migrations"])
        |> File.ls!()
        |> Enum.sort()

      # Act: run upgrade WITHOUT backfill flag.
      {:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])

      # Assert: no crash substring in upgrade stdout.
      refute upgrade_out =~ "** (", "upgrade raised: #{upgrade_out}"

      # Assert: no new ALTER migrations emitted (zero-org path).
      migrations_after =
        Path.join([app_dir, "priv", "repo", "migrations"])
        |> File.ls!()
        |> Enum.sort()

      new_migrations = migrations_after -- migrations_before
      alter_migrations = Enum.filter(new_migrations, &String.contains?(&1, "organizations"))

      assert alter_migrations == [],
             "expected zero new organizations-related migrations, got: #{inspect(alter_migrations)}"

      # Assert: app still compiles + migrates + boots.
      {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
      {:ok, migrate_out} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
      refute migrate_out =~ "** (", "ecto.migrate raised: #{migrate_out}"

      # Assert: no users have personal orgs (no backfill, no orgs table).
      # In the zero-org path there is no organizations table at all, so counting
      # personal orgs should either return 0 (count against nothing) or the table
      # should not exist. Encode the "table absent" case.
      refute organizations_table_exists?(app_dir),
             "expected organizations table to be absent in --no-organizations upgrade"
    end
  end

  describe "upgrade after default install (org-enabled path — ORG-UPGRADE-02)" do
    @tag :tmp_dir
    test "login after backfill-off upgrade redirects to /organizations with 302 and no 500s" do
      # BLOCKER 2: ORG-UPGRADE-02 proof. Per D-06 step 5 and ROADMAP SC #3:
      # "login still works, users land on create/accept page, no 500s, nil-guarded
      # template accessors verified by boot test".
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: "upgrade_default_org")

      # Default install = org-enabled (from Plan 18-01; organizations table already
      # has owner_user_id and personal columns).
      {:ok, _install_out} = InstallFixture.run_sigra_install(app_dir, [])

      seed_users!(app_dir, 2)
      {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

      # Act: run upgrade WITHOUT backfill flag. ALTER migrations use
      # add_if_not_exists / create_if_not_exists so they are idempotent no-ops
      # against the fresh-install shape.
      {:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])
      refute upgrade_out =~ "** (", "upgrade raised: #{upgrade_out}"

      {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
      {:ok, migrate_out} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
      refute migrate_out =~ "** (", "ecto.migrate raised: #{migrate_out}"

      # HTTP login assertion (BLOCKER 2 — ORG-UPGRADE-02 proof).
      # Approach: start `mix phx.server` in background, curl POST to login, assert
      # 302 redirect, follow Location header with session cookie, assert landing
      # page is /organizations, assert no 5xx anywhere.
      login_result = assert_login_redirects_to_organizations!(app_dir)

      assert login_result.login_status in [200, 302, 303],
             "login POST returned #{login_result.login_status}"
      assert login_result.final_path == "/organizations",
             "expected final redirect to /organizations, got #{login_result.final_path}"
      assert login_result.status_codes_seen |> Enum.all?(&(&1 < 500)),
             "saw 5xx response: #{inspect(login_result.status_codes_seen)}"
    end
  end

  describe "mix sigra.upgrade --backfill-personal-orgs (ORG-UPGRADE-01)" do
    @tag :tmp_dir
    test "every user gets a personal org; re-run is a no-op" do
      # Per BLOCKER 1: backfill path requires orgs enabled. Use default install
      # (org-enabled), not --no-organizations.
      {:ok, %{app_dir: app_dir}} =
        InstallFixture.setup_tmp_app_without_install(app_name: "upgrade_with_backfill")

      {:ok, _install_out} = InstallFixture.run_sigra_install(app_dir, [])

      seeded_count = 5
      seed_users!(app_dir, seeded_count)
      {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

      # First upgrade: backfill runs.
      {:ok, upgrade_out} =
        InstallFixture.run_sigra_upgrade(app_dir, ["--backfill-personal-orgs"])

      {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
      {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

      first_count = count_personal_orgs!(app_dir)
      assert first_count == seeded_count,
             "expected #{seeded_count} personal orgs after first backfill, got #{first_count}"

      # Re-run: must be a no-op.
      {:ok, _} = InstallFixture.run_sigra_upgrade(app_dir, ["--backfill-personal-orgs"])
      {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])

      second_count = count_personal_orgs!(app_dir)
      assert second_count == seeded_count, "expected re-run to be a no-op; got #{second_count}"
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  @doc """
  Seeds `n` users into the tmp app's DB via `mix run -e`.
  The inline script creates minimal user rows with unique emails.
  """
  defp seed_users!(app_dir, n) do
    script = """
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(#{otp_app_atom(app_dir)})
    Enum.each(1..#{n}, fn i ->
      %#{otp_app_module(app_dir)}.Accounts.User{}
      |> Ecto.Changeset.change(%{email: "user#{\#{i}}@example.test", confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      |> #{otp_app_module(app_dir)}.Repo.insert!()
    end)
    """

    {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.create"])
    {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
    {:ok, _} = InstallFixture.run_mix(app_dir, ["run", "-e", script])
  end

  defp count_personal_orgs!(app_dir) do
    script = ~S"""
    {:ok, _} = Application.ensure_all_started(APP_OTP)
    APP_MODULE.Repo.aggregate(
      from(o in "organizations", where: o.personal == true),
      :count
    ) |> IO.puts()
    """

    script =
      script
      |> String.replace("APP_OTP", otp_app_atom(app_dir))
      |> String.replace("APP_MODULE", otp_app_module(app_dir))

    {:ok, out} = InstallFixture.run_mix(app_dir, ["run", "-e", script])

    out
    |> String.trim()
    |> String.split("\n")
    |> List.last()
    |> String.to_integer()
  end

  defp otp_app_atom(app_dir) do
    app_dir |> Path.basename() |> Macro.underscore()
  end

  defp otp_app_module(app_dir) do
    app_dir |> Path.basename() |> Macro.camelize()
  end

  # ── BLOCKER 1 helper ─────────────────────────────────────────────

  defp organizations_table_exists?(app_dir) do
    script = ~S"""
    {:ok, _} = Application.ensure_all_started(APP_OTP)
    result =
      Ecto.Adapters.SQL.query!(
        APP_MODULE.Repo,
        "SELECT 1 FROM information_schema.tables WHERE table_name = 'organizations'",
        []
      )
    IO.puts(length(result.rows))
    """

    script =
      script
      |> String.replace("APP_OTP", otp_app_atom(app_dir))
      |> String.replace("APP_MODULE", otp_app_module(app_dir))

    case InstallFixture.run_mix(app_dir, ["run", "-e", script]) do
      {:ok, out} ->
        out |> String.trim() |> String.split("
") |> List.last() |> String.to_integer() > 0

      _ ->
        false
    end
  end

  # ── BLOCKER 2 helper: HTTP login assertion for ORG-UPGRADE-02 ────

  # Starts `mix phx.server` in the tmp app as a background port, POSTs login,
  # follows the redirect with the session cookie, and returns a map of observed
  # status codes + final path. Two implementation paths are acceptable:
  #
  #   A) `mix phx.server` in background + `curl` (preferred — simplest, no
  #      endpoint startup inside mix run -e).
  #
  #   B) `mix run -e` with an inline Elixir script that starts the endpoint in
  #      the current BEAM, builds `Plug.Test.conn/3`, simulates login via direct
  #      call into `MyApp.Accounts.Auth.create_session/3`, and issues a Plug.Test
  #      GET to `/`.
  #
  # The executor should start with (A). If port binding proves unreliable in CI,
  # fall back to (B). Either MUST assert:
  #
  #   * login POST returns 2xx/3xx (never 5xx)
  #   * redirect chain terminates at `/organizations`
  #   * no response in the chain has status >= 500
  defp assert_login_redirects_to_organizations!(app_dir) do
    port = 4444 + :rand.uniform(1000)

    # Start phx.server in background. Seed a user with a known password first
    # via `mix run -e`, then POST login via curl.
    seed_login_user!(app_dir, "login@example.test", "CorrectHorse!1")

    server_task =
      Task.async(fn ->
        System.cmd("mix", ["phx.server"],
          cd: app_dir,
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "dev"}, {"PORT", Integer.to_string(port)}]
        )
      end)

    # Poll for readiness.
    :ok = wait_for_http(port, 30_000)

    try do
      # POST /users/log_in (standard phx.gen.auth route).
      {login_out, _} =
        System.cmd(
          "curl",
          [
            "-s",
            "-i",
            "-c", "#{app_dir}/cookies.txt",
            "-X", "POST",
            "-d", "user[email]=login@example.test&user[password]=CorrectHorse!1",
            "http://localhost:#{port}/users/log_in"
          ],
          stderr_to_stdout: true
        )

      login_status = parse_http_status(login_out)

      # Follow redirect chain with the session cookie.
      {get_out, _} =
        System.cmd(
          "curl",
          [
            "-s",
            "-i",
            "-L",
            "-b", "#{app_dir}/cookies.txt",
            "-o", "/dev/null",
            "-w", "%{http_code} %{url_effective}
",
            "http://localhost:#{port}/"
          ],
          stderr_to_stdout: true
        )

      [final_code_str, final_url] = String.split(String.trim(get_out), " ", parts: 2)
      {final_code, _} = Integer.parse(final_code_str)
      final_path = URI.parse(final_url).path

      # Scan all response headers for 5xx.
      all_status_codes = parse_all_http_status_codes(login_out) ++ [final_code]

      %{
        login_status: login_status,
        final_path: final_path,
        status_codes_seen: all_status_codes
      }
    after
      System.cmd("pkill", ["-f", "phx.server"], stderr_to_stdout: true)
      Task.shutdown(server_task, :brutal_kill)
    end
  end

  defp seed_login_user!(app_dir, email, password) do
    # Generated phx.gen.auth User schema uses register_changeset with :email
    # and :password. Emit via mix run -e.
    script = ~S"""
    {:ok, _} = Application.ensure_all_started(APP_OTP)
    APP_MODULE.Accounts.register_user(%{email: "EMAIL", password: "PASSWORD"})
    """
    script =
      script
      |> String.replace("APP_OTP", otp_app_atom(app_dir))
      |> String.replace("APP_MODULE", otp_app_module(app_dir))
      |> String.replace("EMAIL", email)
      |> String.replace("PASSWORD", password)

    {:ok, _} = InstallFixture.run_mix(app_dir, ["run", "-e", script])
  end

  defp wait_for_http(port, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_http(port, deadline)
  end

  defp do_wait_for_http(port, deadline) do
    case :gen_tcp.connect(~c"localhost", port, [], 500) do
      {:ok, sock} ->
        :gen_tcp.close(sock)
        :ok

      {:error, _} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :timeout}
        else
          Process.sleep(250)
          do_wait_for_http(port, deadline)
        end
    end
  end

  defp parse_http_status(raw) do
    case Regex.run(~r/^HTTP\/[\d.]+\s+(\d+)/m, raw) do
      [_, code] -> String.to_integer(code)
      _ -> 0
    end
  end

  defp parse_all_http_status_codes(raw) do
    Regex.scan(~r/^HTTP\/[\d.]+\s+(\d+)/m, raw)
    |> Enum.map(fn [_, code] -> String.to_integer(code) end)
  end
end
```

**Implementation notes for the executor:**

1. The helper scripts passed to `mix run -e` are best-effort inline seeds. If `mix run -e` proves unreliable for the multi-line scripts above, factor them into files written to the tmp app (`File.write!/2`) and invoke via `mix run #{script_file}`. Either path is acceptable; prefer whichever works cleanly on first pass.

2. `import Ecto.Query` is needed inside the inline `count_personal_orgs!/1` script — prepend `import Ecto.Query` to the script string.

3. The seed script assumes the generated `User` schema accepts `email` and `confirmed_at` via changeset. If the actual generated schema requires additional fields (e.g. `hashed_password`), add them to the inline script — inspect `priv/templates/sigra.install/core/` user-schema templates before writing the seed script.

4. Both tests share the `setup_tmp_app(run_install: false)` pattern. If Task 1 did NOT add the `run_install` option, rewrite the test to do a bespoke tmp-app setup without calling `setup_tmp_app/1` — copy the phx.new + path-dep patching from `setup_tmp_app/1`'s existing body.

5. Use `@moduletag timeout: 600_000` (10 min) — `phx.new` + `mix deps.get` + `mix compile` + upgrade + migrate + re-upgrade is slow.

6. If running the full test locally exceeds 10 min on a typical dev machine, bump to 900_000 rather than skipping assertions.
  </action>
  <verify>
    <automated>mix test test/upgrade_test.exs --only upgrade</automated>
  </verify>
  <acceptance_criteria>
    - `test/upgrade_test.exs` exists at project root under `test/`
    - `grep -c "describe \"upgrade after --no-organizations install" test/upgrade_test.exs` returns 1
    - `grep -c "describe \"upgrade after default install" test/upgrade_test.exs` returns 1
    - `grep -c "describe \"mix sigra.upgrade --backfill-personal-orgs" test/upgrade_test.exs` returns 1
    - `grep -c "assert_login_redirects_to_organizations" test/upgrade_test.exs` returns ≥ 2 (definition + call)
    - `grep -c "final_path == \"/organizations\"" test/upgrade_test.exs` returns ≥ 1 (ORG-UPGRADE-02 proof)
    - `grep -c "refute.*=~ \"\*\* (\"" test/upgrade_test.exs` returns ≥ 2 (crash-scan in both upgrade_out and migrate_out)
    - `grep -c "organizations_table_exists?" test/upgrade_test.exs` returns ≥ 2 (definition + call — zero-org proof)
    - `grep -c "alter_migrations == \[\]" test/upgrade_test.exs` returns ≥ 1 (zero-ALTER-emission proof for --no-organizations path)
    - `grep -c "run_sigra_install(app_dir, \\[\"--no-organizations\"\\])" test/upgrade_test.exs` returns ≥ 1 (zero-org path)
    - `grep -c "run_sigra_install(app_dir, \\[\\])" test/upgrade_test.exs` returns ≥ 2 (org-enabled path + backfill path)
    - `grep -c "run_sigra_upgrade(app_dir, \\[\\])" test/upgrade_test.exs` returns ≥ 2 (both backfill-off paths)
    - `grep -c "run_sigra_upgrade(app_dir, \\[\"--backfill-personal-orgs\"\\])" test/upgrade_test.exs` returns ≥ 2 (first + rerun)
    - `grep -c "count_personal_orgs" test/upgrade_test.exs` returns ≥ 2
    - `grep -c "assert.*== seeded_count" test/upgrade_test.exs` returns ≥ 2 (first-run + rerun idempotency assertions)
    - `grep -c "@moduletag timeout" test/upgrade_test.exs` returns ≥ 1
    - `mix test test/upgrade_test.exs --only upgrade` exits 0 (or, if local env cannot run phx.new, the test MUST pass in CI — verified via the install_matrix job logs)
    - `mix format --check-formatted test/upgrade_test.exs` exits 0
  </acceptance_criteria>
  <done>Two passing tests cover both upgrade paths (backfill-off → zero personal orgs; backfill-on → seeded_count personal orgs + idempotent rerun).</done>
</task>

<task type="auto">
  <name>Task 3: Add install_matrix job to .github/workflows/ci.yml with extensible list-of-flags matrix</name>
  <files>.github/workflows/ci.yml</files>
  <read_first>
    - .github/workflows/ci.yml (full file — especially the existing `install_smoke` job ~lines 104–149)
    - .planning/phases/18-backfill-organizations-generator-wiring/18-CONTEXT.md D-07
    - .planning/phases/18-backfill-organizations-generator-wiring/18-PATTERNS.md section for ci.yml
  </read_first>
  <action>
Append a new job `install_matrix` to `.github/workflows/ci.yml`. Copy the `install_smoke` job skeleton verbatim and parameterize the sigra.install invocation via `strategy.matrix.flags`. The matrix shape MUST be a list-of-flag-strings (D-07) — Phase 19+ will append `"--no-passkeys"` etc. without restructuring.

```yaml
  install_matrix:
    name: Install matrix (flag combinations)
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        flags:
          - ""
          - "--no-organizations"
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_USER: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          version-file: .tool-versions
          version-type: strict
      - name: Install Hex + Rebar
        run: |
          mix local.hex --force
          mix local.rebar --force
      - name: Install phx_new archive
        run: mix archive.install --force hex phx_new
      - name: Fetch Sigra library deps
        run: mix deps.get
      - name: Scaffold fresh Phoenix app
        run: mix phx.new tmp_app --no-assets --no-mailer --no-install
      - name: Patch tmp app mix.exs with sigra path dep
        working-directory: tmp_app
        run: |
          # Mirrors InstallFixture.patch_mix_exs_with_path_dep!
          sed -i 's|defp deps do|defp deps do\n    sigra: [path: "..", override: true],|' mix.exs || true
          # If the sed above doesn't match cleanly, fall back to appending via a known marker.
      - name: Run sigra.install with matrix flags
        working-directory: tmp_app
        run: mix sigra.install Accounts User users ${{ matrix.flags }} --yes
      - name: Compile + migrate + test
        working-directory: tmp_app
        env:
          PGUSER: postgres
          PGPASSWORD: postgres
          PGHOST: localhost
          MIX_ENV: test
        run: |
          mix deps.get
          mix compile --warnings-as-errors
          mix ecto.create
          mix ecto.migrate
          mix test
```

**IMPORTANT — SHA pinning rule:** if the existing `install_smoke` job uses full SHA-pinned actions (e.g. `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5`), match that pattern in the new job — copy the SAME pinned SHAs to keep Dependabot's update surface consistent. Do NOT use bare `@v4` tags if the rest of the file uses SHAs.

**IMPORTANT — sed patching:** the exact `sed` pattern above is a best-effort guess. Before committing, check `test/support/install_fixture.ex` for the ACTUAL `patch_mix_exs_with_path_dep!` function and mirror its shell-equivalent behavior. The real patching may use a different anchor or a heredoc `echo` append. Fidelity matters — a mismatched sed will silently fail and the CI leg will install the hex-released sigra (wrong).

**Matrix extensibility check:** leave a comment above the matrix entry:
```yaml
        # Extensible — Phase 19+ will append:
        #   - "--no-passkeys"
        #   - "--no-organizations --no-passkeys"
```

Do NOT restructure as a 2D boolean product. D-07 locked the list-of-flag-strings shape.
  </action>
  <verify>
    <automated>grep -c "install_matrix" .github/workflows/ci.yml</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "install_matrix:" .github/workflows/ci.yml` returns 1
    - `grep -c "strategy:" .github/workflows/ci.yml` shows at least one new entry (count increased from baseline)
    - `grep -c "flags:" .github/workflows/ci.yml` returns ≥ 1 under install_matrix
    - `grep -c '\\- "--no-organizations"' .github/workflows/ci.yml` returns ≥ 1
    - `grep -c '\\- ""' .github/workflows/ci.yml` returns ≥ 1 (empty-flags matrix entry)
    - `grep -c "\\${{ matrix.flags }}" .github/workflows/ci.yml` returns ≥ 1
    - `grep -c "fail-fast: false" .github/workflows/ci.yml` returns ≥ 1
    - `yamllint .github/workflows/ci.yml` returns 0 (if yamllint is available; otherwise `python -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'` exits 0)
  </acceptance_criteria>
  <done>New `install_matrix` job exists with list-of-flag-strings matrix, both org-axis entries, and a comment reserving space for Phase 19+ passkey-axis entries.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CI → tmp app | CI runner spawns a throwaway Phoenix app and runs upgrade/install against it. No user data; throwaway DB. |
| InstallFixture subprocess → tmp app | Tests spawn `mix` subprocesses in a tmp dir; captured stdout is asserted against. No secrets cross the boundary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-18-13 | Tampering | Test fixture writes outside tmp dir | mitigate | All `System.cmd/3` calls pass `cd: app_dir` (which is always `System.tmp_dir!/1 <> "/sigra_..."`). No relative writes to the sigra repo from within the test. |
| T-18-14 | Information Disclosure | CI secrets leaked via tmp app subprocess output | accept | No secrets are used in the install_matrix job (no hex auth, no external API calls). Database credentials are the standard postgres/postgres throwaway pair. |
| T-18-15 | Denial of Service | Long-running upgrade test hangs CI | mitigate | `@moduletag timeout: 600_000` (10 min) caps single-test runtime. CI job-level timeout applies at the workflow level. |
| T-18-16 | Elevation of Privilege | Unpinned GitHub Action consumes malicious upstream version | mitigate | Follow existing SHA-pinning convention in `ci.yml` — Task 3 acceptance criteria call this out explicitly. |
</threat_model>

<verification>
- `Sigra.Test.InstallFixture` has `run_sigra_install/2`, `run_sigra_upgrade/2`, and `run_mix/2` as public exported helpers
- `mix test test/sigra/install/golden_diff_test.exs` still passes (byte-identity preserved)
- `test/upgrade_test.exs` exists with two describe blocks (backfill-off + backfill-on) and asserts personal-org counts AND idempotent rerun
- `mix test test/upgrade_test.exs --only upgrade` passes locally (or, if local env blocks `phx.new`, the install_matrix CI job must pass for both `""` and `"--no-organizations"` legs in the PR that lands this plan)
- `.github/workflows/ci.yml` has an `install_matrix` job with `strategy.matrix.flags: ["", "--no-organizations"]` and shells `mix sigra.install ... ${{ matrix.flags }} --yes`
- The CI matrix extensibility comment is present (reserves space for Phase 19+ passkey axis)
- `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, and `yamllint` all pass
</verification>

<success_criteria>
1. Phase 18 ships `test/upgrade_test.exs` (ORG-UPGRADE-03): two passing tests, one per upgrade path, asserting backfill-off → users land on zero-org page with no crashes, backfill-on → every user has a personal org AND rerun is a no-op.
2. `Sigra.Test.InstallFixture` gains three reusable subprocess helpers without breaking the golden diff test (byte-identity preserved).
3. `.github/workflows/ci.yml` has a new `install_matrix` job with list-of-flag-strings matrix shape that runs on every PR; both the `""` and `"--no-organizations"` legs compile, migrate, and test cleanly (GEN-03).
4. Re-running `mix sigra.upgrade --backfill-personal-orgs --yes` a second time in the same tmp app does NOT change the personal-org count (idempotency regression lock).
5. ORG-UPGRADE-02 is structurally proven by the backfill-off test — users land on zero-org create/accept page, no 500s.
</success_criteria>

<output>
After completion, create `.planning/phases/18-backfill-organizations-generator-wiring/18-03-SUMMARY.md` following `$HOME/.claude/get-shit-done/templates/summary.md`.
</output>
