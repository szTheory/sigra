defmodule Sigra.Account.EmailChangeTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Account.EmailChange
  alias Ecto.Multi

  setup :verify_on_exit!

  # --- Helpers ---

  defp build_user(attrs \\ %{}) do
    Map.merge(
      %{
        id: 1,
        email: "old@example.com",
        pending_email: nil,
        confirmed_at: ~U[2026-01-01 00:00:00Z]
      },
      attrs
    )
  end

  defp base_opts(overrides \\ []) do
    Keyword.merge(
      [
        user_token_schema: Sigra.TestUserToken,
        user_schema: Sigra.TestUser,
        changeset_fn: fn user, attrs ->
          Ecto.Changeset.change(user, attrs)
        end
      ],
      overrides
    )
  end

  # --- request/4 ---

  describe "request/4" do
    test "returns {:error, :same_email} when new email matches current" do
      user = build_user()

      result = EmailChange.request(Sigra.MockRepo, user, "old@example.com", base_opts())

      assert result == {:error, :same_email}
    end

    test "returns {:error, :email_taken} when email is already in use" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:one, fn _query -> %{id: 2, email: "new@example.com"} end)

      result = EmailChange.request(Sigra.MockRepo, user, "new@example.com", base_opts())

      assert result == {:error, :email_taken}
    end

    test "returns {:ok, user, encoded_token} on success" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: Map.put(user, :pending_email, "new@example.com"), token: %{token: "hashed"}}}
      end)

      assert {:ok, updated_user, encoded_token} =
               EmailChange.request(Sigra.MockRepo, user, "NEW@example.com", base_opts())

      assert updated_user.pending_email == "new@example.com"
      assert is_binary(encoded_token)
    end

    test "normalizes the new email before processing" do
      user = build_user()

      # " NEW@Example.COM " should be normalized to "new@example.com"
      # which is different from "old@example.com", so it should proceed
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)
      |> expect(:transaction, fn _multi ->
        {:ok, %{user: Map.put(user, :pending_email, "new@example.com"), token: %{token: "hashed"}}}
      end)

      assert {:ok, _user, _token} =
               EmailChange.request(Sigra.MockRepo, user, " NEW@Example.COM ", base_opts())
    end
  end

  # --- confirm/3 ---

  describe "confirm/3" do
    test "returns :error for invalid token" do
      Sigra.MockRepo
      |> expect(:one, fn _query -> nil end)

      result = EmailChange.confirm(Sigra.MockRepo, "invalid-token", base_opts())

      assert result == :error
    end

    test "returns {:ok, user} when token is valid" do
      user = build_user(%{pending_email: "new@example.com"})

      Sigra.MockRepo
      |> expect(:one, fn _query -> user end)
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        updated = %{user | email: "new@example.com", pending_email: nil}
        {:ok, %{user: updated}}
      end)

      assert {:ok, updated_user} =
               EmailChange.confirm(Sigra.MockRepo, "valid-encoded-token", base_opts())

      assert updated_user.email == "new@example.com"
      assert updated_user.pending_email == nil
    end
  end

  # --- cancel/3 ---

  describe "cancel/3" do
    test "returns {:ok, user} with pending_email cleared" do
      user = build_user(%{pending_email: "new@example.com"})

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        {:ok, %{user: %{user | pending_email: nil}}}
      end)

      assert {:ok, updated_user} =
               EmailChange.cancel(Sigra.MockRepo, user, base_opts())

      assert updated_user.pending_email == nil
    end
  end
end
