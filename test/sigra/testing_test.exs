defmodule Sigra.TestingTest do
  use ExUnit.Case, async: true

  alias Sigra.Testing

  describe "generate_totp_code/1" do
    test "generates a 6-digit TOTP code from a raw secret" do
      secret = NimbleTOTP.secret()
      code = Testing.generate_totp_code(secret)

      assert is_binary(code)
      assert String.length(code) == 6
      assert String.match?(code, ~r/^\d{6}$/)
    end

    test "generates a valid code that NimbleTOTP accepts" do
      secret = NimbleTOTP.secret()
      code = Testing.generate_totp_code(secret)

      assert NimbleTOTP.valid?(secret, code)
    end
  end

  describe "bypass_mfa/1" do
    test "sets session type to :standard on conn" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Test.init_test_session(%{})
        |> Testing.bypass_mfa()

      assert Plug.Conn.get_session(conn, :sigra_session_type) == :standard
    end
  end

  describe "trust_browser/3" do
    test "sets the trust cookie on the conn" do
      secret = :crypto.strong_rand_bytes(64) |> Base.encode64()
      user = %{id: 42}

      conn =
        Plug.Test.conn(:get, "/")
        |> Map.put(:secret_key_base, secret)
        |> Testing.trust_browser(user, secret_key_base: secret, trust_epoch: 0)

      cookie = conn.resp_cookies["_sigra_mfa_trust"]
      assert cookie != nil
      assert cookie.value != nil
      assert is_binary(cookie.value)
    end

    test "produces a cookie verifiable by Trust.verify" do
      secret = :crypto.strong_rand_bytes(64) |> Base.encode64()
      user = %{id: 42}
      trust_epoch = 0
      trust_ttl = 2_592_000

      conn =
        Plug.Test.conn(:get, "/")
        |> Map.put(:secret_key_base, secret)
        |> Testing.trust_browser(user,
          secret_key_base: secret,
          trust_epoch: trust_epoch,
          trust_ttl: trust_ttl
        )

      cookie_value = conn.resp_cookies["_sigra_mfa_trust"].value

      assert {:ok, 42} =
               Sigra.MFA.Trust.verify(secret, cookie_value, 42, trust_epoch, trust_ttl)
    end
  end

  describe "put_bearer_token/2" do
    test "adds Bearer authorization header to conn" do
      conn =
        Plug.Test.conn(:get, "/api/resource")
        |> Testing.put_bearer_token("my_token_123")

      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer my_token_123"]
    end
  end

  describe "put_api_token/2" do
    test "is an alias for put_bearer_token" do
      conn =
        Plug.Test.conn(:get, "/api/resource")
        |> Testing.put_api_token("my_token_123")

      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer my_token_123"]
    end
  end

  describe "assert_scope_denied/1" do
    test "passes when conn has 403 status and is halted" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.send_resp(403, "Forbidden")
        |> Map.put(:halted, true)

      assert Testing.assert_scope_denied(conn) == true
    end

    test "raises when status is not 403" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.send_resp(200, "OK")
        |> Map.put(:halted, true)

      assert_raise ExUnit.AssertionError, ~r/Expected 403/, fn ->
        Testing.assert_scope_denied(conn)
      end
    end

    test "raises when conn is not halted" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.send_resp(403, "Forbidden")
        |> Map.put(:halted, false)

      assert_raise ExUnit.AssertionError, ~r/Expected conn to be halted/, fn ->
        Testing.assert_scope_denied(conn)
      end
    end
  end

  describe "assert_scope_has_org/2" do
    test "passes when scope.active_organization.id matches the expected org id" do
      scope = %{active_organization: %{id: "org-123"}}

      assert Testing.assert_scope_has_org(scope, "org-123") == true
    end

    test "raises when scope.active_organization.id does not match" do
      scope = %{active_organization: %{id: "org-123"}}

      assert_raise ExUnit.AssertionError, ~r/Expected scope.active_organization.id/, fn ->
        Testing.assert_scope_has_org(scope, "org-999")
      end
    end
  end

  describe "assert_membership/3" do
    test "passes when membership matches user, organization, and role" do
      membership = %{user_id: "user-1", organization_id: "org-1", role: :owner}
      user = %{id: "user-1"}
      organization = %{id: "org-1"}

      assert Testing.assert_membership(membership, user, organization: organization, role: :owner) ==
               true
    end

    test "raises with a clear message when the membership shape drifts" do
      membership = %{user_id: "user-1", organization_id: "org-2", role: :member}
      user = %{id: "user-1"}
      organization = %{id: "org-1"}

      assert_raise ExUnit.AssertionError, ~r/Expected membership.organization_id/, fn ->
        Testing.assert_membership(membership, user, organization: organization, role: :owner)
      end
    end
  end

  describe "module exports API token helpers" do
    test "create_api_token/3 is exported" do
      assert function_exported?(Testing, :create_api_token, 3)
    end

    test "put_bearer_token/2 is exported" do
      assert function_exported?(Testing, :put_bearer_token, 2)
    end

    test "put_api_token/2 is exported" do
      assert function_exported?(Testing, :put_api_token, 2)
    end

    test "assert_token_revoked/2 is exported" do
      assert function_exported?(Testing, :assert_token_revoked, 2)
    end

    test "assert_scope_denied/1 is exported" do
      assert function_exported?(Testing, :assert_scope_denied, 1)
    end

    test "assert_scope_has_org/2 is exported" do
      assert function_exported?(Testing, :assert_scope_has_org, 2)
    end

    test "assert_membership/3 is exported" do
      assert function_exported?(Testing, :assert_membership, 3)
    end

    test "expired_api_token_fixture/3 is exported" do
      assert function_exported?(Testing, :expired_api_token_fixture, 3)
    end

    test "revoked_api_token_fixture/3 is exported" do
      assert function_exported?(Testing, :revoked_api_token_fixture, 3)
    end

    test "scoped_api_token_fixture/4 is exported" do
      assert function_exported?(Testing, :scoped_api_token_fixture, 4)
    end
  end

  describe "module exports JWT helpers" do
    test "generate_jwt/3 is exported" do
      assert function_exported?(Testing, :generate_jwt, 3)
    end

    test "expired_jwt/3 is exported" do
      assert function_exported?(Testing, :expired_jwt, 3)
    end

    test "jwt_with_scopes/3 is exported" do
      assert function_exported?(Testing, :jwt_with_scopes, 3)
    end
  end

  describe "module exports MFA helpers" do
    test "setup_totp/2 is exported" do
      assert function_exported?(Testing, :setup_totp, 2)
    end

    test "generate_totp_code/1 is exported" do
      assert function_exported?(Testing, :generate_totp_code, 1)
    end

    test "create_backup_codes/2 is exported" do
      assert function_exported?(Testing, :create_backup_codes, 2)
    end

    test "bypass_mfa/1 is exported" do
      assert function_exported?(Testing, :bypass_mfa, 1)
    end

    test "simulate_mfa_lockout/2 is exported" do
      assert function_exported?(Testing, :simulate_mfa_lockout, 2)
    end

    test "assert_mfa_enabled/2 is exported" do
      assert function_exported?(Testing, :assert_mfa_enabled, 2)
    end

    test "assert_mfa_disabled/2 is exported" do
      assert function_exported?(Testing, :assert_mfa_disabled, 2)
    end

    test "trust_browser/3 is exported" do
      assert function_exported?(Testing, :trust_browser, 3)
    end
  end
end
