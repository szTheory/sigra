defmodule Sigra.Account.EmailChangeTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Account.EmailChange
  alias Ecto.Multi

  setup :verify_on_exit!

  # --- Helpers ---

  defp build_user(attrs \\ %{}) do
    defaults = %{
      id: 1,
      email: "old@example.com",
      pending_email: nil,
      confirmed_at: ~U[2026-01-01 00:00:00Z]
    }

    struct(Sigra.TestUser, Map.merge(defaults, attrs))
  end

  defp base_opts(overrides \\ []) do
    token_struct = %Sigra.TestUserToken{
      token: :crypto.hash(:sha256, "test_token"),
      context: "change:old@example.com",
      sent_to: "old@example.com",
      user_id: 1
    }

    Keyword.merge(
      [
        changeset_fn: fn user, attrs ->
          Ecto.Changeset.change(user, attrs)
        end,
        email_taken_fn: fn _repo, _email -> false end,
        build_email_token_fn: fn _user, _context ->
          {"encoded_test_token", token_struct}
        end,
        token_query_fn: fn _user, _contexts ->
          import Ecto.Query
          from(t in Sigra.TestUserToken, where: false)
        end,
        find_user_by_token_fn: fn _repo, _token -> nil end
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

      opts = base_opts(email_taken_fn: fn _repo, _email -> true end)

      result = EmailChange.request(Sigra.MockRepo, user, "new@example.com", opts)

      assert result == {:error, :email_taken}
    end

    test "returns {:ok, user, encoded_token} on success" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        updated = %{user | pending_email: "new@example.com"}
        {:ok, %{user: updated, token: %{token: "hashed"}}}
      end)

      assert {:ok, updated_user, encoded_token} =
               EmailChange.request(Sigra.MockRepo, user, "NEW@example.com", base_opts())

      assert updated_user.pending_email == "new@example.com"
      assert is_binary(encoded_token)
    end

    test "normalizes the new email before processing" do
      user = build_user()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        {:ok, %{user: %{user | pending_email: "new@example.com"}, token: %{token: "hashed"}}}
      end)

      assert {:ok, _user, _token} =
               EmailChange.request(Sigra.MockRepo, user, " NEW@Example.COM ", base_opts())
    end
  end

  # --- confirm/3 ---

  describe "confirm/3" do
    test "returns :error for invalid token" do
      opts = base_opts(find_user_by_token_fn: fn _repo, _token -> nil end)

      result = EmailChange.confirm(Sigra.MockRepo, "invalid-token", opts)

      assert result == :error
    end

    test "returns {:ok, user} when token is valid" do
      user = build_user(%{pending_email: "new@example.com"})

      opts = base_opts(find_user_by_token_fn: fn _repo, _token -> user end)

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert %Multi{} = multi
        updated = %{user | email: "new@example.com", pending_email: nil}
        {:ok, %{user: updated}}
      end)

      assert {:ok, updated_user} =
               EmailChange.confirm(Sigra.MockRepo, "valid-encoded-token", opts)

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
