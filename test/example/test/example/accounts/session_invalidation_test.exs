defmodule Example.Accounts.SessionInvalidationTest do
  @moduledoc """
  Integration coverage for session invalidation on password-change and
  account-deletion against the REAL `Sigra.SessionStores.Ecto` store (wired in
  `Example.Accounts.sigra_config/0`).

  Regression guard for 260623-j59 (sibling of 260622-nft's email-change fix):
  `password_change.ex` and `deletion.ex` invalidated sessions by calling
  `session_store.delete_all_for_user/2` WITHOUT threading `:repo` +
  `:session_schema` (passed through `:session_store_opts`). The Ecto store does
  `Keyword.fetch!(opts, :repo)`, so the real store raised `ArgumentError` the
  moment it ran — only mock-based unit tests ever exercised these paths.

  Each test's first assertion (the `{:ok, ...}` match) is the regression guard:
  pre-fix, `delete_all_for_user` raises and the call never returns `{:ok, ...}`.
  """
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Ecto.Query

  alias Example.Accounts
  alias Example.Accounts.User
  alias Example.Accounts.UserSession
  alias Example.Repo

  defp session_count(user) do
    Repo.aggregate(from(s in UserSession, where: s.user_id == ^user.id), :count)
  end

  describe "change_password/3 sign-out-other-sessions" do
    test "deletes other sessions, preserves the current one, and changes the password" do
      user = user_fixture()
      current_password = valid_user_password()
      new_password = "brand new password!!"

      # Two "other" sessions that must be revoked.
      _other1 = session_fixture(user)
      _other2 = session_fixture(user)

      # The "current" session. The Ecto store matches `except_token` directly
      # against `hashed_token` (see Sigra.SessionStores.Ecto.delete_all_for_user/2,
      # `s.hashed_token != ^except_token`), so we control a known raw token and
      # pass its SHA-256 HASH as `except_token` — that is the store's contract.
      raw = :crypto.strong_rand_bytes(32)
      current_hashed = :crypto.hash(:sha256, raw)
      current_session = session_fixture(user, %{hashed_token: current_hashed})

      assert session_count(user) == 3

      # Regression guard: pre-fix this raises ArgumentError from
      # Keyword.fetch!(opts, :repo) and never returns {:ok, _}.
      assert {:ok, updated} =
               Sigra.Auth.change_password(
                 Accounts.sigra_config(),
                 user,
                 current_password,
                 %{password: new_password, password_confirmation: new_password},
                 changeset_fn: &User.password_changeset(&1, &2),
                 except_token: current_hashed
               )

      # Exactly the current session survives.
      assert session_count(user) == 1
      [survivor] = Repo.all(from(s in UserSession, where: s.user_id == ^user.id))
      assert survivor.id == current_session.id
      assert survivor.hashed_token == current_hashed

      # The password actually changed.
      persisted = Repo.get!(User, updated.id)
      assert User.valid_password?(persisted, new_password)
      refute User.valid_password?(persisted, current_password)
    end
  end

  describe "schedule_deletion revokes all sessions" do
    test "scheduling account deletion revokes ALL of the user's sessions" do
      user = user_fixture()

      _s1 = session_fixture(user)
      _s2 = session_fixture(user)
      _s3 = session_fixture(user)

      assert session_count(user) == 3

      # Regression guard: pre-fix this raises ArgumentError from
      # Keyword.fetch!(opts, :repo) and never returns {:ok, _, _}.
      assert {:ok, _user, _scheduled_date} = Accounts.schedule_deletion(user)

      assert session_count(user) == 0
    end
  end
end
