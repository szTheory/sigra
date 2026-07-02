defmodule Example.Accounts.EmailChangeTest do
  @moduledoc """
  Integration coverage for the email-change request → confirm round-trip against
  the REAL Repo + UserToken schema (the path the mock-based unit tests never
  exercised). Regression guard for 260622-nft: confirmation always failed with
  "invalid or has expired" because the change-token verify query matched the
  context exactly ("change:") and required `sent_to == user.email`.
  """
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Ecto.Query

  alias Example.Accounts
  alias Example.Accounts.User
  alias Example.Accounts.UserToken
  alias Example.Repo

  defp new_email, do: "changed#{System.unique_integer([:positive])}@example.com"

  describe "request_email_change/2 → confirm_email_change/1 round-trip" do
    test "confirming a valid token switches the email and clears pending_email" do
      user = user_fixture()
      target = new_email()

      assert {:ok, _user, token} = Accounts.request_email_change(user, target)

      # Pending state: email unchanged, new address reserved in pending_email.
      reloaded = Repo.get!(User, user.id)
      assert reloaded.email == user.email
      assert reloaded.pending_email == target

      # Confirm: this is the exact call that used to always return :error.
      assert {:ok, confirmed} = Accounts.confirm_email_change(token)
      assert confirmed.email == target
      assert is_nil(confirmed.pending_email)

      persisted = Repo.get!(User, user.id)
      assert persisted.email == target
      assert is_nil(persisted.pending_email)
    end

    test "the confirmation token is single-use" do
      user = user_fixture()
      target = new_email()
      {:ok, _user, token} = Accounts.request_email_change(user, target)

      assert {:ok, _} = Accounts.confirm_email_change(token)
      assert :error = Accounts.confirm_email_change(token)
    end
  end

  describe "confirm_email_change/1 rejects bad tokens" do
    test "a malformed token is rejected" do
      assert :error = Accounts.confirm_email_change("not-a-real-token")
    end

    test "an expired change token is rejected and the email is untouched" do
      user = user_fixture()
      {:ok, _user, token} = Accounts.request_email_change(user, new_email())

      # Backdate the change token past the 1-day TTL.
      two_days_ago = DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)

      {count, _} =
        Repo.update_all(
          from(t in UserToken, where: like(t.context, "change:%")),
          set: [inserted_at: two_days_ago]
        )

      assert count >= 1
      assert :error = Accounts.confirm_email_change(token)
      assert Repo.get!(User, user.id).email == user.email
    end

    test "a non-change token (magic link) cannot confirm an email change" do
      user = user_fixture()
      {encoded, token_struct} = UserToken.build_magic_link_token(user)
      Repo.insert!(token_struct)

      assert :error = Accounts.confirm_email_change(encoded)
    end
  end
end
