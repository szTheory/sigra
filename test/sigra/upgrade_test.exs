defmodule Sigra.UpgradeTest do
  # Not async — exercises cwd-dependent fs helpers.
  use ExUnit.Case, async: false

  alias Sigra.Upgrade

  setup do
    original_cwd = File.cwd!()
    tmp = Path.join(System.tmp_dir!(), "sigra_upgrade_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    File.cd!(tmp)

    on_exit(fn ->
      File.cd!(original_cwd)
      File.rm_rf!(tmp)
    end)

    {:ok, tmp: tmp}
  end

  describe "organizations_table_present?/0 (BLOCKER 1)" do
    test "returns false when priv/repo/migrations has no create_organizations migration" do
      File.mkdir_p!(Path.join(["priv", "repo", "migrations"]))
      refute Upgrade.organizations_table_present?()
    end

    test "returns false when priv/repo/migrations does not exist" do
      refute Upgrade.organizations_table_present?()
    end

    test "returns true when a migration file contains `create table(:organizations`" do
      migrations_dir = Path.join(["priv", "repo", "migrations"])
      File.mkdir_p!(migrations_dir)

      File.write!(
        Path.join(migrations_dir, "20250101000000_create_organizations.exs"),
        """
        defmodule MyApp.Repo.Migrations.CreateOrganizations do
          use Ecto.Migration

          def change do
            create table(:organizations, primary_key: false) do
              add :id, :binary_id, primary_key: true
              add :name, :string
            end
          end
        end
        """
      )

      assert Upgrade.organizations_table_present?()
    end
  end

  describe "migrations_to_emit/1 (BLOCKER 1 + backfill gating)" do
    test "returns [] when no organizations table is present" do
      File.mkdir_p!(Path.join(["priv", "repo", "migrations"]))
      assert Upgrade.migrations_to_emit([]) == []
    end

    test "ignores --backfill-personal-orgs when orgs table is absent" do
      File.mkdir_p!(Path.join(["priv", "repo", "migrations"]))
      assert Upgrade.migrations_to_emit(backfill_personal_orgs: true) == []
    end

    test "emits two ALTERs when orgs table is present and no backfill flag" do
      seed_organizations_migration()

      result = Upgrade.migrations_to_emit([])
      assert length(result) == 2
      assert Enum.any?(result, fn {t, _} -> t == "alter_add_owner_user_id.exs" end)
      assert Enum.any?(result, fn {t, _} -> t == "alter_add_personal.exs" end)
    end

    test "emits ALTERs + data migration shim with --backfill-personal-orgs" do
      seed_organizations_migration()

      result = Upgrade.migrations_to_emit(backfill_personal_orgs: true)
      assert length(result) == 3
      assert Enum.any?(result, fn {t, _} -> t == "data_migration.exs" end)
    end

    defp seed_organizations_migration do
      migrations_dir = Path.join(["priv", "repo", "migrations"])
      File.mkdir_p!(migrations_dir)

      File.write!(
        Path.join(migrations_dir, "20250101000000_create_organizations.exs"),
        "create table(:organizations) do\nend\n"
      )
    end
  end

  describe "detect_versions/1 (INFO 8)" do
    setup do
      original = Application.get_env(:sigra, :schema_version)
      Application.delete_env(:sigra, :schema_version)

      on_exit(fn ->
        if original do
          Application.put_env(:sigra, :schema_version, original)
        else
          Application.delete_env(:sigra, :schema_version)
        end
      end)

      :ok
    end

    test "defaults source to a pre-1.0 version when the sentinel config key is absent" do
      {:ok, source, target} = Upgrade.detect_versions([])
      assert is_binary(source)
      assert is_binary(target)
      # source must be <= target so run/1 does not raise as a downgrade
      refute Version.compare(target, source) == :lt
    end

    test "honors --from override" do
      {:ok, "0.0.5", _target} = Upgrade.detect_versions(from: "0.0.5")
    end
  end

  describe "check_git_dirty/1" do
    test "refuses on dirty tree without --allow-dirty" do
      # Create a fresh git repo with an uncommitted file inside our
      # tmp cwd so `git status --porcelain` reports non-empty output.
      {_, 0} = System.cmd("git", ["init", "-q"], stderr_to_stdout: true)
      File.write!("dirty.txt", "hello")

      assert_raise Mix.Error, ~r/Refusing to run/, fn ->
        Upgrade.check_git_dirty([])
      end
    end

    test "allows --allow-dirty to bypass" do
      {_, 0} = System.cmd("git", ["init", "-q"], stderr_to_stdout: true)
      File.write!("dirty.txt", "hello")
      assert :ok = Upgrade.check_git_dirty(allow_dirty: true)
    end

    test "allows clean tree" do
      {_, 0} = System.cmd("git", ["init", "-q"], stderr_to_stdout: true)

      {_, 0} =
        System.cmd("git", ["config", "user.email", "test@example.com"], stderr_to_stdout: true)

      {_, 0} =
        System.cmd("git", ["config", "user.name", "test"], stderr_to_stdout: true)

      assert :ok = Upgrade.check_git_dirty([])
    end
  end

  describe "next_migration_timestamp/2" do
    test "produces monotonically increasing prefixes when called twice in the same second" do
      # Regression test for Phase 25 Bug B: mix sigra.install + mix sigra.upgrade
      # ran back-to-back in the same second collided on migration version.
      # Generator must scan priv/repo/migrations/ and bump past the highest extant
      # timestamp, producing monotonically increasing 14-digit prefixes.
      tmp_dir =
        System.tmp_dir!()
        |> Path.join("sigra_upgrade_ts_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)
      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      # Seed with a known-high timestamp to force the scan-and-bump path
      File.write!(Path.join(tmp_dir, "20260415102050_fake.exs"), "")

      t1 = Sigra.Upgrade.next_migration_timestamp(tmp_dir, 0)
      t2 = Sigra.Upgrade.next_migration_timestamp(tmp_dir, 1)

      assert String.length(t1) == 14
      assert String.length(t2) == 14
      assert t1 =~ ~r/^\d{14}$/
      assert t2 =~ ~r/^\d{14}$/
      assert String.to_integer(t1) > 20_260_415_102_050
      assert String.to_integer(t2) > String.to_integer(t1)
    end
  end

  describe "build_plan/3 regression coverage (WARNING 7 prep + INFO 8)" do
    test "produces an injection with config :sigra, :schema_version marker" do
      plan = Upgrade.build_plan([], "0.0.0", "0.1.0")
      assert [injection] = plan.injections
      assert injection.target == Path.join(["config", "config.exs"])
      assert String.contains?(injection.content, "config :sigra, :schema_version")
      assert String.contains?(injection.content, "0.1.0")
    end

    test "resulting config.exs fragment parses as valid Elixir" do
      plan = Upgrade.build_plan([], "0.0.0", "0.1.0")
      [injection] = plan.injections
      # Must not raise.
      _ = Code.string_to_quoted!(injection.content)
    end
  end
end
