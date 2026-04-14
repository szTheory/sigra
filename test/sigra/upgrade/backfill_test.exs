defmodule Sigra.Upgrade.BackfillTest do
  # Not async — :telemetry handlers attach to the global registry and
  # assertions rely on handler isolation.
  use ExUnit.Case, async: false

  import Mox

  alias Sigra.Upgrade.Backfill

  # Inline test schemas — no real DB. `users_schema` / `orgs_schema`
  # options only need a module atom for query building; with the
  # Mock repo we never actually compile to SQL.
  defmodule TestUser do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "users" do
      field :email, :string
      field :display_name, :string
    end
  end

  defmodule TestOrg do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organizations" do
      field :name, :string
      field :slug, :string
      field :owner_user_id, :binary_id
      field :personal, :boolean, default: false
      timestamps(type: :utc_datetime)
    end
  end

  setup :verify_on_exit!
  setup :set_mox_from_context

  defp build_user(attrs \\ %{}) do
    Map.merge(
      %TestUser{id: Ecto.UUID.generate(), email: "user@example.com", display_name: nil},
      attrs
    )
  end

  describe "run_personal_orgs/2" do
    test "creates personal orgs for users with none" do
      users = [build_user(), build_user(), build_user()]
      test_pid = self()

      Sigra.MockRepo
      |> expect(:all, fn _query -> users end)
      |> expect(:insert_all, fn schema, rows, opts ->
        send(test_pid, {:inserted, schema, rows, opts})
        {length(rows), nil}
      end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 3} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg,
                 batch_size: 1_000
               )

      assert_receive {:inserted, TestOrg, rows, opts}
      assert length(rows) == 3
      assert Enum.all?(rows, & &1.personal)
      assert Enum.all?(rows, &String.starts_with?(&1.slug, "user-"))
      assert Enum.map(rows, & &1.owner_user_id) == Enum.map(users, & &1.id)
      assert opts[:on_conflict] == :nothing

      assert opts[:conflict_target] ==
               {:unsafe_fragment, "(owner_user_id) WHERE personal = true"}
    end

    test "is idempotent on re-run (empty residual set is a no-op)" do
      # First run: zero residual users → no insert_all, immediate :done.
      Sigra.MockRepo
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 0} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )
    end

    test "skips users who already have a personal org (residual selector)" do
      # The NOT EXISTS selector is the contract — we simulate it by
      # returning only the 1 residual user, not the 2 who already have orgs.
      residual = build_user()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [residual] end)
      |> expect(:insert_all, fn _schema, rows, _opts -> {length(rows), nil} end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 1} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )
    end

    test "honors display_name in workspace name when present" do
      user = build_user(%{display_name: "Alice Smith"})
      test_pid = self()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [user] end)
      |> expect(:insert_all, fn _schema, rows, _opts ->
        send(test_pid, {:rows, rows})
        {length(rows), nil}
      end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 1} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )

      assert_receive {:rows, [row]}
      assert row.name == "Alice Smith's Workspace"
    end

    test "falls back to email local-part when display_name is blank" do
      user = build_user(%{display_name: nil, email: "bob@example.com"})
      test_pid = self()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [user] end)
      |> expect(:insert_all, fn _schema, rows, _opts ->
        send(test_pid, {:rows, rows})
        {length(rows), nil}
      end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 1} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )

      assert_receive {:rows, [row]}
      assert row.name == "bob's Workspace"
    end

    test "falls back to \"Personal\" when display_name and email are both absent" do
      user = build_user(%{display_name: nil, email: nil})
      test_pid = self()

      Sigra.MockRepo
      |> expect(:all, fn _query -> [user] end)
      |> expect(:insert_all, fn _schema, rows, _opts ->
        send(test_pid, {:rows, rows})
        {length(rows), nil}
      end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 1} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )

      assert_receive {:rows, [row]}
      assert row.name == "Personal's Workspace"
    end

    test "emits telemetry events per batch" do
      # 2_500 users with batch_size 1_000 → 3 batches (1000, 1000, 500).
      all_users = for _ <- 1..2_500, do: build_user()
      [b1, rest] = Enum.split(all_users, 1_000) |> Tuple.to_list()
      [b2, b3] = Enum.split(rest, 1_000) |> Tuple.to_list()

      test_pid = self()
      handler_id = "backfill-test-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:sigra, :upgrade, :backfill, :batch],
        fn _event, measurements, _meta, _config ->
          send(test_pid, {:batch_event, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> b1 end)
      |> expect(:insert_all, fn _schema, rows, _opts -> {length(rows), nil} end)
      |> expect(:all, fn _query -> b2 end)
      |> expect(:insert_all, fn _schema, rows, _opts -> {length(rows), nil} end)
      |> expect(:all, fn _query -> b3 end)
      |> expect(:insert_all, fn _schema, rows, _opts -> {length(rows), nil} end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 2_500} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg,
                 batch_size: 1_000
               )

      assert_receive {:batch_event, %{batch_index: 0, batch_size: 1_000, inserted: 1_000}}
      assert_receive {:batch_event, %{batch_index: 1, batch_size: 1_000, inserted: 1_000}}
      assert_receive {:batch_event, %{batch_index: 2, batch_size: 500, inserted: 500}}
    end

    test "emits :done telemetry event once at the end" do
      test_pid = self()
      handler_id = "backfill-done-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:sigra, :upgrade, :backfill, :done],
        fn _event, measurements, _meta, _config ->
          send(test_pid, {:done_event, measurements})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      Sigra.MockRepo
      |> expect(:all, fn _query -> [build_user()] end)
      |> expect(:insert_all, fn _schema, _rows, _opts -> {1, nil} end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 1} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg
               )

      assert_receive {:done_event, %{total_processed: 1, batches: 1}}
    end

    test "advances keyset cursor across batches (u.id > last_cursor)" do
      # Two non-empty batches — the second query must be built with the
      # last id from the first batch as the cursor. We can't inspect the
      # query directly, but we can assert the second call receives a
      # different (non-identical) query struct.
      b1 = [build_user(), build_user()]
      b2 = [build_user()]

      test_pid = self()

      Sigra.MockRepo
      |> expect(:all, fn query ->
        send(test_pid, {:first_query, query})
        b1
      end)
      |> expect(:insert_all, fn _schema, _rows, _opts -> {length(b1), nil} end)
      |> expect(:all, fn query ->
        send(test_pid, {:second_query, query})
        b2
      end)
      |> expect(:insert_all, fn _schema, _rows, _opts -> {length(b2), nil} end)
      |> expect(:all, fn _query -> [] end)

      assert {:ok, 3} =
               Backfill.run_personal_orgs(Sigra.MockRepo,
                 users_schema: TestUser,
                 orgs_schema: TestOrg,
                 batch_size: 2
               )

      assert_receive {:first_query, q1}
      assert_receive {:second_query, q2}

      # First query has no u.id > ^cursor clause; second query does.
      # Compare the number of wheres as a proxy (first: 1 NOT EXISTS;
      # second: 1 cursor + 1 NOT EXISTS).
      assert length(q1.wheres) == 1
      assert length(q2.wheres) == 2
    end

    test "raises when required :users_schema is missing" do
      assert_raise NimbleOptions.ValidationError, ~r/users_schema/, fn ->
        Backfill.run_personal_orgs(Sigra.MockRepo,
          orgs_schema: TestOrg,
          batch_size: 1_000
        )
      end
    end

    test "raises when required :orgs_schema is missing" do
      assert_raise NimbleOptions.ValidationError, ~r/orgs_schema/, fn ->
        Backfill.run_personal_orgs(Sigra.MockRepo,
          users_schema: TestUser,
          batch_size: 1_000
        )
      end
    end
  end
end
