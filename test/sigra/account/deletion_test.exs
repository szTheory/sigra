defmodule Sigra.Account.DeletionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Account.Deletion
  alias Ecto.Multi

  setup :verify_on_exit!

  # --- Helpers ---

  defp build_user(attrs \\ %{}) do
    defaults = %{
      id: 1,
      email: "user@example.com",
      hashed_password: "hashed_pw",
      pending_email: nil,
      deleted_at: nil,
      scheduled_deletion_at: nil,
      original_email: nil
    }

    struct(Sigra.TestUser, Map.merge(defaults, attrs))
  end

  defp base_opts(overrides \\ []) do
    Keyword.merge(
      [
        changeset_fn: fn user, attrs ->
          known =
            ~w(deleted_at scheduled_deletion_at original_email pending_email email hashed_password)a

          filtered = Map.take(attrs, known)
          Ecto.Changeset.change(user, filtered)
        end,
        session_store: Sigra.MockSessionStore,
        token_query_fn: fn _user, _contexts ->
          import Ecto.Query
          from(t in Sigra.TestUserToken, where: false)
        end,
        config: [deletion: [strategy: :soft_delete, grace_period_days: 14, cooldown_hours: 24]]
      ],
      overrides
    )
  end

  # --- schedule/3 ---

  describe "schedule/3" do
    test "returns {:ok, user, scheduled_date} on success" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        scheduled = DateTime.add(now, 14 * 86400, :second) |> DateTime.truncate(:second)

        {:ok,
         %{
           user: %{
             user
             | deleted_at: now,
               scheduled_deletion_at: scheduled,
               original_email: user.email,
               pending_email: nil
           }
         }}
      end)

      Sigra.MockSessionStore
      |> expect(:delete_all_for_user, fn _user_id, _opts -> {1, nil} end)

      assert {:ok, updated_user, scheduled_at} =
               Deletion.schedule(Sigra.MockRepo, user, base_opts())

      assert updated_user.deleted_at != nil
      assert updated_user.scheduled_deletion_at != nil
      assert updated_user.original_email == "user@example.com"
      assert updated_user.pending_email == nil
      assert %DateTime{} = scheduled_at
    end

    test "returns {:error, :already_scheduled} when deletion is already scheduled" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]
        })

      result = Deletion.schedule(Sigra.MockRepo, user, base_opts())

      assert result == {:error, :already_scheduled}
    end
  end

  # --- cancel/3 ---

  describe "cancel/3" do
    test "returns {:ok, user} when deletion is scheduled" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z],
          original_email: "user@example.com"
        })

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: %{user | deleted_at: nil, scheduled_deletion_at: nil, original_email: nil}}}
      end)

      assert {:ok, updated_user} = Deletion.cancel(Sigra.MockRepo, user, base_opts())

      assert updated_user.deleted_at == nil
      assert updated_user.scheduled_deletion_at == nil
      assert updated_user.original_email == nil
    end

    test "returns {:error, :not_scheduled} when not scheduled" do
      user = build_user()

      result = Deletion.cancel(Sigra.MockRepo, user, base_opts())

      assert result == {:error, :not_scheduled}
    end
  end

  # --- execute/3 ---

  describe "execute/3" do
    test "returns {:ok, :soft_delete} for soft delete strategy" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]
        })

      # Soft delete: just clear MFA data, no row deletion
      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{}}
      end)

      opts = base_opts(config: [deletion: [strategy: :soft_delete]])

      assert {:ok, :soft_delete} = Deletion.execute(Sigra.MockRepo, user, opts)
    end

    test "returns {:ok, :hard_delete} and deletes user row" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]
        })

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{delete_user: user}}
      end)

      opts = base_opts(config: [deletion: [strategy: :hard_delete]])

      assert {:ok, :hard_delete} = Deletion.execute(Sigra.MockRepo, user, opts)
    end

    test "returns {:ok, :anonymize} and clears PII" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]
        })

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: %{user | email: "deleted_1@deleted.invalid", hashed_password: nil}}}
      end)

      opts = base_opts(config: [deletion: [strategy: :anonymize]])

      assert {:ok, :anonymize} = Deletion.execute(Sigra.MockRepo, user, opts)
    end

    test "returns {:error, :not_scheduled} when user is not scheduled for deletion" do
      user = build_user()

      opts = base_opts(config: [deletion: [strategy: :soft_delete]])

      assert {:error, :not_scheduled} = Deletion.execute(Sigra.MockRepo, user, opts)
    end
  end

  # --- scheduled?/1 ---

  describe "scheduled?/1" do
    test "returns true when both timestamps are set" do
      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: ~U[2026-01-15 00:00:00Z]
        })

      assert Deletion.scheduled?(user) == true
    end

    test "returns false when deleted_at is nil" do
      user = build_user()

      assert Deletion.scheduled?(user) == false
    end

    test "returns false when scheduled_deletion_at is nil but deleted_at is set" do
      user = build_user(%{deleted_at: ~U[2026-01-01 00:00:00Z]})

      assert Deletion.scheduled?(user) == false
    end
  end

  # --- status/1 ---

  describe "status/1" do
    test "returns {:scheduled, days} when scheduled" do
      scheduled_at =
        DateTime.utc_now() |> DateTime.add(7 * 86400, :second) |> DateTime.truncate(:second)

      user =
        build_user(%{
          deleted_at: ~U[2026-01-01 00:00:00Z],
          scheduled_deletion_at: scheduled_at
        })

      assert {:scheduled, days} = Deletion.status(user)
      assert days >= 6 and days <= 7
    end

    test "returns :not_scheduled when no deletion" do
      user = build_user()

      assert Deletion.status(user) == :not_scheduled
    end

    test "returns :deleted when deleted_at set but no scheduled_deletion_at" do
      user = build_user(%{deleted_at: ~U[2026-01-01 00:00:00Z]})

      assert Deletion.status(user) == :deleted
    end
  end

  # --- within_cooldown?/2 ---

  describe "within_cooldown?/2" do
    test "returns true when cancelled_at is within cooldown hours" do
      cancelled_at =
        DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      assert Deletion.within_cooldown?(cancelled_at, 24) == true
    end

    test "returns false when cancelled_at is beyond cooldown hours" do
      cancelled_at =
        DateTime.utc_now() |> DateTime.add(-25 * 3600, :second) |> DateTime.truncate(:second)

      assert Deletion.within_cooldown?(cancelled_at, 24) == false
    end
  end
end
