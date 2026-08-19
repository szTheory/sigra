defmodule Example.LearningTwinTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.LearningTwin
  alias Example.LearningTwin.Lease
  alias Example.Repo

  @as_of ~U[2026-08-18 12:00:00.123456Z]

  setup do
    old_config = Application.get_env(:example, LearningTwin)
    {_, nil} = Repo.delete_all(Lease)

    on_exit(fn ->
      if old_config do
        Application.put_env(:example, LearningTwin, old_config)
      else
        Application.delete_env(:example, LearningTwin)
      end
    end)

    :ok
  end

  test "uses the seven-day default and accepts a bounded positive configured lease TTL" do
    Application.delete_env(:example, LearningTwin)
    assert {:ok, 604_800} = LearningTwin.lease_ttl_seconds()

    Application.put_env(:example, LearningTwin, offline_lease_ttl_seconds: 60)
    assert {:ok, 60} = LearningTwin.lease_ttl_seconds()
  end

  test "rejects zero, negative, non-integer, and unsafe lease TTL configuration" do
    for ttl <- [0, -1, "60", 604_801] do
      Application.put_env(:example, LearningTwin, offline_lease_ttl_seconds: ttl)
      assert {:error, :invalid_lease_ttl} = LearningTwin.lease_ttl_seconds()
    end
  end

  test "treats the exact microsecond expiry boundary as invalid" do
    expiry = DateTime.add(@as_of, 1, :second)

    assert LearningTwin.lease_valid?(%Lease{expires_at: expiry}, DateTime.add(expiry, -1, :microsecond))
    refute LearningTwin.lease_valid?(%Lease{expires_at: expiry}, expiry)
    refute LearningTwin.lease_valid?(%Lease{expires_at: expiry}, DateTime.add(expiry, 1, :microsecond))
  end

  test "binds active lease and partition authorization to the trusted current scope" do
    user = user_fixture()
    other_user = user_fixture()
    scope = %{user: user}
    other_scope = %{user: other_user}
    lease = lease_fixture(user, "lt_current", DateTime.add(@as_of, 1, :second))

    assert {:ok, ^lease} = LearningTwin.active_lease(scope, as_of: @as_of)
    assert {:ok, ^lease} = LearningTwin.authorize_partition(scope, "lt_current", as_of: @as_of)
    assert {:error, :partition_mismatch} = LearningTwin.authorize_partition(scope, "lt_changed", as_of: @as_of)
    assert {:error, :partition_mismatch} = LearningTwin.authorize_partition(scope, nil, as_of: @as_of)
    assert {:error, :unavailable} = LearningTwin.active_lease(other_scope, as_of: @as_of)
    assert {:error, :unavailable} = LearningTwin.authorize_partition(other_scope, "lt_current", as_of: @as_of)
  end

  test "does not return an expired partition as activatable state" do
    user = user_fixture()
    scope = %{user: user}
    _lease = lease_fixture(user, "lt_expired", @as_of)

    assert {:error, :expired} = LearningTwin.active_lease(scope, as_of: @as_of)
    assert {:error, :expired} = LearningTwin.authorize_partition(scope, "lt_expired", as_of: @as_of)
  end

  defp lease_fixture(user, partition, expires_at) do
    Repo.insert!(%Lease{
      user_id: user.id,
      account_partition: partition,
      issued_at: @as_of,
      expires_at: expires_at
    })
  end
end
