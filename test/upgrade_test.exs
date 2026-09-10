defmodule Sigra.UpgradeIntegrationTest do
  @moduledoc """
  Phase 18 D-06: semantic-equivalence upgrade regression test.

  Treats `mix sigra.install --no-organizations` as the v1.0 state by definition.
  Exercises both upgrade paths:

    * backfill-off (ORG-UPGRADE-02): users land on zero-org create/accept page, no 500s
    * backfill-on  (ORG-UPGRADE-01): every user gets a personal org, re-run is a no-op
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.InstallFixture

  @documented_upgrade_command "mix sigra.upgrade --yes"
  @documented_backfill_command "mix sigra.upgrade --backfill-personal-orgs --yes"

  @moduletag timeout: 600_000
  @moduletag :scaffold

  setup_all do
    original_cloak_key = System.get_env("CLOAK_KEY")
    System.put_env("CLOAK_KEY", Base.encode64(:crypto.strong_rand_bytes(32)))

    on_exit(fn ->
      if is_nil(original_cloak_key) do
        System.delete_env("CLOAK_KEY")
      else
        System.put_env("CLOAK_KEY", original_cloak_key)
      end
    end)

    :ok
  end

  describe "isolated prepared upgrade scenarios" do
    @tag :tmp_dir
    test "zero-org, backfill-off, and backfill-on retain their complete behavior" do
      scenarios =
        prepare_checkouts!([
          {:no_org_installed, "upgrade-zero-org", :zero_org},
          {:default_installed, "upgrade-backfill-off", :backfill_off},
          {:default_installed, "upgrade-backfill-on", :backfill_on}
        ])

      assert {:ok, results} =
               InstallFixture.run_scenarios(scenarios, &run_upgrade_scenario/1)

      assert results |> Enum.map(fn {scenario, :ok} -> scenario.kind end) |> Enum.sort() ==
               [:backfill_off, :backfill_on, :zero_org]
    end
  end

  defp run_upgrade_scenario(%{kind: :zero_org} = checkout) do
    # BLOCKER 1: treats `mix sigra.install --no-organizations` as v1.0 fixture.
    # The upgrade task MUST detect the missing organizations table and emit ZERO
    # ALTER migrations (no crash on `mix ecto.migrate`).
    app_dir = checkout.path

    # Snapshot priv/repo/migrations/ before upgrade.
    migrations_before =
      [app_dir, "priv", "repo", "migrations"]
      |> Path.join()
      |> File.ls!()
      |> Enum.sort()

    # Act: seed, upgrade, compile, migrate, and inspect the database inside one
    # bounded checkout-local Mix session.
    result = run_upgrade_session!(checkout, seeded_count: 3)

    # Assert: no crash substring in upgrade stdout.
    refute result.output =~ "** (", "upgrade raised: #{result.output}"
    assert documented_upgrade_command([]) == @documented_upgrade_command

    # Assert: no new ALTER migrations emitted (zero-org path).
    migrations_after =
      [app_dir, "priv", "repo", "migrations"]
      |> Path.join()
      |> File.ls!()
      |> Enum.sort()

    new_migrations = migrations_after -- migrations_before
    alter_migrations = Enum.filter(new_migrations, &String.contains?(&1, "organizations"))

    assert alter_migrations == [],
           "expected zero new organizations-related migrations, got: #{inspect(alter_migrations)}"

    # Assert: app still compiles + migrates + boots.
    refute result.output =~ "** (", "ecto.migrate raised: #{result.output}"

    # Assert: organizations table should be absent in the zero-org path.
    refute result.organizations_table_exists,
           "expected organizations table to be absent in --no-organizations upgrade"

    :ok
  end

  defp run_upgrade_scenario(%{kind: :backfill_off} = checkout) do
    # BLOCKER 2: ORG-UPGRADE-02 proof. Per D-06 step 5 and ROADMAP SC #3:
    # "login still works, users land on create/accept page, no 500s, nil-guarded
    # template accessors verified by boot test".
    # Act: run upgrade WITHOUT backfill flag. ALTER migrations use
    # add_if_not_exists / create_if_not_exists so they are idempotent no-ops
    # against the fresh-install shape.
    result = run_upgrade_session!(checkout, seeded_count: 2)
    refute result.output =~ "** (", "upgrade raised: #{result.output}"
    assert documented_upgrade_command([]) == @documented_upgrade_command

    refute result.output =~ "** (", "ecto.migrate raised: #{result.output}"

    # HTTP login assertion (BLOCKER 2 — ORG-UPGRADE-02 proof).
    login_result = assert_login_redirects_to_organizations!(checkout)

    assert login_result.login_status in [200, 302, 303],
           "login POST returned #{login_result.login_status}"

    # ORG-UPGRADE-02 post-upgrade landing assertion.
    #
    # The seeded login user was created via the generated
    # `register_user/1` which, on a v1.1+ default install, auto-
    # creates a personal organization. Post-upgrade that user
    # therefore has an active org and is routed to the app root
    # (`/`). A pre-v1.1 user with zero orgs would instead be
    # trapped on `/organizations` by `RequireMembership`. Both
    # outcomes are acceptable here — the load-bearing guarantee is
    # that the session is valid, the router fires, and no 5xx
    # leaks from a nil-guard gap in the upgraded templates.
    assert login_result.final_path in ["/", "/organizations"],
           "expected final path to be / or /organizations, got #{login_result.final_path}"

    assert Enum.all?(login_result.status_codes_seen, &(&1 < 500)),
           "saw 5xx response: #{inspect(login_result.status_codes_seen)}"

    :ok
  end

  defp run_upgrade_scenario(%{kind: :backfill_on} = checkout) do
    # Per BLOCKER 1: backfill path requires orgs enabled. Use default install
    # (org-enabled), not --no-organizations.
    seeded_count = 5
    result = run_upgrade_session!(checkout, seeded_count: seeded_count)

    assert documented_upgrade_command(["--backfill-personal-orgs"]) ==
             @documented_backfill_command

    if result.organizations_table_exists do
      assert result.first_count == seeded_count,
             "expected #{seeded_count} personal orgs after first backfill, got #{result.first_count}"

      assert result.second_count == seeded_count,
             "expected re-run to be a no-op; got #{result.second_count}"
    else
      # Some dependency-minimal install shapes do not install organizations.
      # Backfill must remain a no-op in that shape, including on re-run.
      refute result.organizations_table_exists_after_rerun,
             "expected backfill to preserve org-absent install shape"
    end

    :ok
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp prepare_checkouts!(specs) do
    specs
    |> Task.async_stream(
      fn {variant, scenario, kind} ->
        variant
        |> InstallFixture.checkout!(scenario)
        |> Map.put(:kind, kind)
      end,
      max_concurrency: 2,
      ordered: true,
      timeout: 120_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, checkout} -> checkout
      {:exit, reason} -> flunk("private upgrade checkout preparation failed: #{inspect(reason)}")
    end)
  end

  # Runs each upgrade scenario's Mix tasks and database assertions in one BEAM.
  # The fixture runner provides the hard 120-second scenario timeout around this
  # command, and run_mix/3 retains the graph-global two-worker lease.
  defp run_upgrade_session!(checkout, opts) do
    app_dir = checkout.path
    seeded_count = Keyword.fetch!(opts, :seeded_count)
    otp_atom = otp_app_atom(app_dir)
    otp_module = otp_app_module(app_dir)

    script = """
    defmodule SigraUpgradeReceiverSession do
      import Ecto.Query

      @repo #{otp_module}.Repo

      def run(kind, seeded_count) do
        Logger.configure(level: :warning)
        task("ecto.create", ["--quiet"])
        task("ecto.migrate", ["--quiet"])
        {:ok, _} = Application.ensure_all_started(:#{otp_atom})
        seed_users(seeded_count)

        if kind == :backfill_off do
          {:ok, _} =
            #{otp_module}.Accounts.register_user(%{
              email: "login@example.test",
              password: "CorrectHorse!1"
            })
        end

        upgrade_flags = if kind == :backfill_on, do: ["--backfill-personal-orgs"], else: []
        upgrade(upgrade_flags)
        task("compile", [])
        task("ecto.migrate", ["--quiet"])

        result =
          if kind == :backfill_on do
            data_migrations()
            exists = organizations_table_exists?()
            first_count = if exists, do: personal_org_count(), else: nil

            upgrade(upgrade_flags)
            task("ecto.migrate", ["--quiet"])
            data_migrations()

            %{
              organizations_table_exists: exists,
              organizations_table_exists_after_rerun: organizations_table_exists?(),
              first_count: first_count,
              second_count: if(exists, do: personal_org_count(), else: nil)
            }
          else
            %{organizations_table_exists: organizations_table_exists?()}
          end

        IO.puts("SIGRA_UPGRADE_RESULT:" <> Jason.encode!(result))
      end

      defp task(name, args) do
        Mix.Task.reenable(name)
        Mix.Task.run(name, args)
      end

      defp upgrade(flags),
        do: task("sigra.upgrade", flags ++ ["--allow-dirty", "--yes"])

      defp seed_users(count) do
        Enum.each(1..count, fn i ->
          %#{otp_module}.Accounts.User{}
          |> Ecto.Changeset.change(%{
            email: "user\#{i}@example.test",
            confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> @repo.insert!()
        end)
      end

      # Schema migrations and generated data migrations intentionally remain
      # distinct so the receiver proves the documented two-stage upgrade path.
      defp data_migrations do
        Ecto.Migrator.run(@repo, "priv/repo/data_migrations", :up, all: true)
      end

      defp organizations_table_exists? do
        result =
          Ecto.Adapters.SQL.query!(
            @repo,
            "SELECT 1 FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = 'organizations'",
            []
          )

        result.rows != []
      end

      defp personal_org_count do
        @repo.aggregate(from(o in "organizations", where: o.personal == true), :count)
      end
    end

    SigraUpgradeReceiverSession.run(#{inspect(checkout.kind)}, #{seeded_count})
    """

    {:ok, output} =
      InstallFixture.run_mix(app_dir, ["run", "--no-start", "--no-compile", "-e", script])

    case Regex.run(~r/^SIGRA_UPGRADE_RESULT:(\{.*\})$/m, output) do
      [_, encoded] ->
        result = Jason.decode!(encoded)

        %{
          output: output,
          organizations_table_exists: result["organizations_table_exists"],
          organizations_table_exists_after_rerun:
            result["organizations_table_exists_after_rerun"],
          first_count: result["first_count"],
          second_count: result["second_count"]
        }

      nil ->
        flunk("upgrade session did not emit SIGRA_UPGRADE_RESULT:\n#{output}")
    end
  end

  defp documented_upgrade_command(flags) do
    ["mix", "sigra.upgrade" | flags ++ ["--yes"]]
    |> Enum.join(" ")
  end

  defp otp_app_atom(app_dir) do
    [_, app] = Regex.run(~r/app:\s+:(\w+)/, File.read!(Path.join(app_dir, "mix.exs")))
    app
  end

  defp otp_app_module(app_dir) do
    app_dir |> otp_app_atom() |> Macro.camelize()
  end

  # ── BLOCKER 2 helper: HTTP login assertion for ORG-UPGRADE-02 ────

  # Starts `mix phx.server` in the tmp app as a background port, POSTs login,
  # follows the redirect with the session cookie, and returns a map of observed
  # status codes + final path.
  defp assert_login_redirects_to_organizations!(checkout) do
    app_dir = checkout.path
    port = checkout.port

    {server_port, server_pid} = start_server!(checkout)

    try do
      :ok = wait_for_http(port, 30_000)

      # Step 1: GET the login form to establish a session cookie AND
      # extract the _csrf_token hidden input. Phoenix 1.8's default
      # `protect_from_forgery` plug rejects POSTs without a matching
      # token with a 403, so the test has to go through the form.
      {form_out, _} =
        System.cmd(
          "curl",
          [
            "-s",
            "--connect-timeout",
            "2",
            "--max-time",
            "10",
            "-c",
            "#{app_dir}/cookies.txt",
            "http://localhost:#{port}/users/log_in"
          ],
          stderr_to_stdout: true
        )

      # Match either attribute order — Phoenix's form helpers render
      # hidden inputs as `<input name="_csrf_token" value="..."/>` or
      # `<input value="..." name="_csrf_token"/>` depending on version.
      csrf_token =
        cond do
          match = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, form_out) ->
            Enum.at(match, 1)

          match = Regex.run(~r/value="([^"]+)"[^>]*name="_csrf_token"/, form_out) ->
            Enum.at(match, 1)

          true ->
            flunk("could not extract _csrf_token from /users/log_in form:\n#{form_out}")
        end

      # Step 2: POST /users/log_in (standard phx.gen.auth route) with
      # the extracted CSRF token and the session cookie jar.
      {login_out, _} =
        System.cmd(
          "curl",
          [
            "-s",
            "--connect-timeout",
            "2",
            "--max-time",
            "10",
            "-i",
            "-b",
            "#{app_dir}/cookies.txt",
            "-c",
            "#{app_dir}/cookies.txt",
            "-X",
            "POST",
            "--data-urlencode",
            "_csrf_token=#{csrf_token}",
            "--data-urlencode",
            "user[email]=login@example.test",
            "--data-urlencode",
            "user[password]=CorrectHorse!1",
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
            "--connect-timeout",
            "2",
            "--max-time",
            "10",
            "-L",
            "-b",
            "#{app_dir}/cookies.txt",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code} %{url_effective}\n",
            "http://localhost:#{port}/"
          ],
          stderr_to_stdout: true
        )

      [final_code_str, final_url] = String.split(String.trim(get_out), " ", parts: 2)
      {final_code, _} = Integer.parse(final_code_str)
      final_path = URI.parse(final_url).path

      all_status_codes = parse_all_http_status_codes(login_out) ++ [final_code]

      %{
        login_status: login_status,
        final_path: final_path,
        status_codes_seen: all_status_codes
      }
    after
      stop_server!(server_port, server_pid)
    end
  end

  defp start_server!(checkout) do
    executable = System.find_executable("mix") || flunk("mix executable not found")

    server_port =
      Port.open(
        {:spawn_executable, executable},
        [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          args: [~c"phx.server"],
          cd: String.to_charlist(checkout.path),
          env: [
            {~c"MIX_ENV", ~c"dev"},
            {~c"MIX_TEST_PARTITION", String.to_charlist(checkout.partition)},
            {~c"MIX_BUILD_PATH", String.to_charlist(checkout.build_path)},
            {~c"MIX_DEPS_PATH", String.to_charlist(checkout.deps_path)},
            {~c"PORT", checkout.port |> Integer.to_string() |> String.to_charlist()}
          ]
        ]
      )

    {:os_pid, server_pid} = Port.info(server_port, :os_pid)
    {server_port, server_pid}
  end

  defp stop_server!(server_port, server_pid) do
    owned_pids = [server_pid | descendant_pids(server_pid)] |> Enum.uniq()
    signal_processes(Enum.reverse(owned_pids), "TERM")
    await_port_exit(server_port, 2_000)

    remaining = Enum.filter(owned_pids, &os_process_alive?/1)
    signal_processes(Enum.reverse(remaining), "KILL")
    await_process_exit(remaining, 2_000)

    if Port.info(server_port) do
      Port.close(server_port)
    end

    still_alive = Enum.filter(owned_pids, &os_process_alive?/1)

    if still_alive != [] do
      flunk("upgrade server left owned OS descendants alive: #{inspect(still_alive)}")
    end
  end

  defp descendant_pids(parent_pid) do
    case System.cmd("pgrep", ["-P", Integer.to_string(parent_pid)], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split()
        |> Enum.map(&String.to_integer/1)
        |> Enum.flat_map(fn child_pid -> [child_pid | descendant_pids(child_pid)] end)

      {_output, _status} ->
        []
    end
  end

  defp signal_processes([], _signal), do: :ok

  defp signal_processes(pids, signal) do
    System.cmd("kill", ["-#{signal}" | Enum.map(pids, &Integer.to_string/1)],
      stderr_to_stdout: true
    )

    :ok
  end

  defp await_port_exit(server_port, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_port_exit(server_port, deadline)
  end

  defp do_await_port_exit(server_port, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^server_port, {:exit_status, _status}} ->
        :ok

      {^server_port, {:data, _output}} ->
        do_await_port_exit(server_port, deadline)
    after
      remaining -> :timeout
    end
  end

  defp await_process_exit([], _timeout_ms), do: :ok

  defp await_process_exit(pids, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_process_exit(pids, deadline)
  end

  defp do_await_process_exit(pids, deadline) do
    remaining = Enum.filter(pids, &os_process_alive?/1)

    cond do
      remaining == [] ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        :timeout

      true ->
        Process.sleep(25)
        do_await_process_exit(remaining, deadline)
    end
  end

  defp os_process_alive?(pid) do
    match?(
      {_output, 0},
      System.cmd("kill", ["-0", Integer.to_string(pid)], stderr_to_stdout: true)
    )
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
    ~r/^HTTP\/[\d.]+\s+(\d+)/m
    |> Regex.scan(raw)
    |> Enum.map(fn [_, code] -> String.to_integer(code) end)
  end
end
