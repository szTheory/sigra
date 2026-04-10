defmodule Example.RegisterLoginLogoutTest do
  @moduledoc """
  Plan 10-06 D-17 #2: register/login/logout happy-path smoke test.

  Exercises the full Accounts context round-trip at the context layer:
  register → generate session token → look up by session token → revoke.
  We intentionally avoid HTTP/LiveView-layer assertions here because the
  generated UI scaffolding (LiveViews, controllers) is not in scope for
  plan 10-06 to fully wire -- the context layer is what Sigra guarantees.
  """
  use Example.DataCase, async: true
  import Example.AccountsFixtures
  @moduletag :example_app

  alias Example.Accounts

  test "register_user creates a user with hashed password" do
    attrs = valid_user_attributes()
    assert {:ok, user} = Accounts.register_user(attrs)
    assert user.email == attrs.email
    assert user.hashed_password
    assert user.hashed_password != attrs.password
    refute user.confirmed_at
  end

  test "register_user rejects duplicate email" do
    attrs = valid_user_attributes()
    assert {:ok, _} = Accounts.register_user(attrs)
    assert {:error, changeset} = Accounts.register_user(attrs)
    assert %Ecto.Changeset{valid?: false} = changeset
    assert [{:email, {_msg, _meta}} | _] = changeset.errors
  end

  test "get_user_by_email_and_password returns user with valid credentials" do
    attrs = valid_user_attributes()
    {:ok, user} = Accounts.register_user(attrs)

    assert %Example.Accounts.User{id: id} =
             Accounts.get_user_by_email_and_password(attrs.email, attrs.password)

    assert id == user.id
  end

  test "get_user_by_email_and_password returns nil for wrong password" do
    attrs = valid_user_attributes()
    {:ok, _user} = Accounts.register_user(attrs)
    assert is_nil(Accounts.get_user_by_email_and_password(attrs.email, "wrong-password"))
  end

  test "generate_user_session_token issues a usable token" do
    {:ok, user} = Accounts.register_user(valid_user_attributes())
    token = Accounts.generate_user_session_token(user)
    assert is_binary(token)
    assert byte_size(token) > 0

    fetched = Accounts.get_user_by_session_token(token)
    assert fetched
    assert fetched.id == user.id
  end

  test "delete_user_session_token invalidates the session (logout)" do
    {:ok, user} = Accounts.register_user(valid_user_attributes())
    token = Accounts.generate_user_session_token(user)
    assert Accounts.get_user_by_session_token(token)

    Accounts.delete_user_session_token(token)
    refute Accounts.get_user_by_session_token(token)
  end
end
