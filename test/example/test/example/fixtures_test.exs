defmodule Example.FixturesTest do
  @moduledoc """
  Plan 10-06 Task 2 Step G: runtime verification of plan 10-02's scenario
  fixtures in a real host app. Plan 10-02 only verified the fixtures at the
  template-string level (content grep); this test actually *runs* each
  scenario against the generated Example.AccountsFixtures module,
  exercising the real database and real Sigra library code paths.

  Mirrors the seven scenarios + dispatcher + FunctionClauseError guard
  from plan 10-02's template tests (test/sigra/auth_fixtures_scenario_test.exs).
  """
  use Example.DataCase, async: true
  import Example.AccountsFixtures
  @moduletag :example_app

  test "anonymous_fixture returns %{conn: conn} only" do
    result = anonymous_fixture()
    assert Map.keys(result) == [:conn]
    assert %Plug.Conn{} = result.conn
  end

  test "authenticated_fixture returns user, session, conn" do
    result = authenticated_fixture()
    assert %Example.Accounts.User{} = result.user
    assert result.session
    assert %Plug.Conn{} = result.conn
  end

  test "mfa_pending_fixture omits :conn (D-07)" do
    result = mfa_pending_fixture()
    refute Map.has_key?(result, :conn)
    assert result.user
    assert result.totp_secret
  end

  test "mfa_complete_fixture returns standard-type session post-challenge" do
    result = mfa_complete_fixture()
    assert result.session.type == "standard"
    assert %Plug.Conn{} = result.conn
    assert result.totp_secret
  end

  test "sudo_fixture session has recent sudo_at" do
    result = sudo_fixture()
    assert result.session.sudo_at
    assert %Plug.Conn{} = result.conn
  end

  test "locked_fixture omits :conn" do
    result = locked_fixture()
    refute Map.has_key?(result, :conn)
    assert result.user.failed_login_attempts == 5
    assert result.user.locked_at
  end

  test "unconfirmed_fixture user has nil confirmed_at" do
    result = unconfirmed_fixture()
    refute Map.has_key?(result, :conn)
    assert is_nil(result.user.confirmed_at)
  end

  test "scenario/2 dispatches to all seven atoms" do
    for name <- [
          :anonymous,
          :authenticated,
          :mfa_pending,
          :mfa_complete,
          :sudo,
          :locked,
          :unconfirmed
        ] do
      assert scenario(name)
    end
  end

  test "scenario/2 raises FunctionClauseError on string input" do
    assert_raise FunctionClauseError, fn ->
      scenario("authenticated")
    end
  end
end
