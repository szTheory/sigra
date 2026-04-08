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
