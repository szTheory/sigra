defmodule Sigra.ApplicationCookieWarningTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Sigra.Application

  describe "maybe_warn_missing_cookie_domain/2" do
    test "emits Logger.warning in :prod when cookie_domain is nil" do
      log =
        capture_log(fn ->
          Application.maybe_warn_missing_cookie_domain(:prod, nil)
        end)

      assert log =~ "cookie_domain is not set"
    end

    test "does NOT warn in :prod when cookie_domain is a string" do
      log =
        capture_log(fn ->
          Application.maybe_warn_missing_cookie_domain(:prod, ".example.com")
        end)

      refute log =~ "cookie_domain is not set"
    end

    test "does NOT warn in :dev regardless of cookie_domain" do
      log_nil =
        capture_log(fn ->
          Application.maybe_warn_missing_cookie_domain(:dev, nil)
        end)

      log_set =
        capture_log(fn ->
          Application.maybe_warn_missing_cookie_domain(:dev, ".example.com")
        end)

      refute log_nil =~ "cookie_domain is not set"
      refute log_set =~ "cookie_domain is not set"
    end

    test "does NOT warn in :test regardless of cookie_domain" do
      log =
        capture_log(fn ->
          Application.maybe_warn_missing_cookie_domain(:test, nil)
        end)

      refute log =~ "cookie_domain is not set"
    end
  end

  describe "generated templates reference cookie_domain at runtime" do
    @user_auth_path "priv/templates/sigra.install/core/user_auth.ex"
    @mfa_challenge_path "priv/templates/sigra.install/core/mfa_challenge_controller.ex"

    test "user_auth.ex defines a runtime remember_me_options/0 function" do
      source = File.read!(@user_auth_path)
      assert source =~ "defp remember_me_options"
      assert source =~ "sigra_config()"
      assert source =~ "config.cookie_domain"
    end

    test "user_auth.ex no longer freezes the domain-less @remember_me_options into put_resp_cookie" do
      source = File.read!(@user_auth_path)
      # Put_resp_cookie must call the runtime function, not the module attribute.
      refute source =~ "put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)"
      assert source =~ "remember_me_options()"
    end

    test "mfa_challenge_controller.ex calls Sigra.MFA.Trust.cookie_opts(config)" do
      source = File.read!(@mfa_challenge_path)
      assert source =~ ~r/Sigra\.MFA\.Trust\.cookie_opts\(config\)/
    end
  end
end
