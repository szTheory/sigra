defmodule Sigra.Install.GeneratedCapabilityGatesTest do
  use ExUnit.Case, async: true

  @auth_template "priv/templates/sigra.install/core/auth.ex"
  @user_auth_template "priv/templates/sigra.install/core/user_auth.ex"
  @session_controller "priv/templates/sigra.install/core/session_controller.ex"
  @login_template "priv/templates/sigra.install/core/login_html.ex"
  @mfa_settings_live "priv/templates/sigra.install/core/mfa_settings_live.ex"
  @passkey_routes "priv/templates/sigra.install/passkeys/router_injection.ex"
  @runtime_proof "scripts/ci/install-smoke.sh"

  test "generated context reads independent default-on runtime capabilities" do
    source = read!(@auth_template)

    assert source =~ "Sigra.Config.mfa_enabled?(sigra_config())"
    assert source =~ "Sigra.Config.passkeys_enabled?(sigra_config())"
    assert source =~ "Sigra.Config.enterprise_enabled?(sigra_config())"
    assert source =~ "Keyword.get(legacy_config, :oauth, [])"
    assert source =~ "mfa_capability_enabled?() and Sigra.MFA.enabled?"
    assert source =~ "passkeys_enabled?() and"
  end

  test "generated router plugs fail closed before protected actions" do
    user_auth = read!(@user_auth_template)
    core_routes = read!("lib/sigra/install/features/core.ex")
    passkey_routes = read!(@passkey_routes)

    for plug <-
          ~w(ensure_mfa_capability ensure_passkeys_capability ensure_auth_settings_capability) do
      assert user_auth =~ "def #{plug}(conn, _opts)"
    end

    assert user_auth =~ ~S|send_resp(:not_found, "Not Found")|
    assert core_routes =~ "pipe_through [:browser, :require_mfa_capability]"

    assert core_routes =~
             "pipe_through [:browser, :require_auth_settings_capability, :require_authenticated, :require_sudo]"

    assert passkey_routes =~
             "pipe_through [:browser, :require_passkeys_capability, :redirect_if_user_is_authenticated]"
  end

  test "generated login and settings render from the same capability helpers" do
    controller = read!(@session_controller)
    login = read!(@login_template)
    settings = read!(@mfa_settings_live)

    assert controller =~ "enterprise_sign_in_enabled: Auth.enterprise_sign_in_enabled?()"
    assert controller =~ "if Auth.enterprise_sign_in_enabled?() do"
    assert login =~ ":if={@enterprise_sign_in_enabled}"
    assert settings =~ "mfa_capability_enabled: Auth.mfa_capability_enabled?()"
    assert settings =~ "passkeys_enabled: Auth.passkeys_enabled?()"
    assert settings =~ "if @passkeys_enabled, do: render_passkeys_section(assigns)"
  end

  test "fresh-host proof disables consumer capabilities without disabling OAuth" do
    proof = read!(@runtime_proof)

    assert proof =~ "generated_capability_gate_probe_test.exs"
    assert proof =~ "enterprise: [enabled: false]"
    assert proof =~ "refute html =~ ~s(id=\"enterprise_login_form\")"
    assert proof =~ "post(\"/users/log_in/passkey/options\""
    assert proof =~ "response(404) == \"Not Found\""
    assert proof =~ "Sigra.Config.oauth_enabled?(config)"
    assert proof =~ "Keyword.has_key?(Sigra.Config.oauth_providers(config), :google)"
  end

  defp read!(path), do: path |> Path.expand(File.cwd!()) |> File.read!()
end
