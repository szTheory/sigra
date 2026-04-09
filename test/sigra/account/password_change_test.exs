defmodule Sigra.Account.PasswordChangeTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Account.PasswordChange
  alias Ecto.Multi

  setup :verify_on_exit!

  # --- Helpers ---

  defp build_user(attrs \\ %{}) do
    Map.merge(
      %{
        id: 1,
        email: "user@example.com",
        hashed_password: "hashed_old",
        must_change_password: false
      },
      attrs
    )
  end

  defp base_opts(overrides \\ []) do
    Keyword.merge(
      [
        changeset_fn: fn user, attrs ->
          Ecto.Changeset.change(user, attrs)
        end,
        session_store: Sigra.MockSessionStore
      ],
      overrides
    )
  end

  # --- change/5 ---

  describe "change/5" do
    test "returns {:ok, user} when current password is valid" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: Map.put(user, :hashed_password, "hashed_new")}}
      end)

      Sigra.MockSessionStore
      |> expect(:delete_all_for_user, fn _user_id, _opts -> {1, nil} end)

      changeset_fn = fn _user, attrs ->
        # Simulate valid password changeset
        Ecto.Changeset.change(%Sigra.TestUser{}, attrs)
      end

      assert {:ok, updated_user} =
               PasswordChange.change(
                 Sigra.MockRepo,
                 user,
                 "current_password",
                 %{password: "new_password"},
                 base_opts(changeset_fn: changeset_fn, validate_password_fn: fn _user, _pw -> true end)
               )

      assert updated_user.hashed_password == "hashed_new"
    end

    test "returns {:error, :invalid_password} when current password is wrong" do
      user = build_user()

      result =
        PasswordChange.change(
          Sigra.MockRepo,
          user,
          "wrong_password",
          %{password: "new_password"},
          base_opts(validate_password_fn: fn _user, _pw -> false end)
        )

      assert result == {:error, :invalid_password}
    end
  end

  # --- set_for_oauth_user/4 ---

  describe "set_for_oauth_user/4" do
    test "sets password without current password verification" do
      user = build_user(%{hashed_password: nil})

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: Map.put(user, :hashed_password, "hashed_new")}}
      end)

      changeset_fn = fn _user, attrs ->
        Ecto.Changeset.change(%Sigra.TestUser{}, attrs)
      end

      assert {:ok, updated_user} =
               PasswordChange.set_for_oauth_user(
                 Sigra.MockRepo,
                 user,
                 %{password: "new_password"},
                 base_opts(changeset_fn: changeset_fn)
               )

      assert updated_user.hashed_password == "hashed_new"
    end
  end

  # --- force_change_required?/1 ---

  describe "force_change_required?/1" do
    test "returns true when must_change_password is true" do
      user = build_user(%{must_change_password: true})
      assert PasswordChange.force_change_required?(user) == true
    end

    test "returns false when must_change_password is false" do
      user = build_user(%{must_change_password: false})
      assert PasswordChange.force_change_required?(user) == false
    end

    test "returns false when must_change_password is not set" do
      user = %{id: 1, email: "test@example.com"}
      assert PasswordChange.force_change_required?(user) == false
    end
  end

  # --- require_force_change/2 ---

  describe "require_force_change/2" do
    test "sets must_change_password to true" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:update, fn changeset ->
        assert Ecto.Changeset.get_change(changeset, :must_change_password) == true
        {:ok, Map.put(user, :must_change_password, true)}
      end)

      assert {:ok, updated} = PasswordChange.require_force_change(Sigra.MockRepo, user)
      assert updated.must_change_password == true
    end
  end

  # --- clear_force_change/2 ---

  describe "clear_force_change/2" do
    test "sets must_change_password to false" do
      user = build_user(%{must_change_password: true})

      Sigra.MockRepo
      |> expect(:update, fn changeset ->
        assert Ecto.Changeset.get_change(changeset, :must_change_password) == false
        {:ok, Map.put(user, :must_change_password, false)}
      end)

      assert {:ok, updated} = PasswordChange.clear_force_change(Sigra.MockRepo, user)
      assert updated.must_change_password == false
    end
  end
end
