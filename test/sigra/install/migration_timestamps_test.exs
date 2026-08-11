defmodule Sigra.Install.MigrationTimestampsTest do
  use ExUnit.Case, async: true

  alias Sigra.Install.MigrationTimestamps

  defmodule FeatureA do
    @behaviour Sigra.Install.Feature
    @impl true
    def enabled?(_), do: true
    @impl true
    def files(_), do: []
    @impl true
    def injections(_), do: []
    @impl true
    def migrations(_),
      do: [
        {:primary, "a.exs", "a.exs"},
        {:api_token, "b.exs", "b.exs"}
      ]

    @impl true
    def post_instructions(_, _), do: []
  end

  defmodule FeatureB do
    @behaviour Sigra.Install.Feature
    @impl true
    def enabled?(_), do: true
    @impl true
    def files(_), do: []
    @impl true
    def injections(_), do: []
    @impl true
    def migrations(_), do: [{:orgs, "o.exs", "o.exs"}]
    @impl true
    def post_instructions(_, _), do: []
  end

  @base ~U[2026-04-11 12:00:00Z]

  test "single-feature allocation is monotonic within slots" do
    result = MigrationTimestamps.allocate([FeatureA], @base)

    assert result[FeatureA][:primary] == "20260411120000"
    assert result[FeatureA][:api_token] == "20260411120001"
  end

  test "cross-feature allocation respects canonical feature order" do
    result = MigrationTimestamps.allocate([FeatureA, FeatureB], @base)

    assert result[FeatureA][:primary] == "20260411120000"
    assert result[FeatureA][:api_token] == "20260411120001"
    assert result[FeatureB][:orgs] == "20260411120002"
  end

  test "allocation is deterministic (same input produces same output)" do
    a = MigrationTimestamps.allocate([FeatureA, FeatureB], @base)
    b = MigrationTimestamps.allocate([FeatureA, FeatureB], @base)
    assert a == b
  end

  test "timestamps are exactly 14 digits" do
    result = MigrationTimestamps.allocate([FeatureA], @base)

    for {_slot, ts} <- result[FeatureA] do
      assert byte_size(ts) == 14
      assert ts =~ ~r/^\d{14}$/
    end
  end

  test "empty feature list yields empty map" do
    assert MigrationTimestamps.allocate([], @base) == %{}
  end

  test "next_available advances past the highest existing migration version" do
    migrations_dir =
      System.tmp_dir!()
      |> Path.join("sigra_migration_timestamp_#{System.unique_integer([:positive])}")

    File.mkdir_p!(migrations_dir)
    on_exit(fn -> File.rm_rf!(migrations_dir) end)

    File.write!(Path.join(migrations_dir, "20260411120005_create_audit_events.exs"), "")
    File.write!(Path.join(migrations_dir, "not_a_migration.exs"), "")

    assert MigrationTimestamps.next_available(migrations_dir, @base) == "20260411120006"
  end

  test "next_available uses the current timestamp when it is newer" do
    migrations_dir =
      System.tmp_dir!()
      |> Path.join("sigra_migration_timestamp_#{System.unique_integer([:positive])}")

    File.mkdir_p!(migrations_dir)
    on_exit(fn -> File.rm_rf!(migrations_dir) end)

    File.write!(Path.join(migrations_dir, "20260410120000_old.exs"), "")

    assert MigrationTimestamps.next_available(migrations_dir, @base) == "20260411120000"
  end
end
