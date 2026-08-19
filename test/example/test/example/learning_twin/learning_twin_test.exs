defmodule Example.LearningTwinTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.LearningTwin
  alias Example.LearningTwin.{Lease, ReplayReceipt}
  alias Example.Repo

  @as_of ~U[2026-08-18 12:00:00.123456Z]

  setup do
    old_config = Application.get_env(:example, LearningTwin)
    {_, nil} = Repo.delete_all(ReplayReceipt)
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

    assert LearningTwin.lease_valid?(
             %Lease{expires_at: expiry},
             DateTime.add(expiry, -1, :microsecond)
           )

    refute LearningTwin.lease_valid?(%Lease{expires_at: expiry}, expiry)

    refute LearningTwin.lease_valid?(
             %Lease{expires_at: expiry},
             DateTime.add(expiry, 1, :microsecond)
           )
  end

  test "binds active lease and partition authorization to the trusted current scope" do
    user = user_fixture()
    other_user = user_fixture()
    scope = %{user: user}
    other_scope = %{user: other_user}
    lease = lease_fixture(user, "lt_current", DateTime.add(@as_of, 1, :second))

    assert {:ok, ^lease} = LearningTwin.active_lease(scope, as_of: @as_of)
    assert {:ok, ^lease} = LearningTwin.authorize_partition(scope, "lt_current", as_of: @as_of)

    assert {:error, :partition_mismatch} =
             LearningTwin.authorize_partition(scope, "lt_changed", as_of: @as_of)

    assert {:error, :partition_mismatch} =
             LearningTwin.authorize_partition(scope, nil, as_of: @as_of)

    assert {:error, :unavailable} = LearningTwin.active_lease(other_scope, as_of: @as_of)

    assert {:error, :unavailable} =
             LearningTwin.authorize_partition(other_scope, "lt_current", as_of: @as_of)
  end

  test "does not return an expired partition as activatable state" do
    user = user_fixture()
    scope = %{user: user}
    _lease = lease_fixture(user, "lt_expired", @as_of)

    assert {:error, :expired} = LearningTwin.active_lease(scope, as_of: @as_of)

    assert {:error, :expired} =
             LearningTwin.authorize_partition(scope, "lt_expired", as_of: @as_of)
  end

  test "persists accepted, rejected, and conflict terminal receipts exactly once" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_replay", DateTime.add(DateTime.utc_now(), 1, :hour))

    assert {:ok, accepted} = LearningTwin.replay(scope, replay_params("accepted"), [])
    assert accepted.outcome == "accepted"

    assert {:ok, rejected} =
             LearningTwin.replay(scope, replay_params("rejected", %{"answer" => ""}), [])

    assert rejected.outcome == "rejected"

    assert {:ok, conflict} =
             LearningTwin.replay(scope, replay_params("conflict", %{"base_checkpoint" => "old"}), [])

    assert conflict.outcome == "conflict"
    assert Repo.aggregate(ReplayReceipt, :count) == 3
  end

  test "sequential duplicate returns its original terminal receipt without a second application" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_duplicate", DateTime.add(DateTime.utc_now(), 1, :hour))
    params = replay_params("duplicate")

    assert {:ok, first} = LearningTwin.replay(scope, params, [])
    assert {:ok, second} = LearningTwin.replay(scope, params, [])
    assert %{outcome: first.outcome, terminal_at: first.terminal_at} ==
             %{outcome: second.outcome, terminal_at: second.terminal_at}
    assert Repo.aggregate(ReplayReceipt, :count) == 1
  end

  test "two barrier-released duplicate requests return one stored terminal receipt" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_concurrent", DateTime.add(DateTime.utc_now(), 1, :hour))
    params = replay_params("concurrent")
    parent = self()
    barrier = make_ref()

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          send(parent, {:replay_ready, self(), barrier})

          receive do
            {:replay_go, ^barrier} -> LearningTwin.replay(scope, params, [])
          end
        end)
      end

    ready_pids = for _ <- 1..2, do: receive_ready(barrier)
    Enum.each(ready_pids, &send(&1, {:replay_go, barrier}))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert Enum.all?(results, &match?({:ok, %{outcome: "accepted"}}, &1))
    assert Repo.aggregate(ReplayReceipt, :count) == 1
  end

  test "outer transaction rollback removes terminal receipt and permits a clean retry" do
    user = user_fixture()
    scope = %{user: user}
    lease_fixture(user, "lt_rollback", DateTime.add(DateTime.utc_now(), 1, :hour))
    params = replay_params("rollback")

    assert {:error, :forced} =
             Repo.transaction(fn ->
               assert {:ok, %{outcome: "accepted"}} = LearningTwin.replay(scope, params, [])
               Repo.rollback(:forced)
             end)

    assert Repo.aggregate(ReplayReceipt, :count) == 0
    assert {:ok, %{outcome: "accepted"}} = LearningTwin.replay(scope, params, [])
    assert Repo.aggregate(ReplayReceipt, :count) == 1
  end

  defp lease_fixture(user, partition, expires_at) do
    Repo.insert!(%Lease{
      user_id: user.id,
      account_partition: partition,
      issued_at: @as_of,
      expires_at: expires_at
    })
  end

  defp replay_params(id, overrides \\ %{}) do
    Map.merge(
      %{
        "client_mutation_id" => "mutation-#{id}",
        "idempotency_key" => "idempotency-#{id}",
        "base_checkpoint" => "market-morning-v1",
        "action" => "answer",
        "answer" => "apples"
      },
      overrides
    )
  end

  defp receive_ready(barrier) do
    assert_receive {:replay_ready, pid, ^barrier}
    pid
  end
end
