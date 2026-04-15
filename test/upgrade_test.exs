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
        [app_dir, "priv", "repo", "migrations"]
        |> Path.join()
        |> File.ls!()
        |> Enum.sort()

      # Act: run upgrade WITHOUT backfill flag.
      {:ok, upgrade_out} = InstallFixture.run_sigra_upgrade(app_dir, [])

      # Assert: no crash substring in upgrade stdout.
      refute upgrade_out =~ "** (", "upgrade raised: #{upgrade_out}"

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
      {:ok, _} = InstallFixture.run_mix(app_dir, ["compile", "--warnings-as-errors"])
      {:ok, migrate_out} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
      refute migrate_out =~ "** (", "ecto.migrate raised: #{migrate_out}"

      # Assert: organizations table should be absent in the zero-org path.
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
      login_result = assert_login_redirects_to_organizations!(app_dir)

      assert login_result.login_status in [200, 302, 303],
             "login POST returned #{login_result.login_status}"

      assert login_result.final_path == "/organizations",
             "expected final redirect to /organizations, got #{login_result.final_path}"

      assert Enum.all?(login_result.status_codes_seen, &(&1 < 500)),
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
      {:ok, _upgrade_out} =
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

  # Seeds `n` users into the tmp app's DB via `mix run -e`.
  defp seed_users!(app_dir, n) do
    otp_atom = otp_app_atom(app_dir)
    otp_module = otp_app_module(app_dir)

    script = """
    {:ok, _} = Application.ensure_all_started(:#{otp_atom})
    Enum.each(1..#{n}, fn i ->
      %#{otp_module}.Accounts.User{}
      |> Ecto.Changeset.change(%{
        email: "user\#{i}@example.test",
        confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> #{otp_module}.Repo.insert!()
    end)
    """

    {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.create"])
    {:ok, _} = InstallFixture.run_mix(app_dir, ["ecto.migrate"])
    {:ok, _} = InstallFixture.run_mix(app_dir, ["run", "-e", script])
  end

  defp count_personal_orgs!(app_dir) do
    otp_atom = otp_app_atom(app_dir)
    otp_module = otp_app_module(app_dir)

    script = """
    import Ecto.Query
    {:ok, _} = Application.ensure_all_started(:#{otp_atom})
    count =
      #{otp_module}.Repo.aggregate(
        from(o in "organizations", where: o.personal == true),
        :count
      )
    IO.puts(count)
    """

    {:ok, out} = InstallFixture.run_mix(app_dir, ["run", "-e", script])

    out
    |> String.trim()
    |> String.split("\n")
    |> List.last()
    |> String.to_integer()
  end

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
    IO.puts(length(result.rows))
    """

    case InstallFixture.run_mix(app_dir, ["run", "-e", script]) do
      {:ok, out} ->
        out
        |> String.trim()
        |> String.split("\n")
        |> List.last()
        |> String.to_integer()
        |> Kernel.>(0)

      _ ->
        false
    end
  end

  defp otp_app_atom(app_dir) do
    app_dir |> Path.basename() |> Macro.underscore()
  end

  defp otp_app_module(app_dir) do
    app_dir |> Path.basename() |> Macro.camelize()
  end

  # ── BLOCKER 2 helper: HTTP login assertion for ORG-UPGRADE-02 ────

  # Starts `mix phx.server` in the tmp app as a background port, POSTs login,
  # follows the redirect with the session cookie, and returns a map of observed
  # status codes + final path.
  defp assert_login_redirects_to_organizations!(app_dir) do
    port = 4444 + :rand.uniform(1000)

    # Seed a user with a known password via generated register_user/1.
    seed_login_user!(app_dir, "login@example.test", "CorrectHorse!1")

    server_task =
      Task.async(fn ->
        System.cmd("mix", ["phx.server"],
          cd: app_dir,
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "dev"}, {"PORT", Integer.to_string(port)}]
        )
      end)

    :ok = wait_for_http(port, 30_000)

    try do
      # POST /users/log_in (standard phx.gen.auth route).
      {login_out, _} =
        System.cmd(
          "curl",
          [
            "-s",
            "-i",
            "-c",
            "#{app_dir}/cookies.txt",
            "-X",
            "POST",
            "-d",
            "user[email]=login@example.test&user[password]=CorrectHorse!1",
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
      System.cmd("pkill", ["-f", "phx.server"], stderr_to_stdout: true)
      Task.shutdown(server_task, :brutal_kill)
    end
  end

  defp seed_login_user!(app_dir, email, password) do
    otp_atom = otp_app_atom(app_dir)
    otp_module = otp_app_module(app_dir)

    script = """
    {:ok, _} = Application.ensure_all_started(:#{otp_atom})
    #{otp_module}.Accounts.register_user(%{email: "#{email}", password: "#{password}"})
    """

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
    ~r/^HTTP\/[\d.]+\s+(\d+)/m
    |> Regex.scan(raw)
    |> Enum.map(fn [_, code] -> String.to_integer(code) end)
  end
end
