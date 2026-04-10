defmodule Example.InstallCompileTest do
  @moduledoc """
  Plan 10-06 smoke test: verifies that `mix sigra.install` generated code loads
  cleanly and the core public API surface is present.

  This test is the "did the installer work" gate for D-17 #1. If this test
  fails, downstream smoke tests cannot run.
  """
  use ExUnit.Case, async: true
  @moduletag :example_app

  test "Sigra-generated core modules are loaded" do
    assert Code.ensure_loaded?(Example.Accounts)
    assert Code.ensure_loaded?(Example.Accounts.User)
    assert Code.ensure_loaded?(Example.Accounts.UserToken)
    assert Code.ensure_loaded?(Example.Accounts.UserSession)
    assert Code.ensure_loaded?(Example.Accounts.UserMFACredential)
    assert Code.ensure_loaded?(Example.Accounts.UserBackupCode)
    assert Code.ensure_loaded?(Example.Accounts.AuditEvent)
    assert Code.ensure_loaded?(ExampleWeb.UserAuth)
    assert Code.ensure_loaded?(ExampleWeb.ConnCaseHelpers)
    assert Code.ensure_loaded?(Example.AccountsFixtures)
  end

  test "Accounts context exposes canonical Sigra public API" do
    assert function_exported?(Example.Accounts, :register_user, 1)
    assert function_exported?(Example.Accounts, :get_user_by_email, 1)
    assert function_exported?(Example.Accounts, :generate_user_session_token, 1)
    assert function_exported?(Example.Accounts, :sigra_config, 0)
    assert function_exported?(Example.Accounts, :reset_user_password, 2)
  end

  test "Sigra config struct has cookie_domain key (Phase 10 D-08)" do
    config = Example.Accounts.sigra_config()
    assert Map.has_key?(config, :cookie_domain)
  end

  test "Sigra library modules used by generated code are loaded" do
    assert Code.ensure_loaded?(Sigra.Auth)
    assert Code.ensure_loaded?(Sigra.Testing)
    assert Code.ensure_loaded?(Sigra.Config)
    assert Code.ensure_loaded?(Sigra.MFA)
  end
end
