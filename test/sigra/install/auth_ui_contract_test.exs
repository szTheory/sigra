defmodule Sigra.Install.AuthUIContractTest do
  use ExUnit.Case, async: true

  @auth_css "priv/templates/sigra.install/core/sigra_auth.css"
  @auth_components "priv/templates/sigra.install/core/sigra_auth_components.ex"
  @login "priv/templates/sigra.install/core/login_html.ex"
  @invitation "priv/templates/sigra.install/organizations/live/invitation_accept_live.ex"
  @modern_auth_templates [
    "priv/templates/sigra.install/core/login_html.ex",
    "priv/templates/sigra.install/core/registration_live.ex",
    "priv/templates/sigra.install/core/registration_html.ex",
    "priv/templates/sigra.install/core/confirmation_live.ex",
    "priv/templates/sigra.install/core/confirmation_html.ex",
    "priv/templates/sigra.install/core/reset_password_live.ex",
    "priv/templates/sigra.install/core/reset_password_html.ex",
    "priv/templates/sigra.install/core/reactivation_live.ex",
    "priv/templates/sigra.install/core/sudo_html.ex",
    "priv/templates/sigra.install/core/settings_live.ex",
    "priv/templates/sigra.install/core/mfa_settings_live.ex",
    "priv/templates/sigra.install/core/mfa_settings_html.ex",
    "priv/templates/sigra.install/core/mfa_challenge_live.ex",
    "priv/templates/sigra.install/core/mfa_challenge_html.ex",
    "priv/templates/sigra.install/core/session_live.ex",
    @invitation
  ]

  test "generated auth CSS exposes the semantic vocabulary without inferred primary actions" do
    css = File.read!(@auth_css)

    for class <- ~w(
      sigra-auth-flow
      sigra-auth-stack
      sigra-auth-cluster
      sigra-auth-section
      sigra-auth-divider
      sigra-auth-disclosure
      sigra-auth-action--primary
      sigra-auth-action--secondary
      sigra-auth-action--ghost
      sigra-auth-action--danger
      sigra-auth-notice--warning
      sigra-auth-status
      sigra-auth-empty
      sigra-auth-code-list
    ) do
      assert css =~ ".#{class}", "missing semantic auth class #{class}"
    end

    refute css =~ ~s(.sigra-auth button[type="submit"])
    refute css =~ ~s(.sigra-auth [type="submit"])
    refute css =~ ".sigra-auth section,"
    assert css =~ ".sigra-auth :where(.btn, button)"
  end

  test "login hierarchy follows passkey-primary configuration and discloses alternatives" do
    source = File.read!(@login)

    assert source =~ "@passkey_primary_enabled"
    assert source =~ "Continue with a passkey"
    assert source =~ "Email me a sign-in link"
    assert source =~ "Other ways to sign in"
    assert source =~ ~s(class="sigra-auth-action sigra-auth-action--primary)
    assert source =~ ~s(class="sigra-auth-action sigra-auth-action--secondary)
    assert source =~ ~s(autocomplete="username webauthn")
    assert source =~ ~s(autocomplete="current-password")
    refute source =~ "canonical enterprise sign-in route"
  end

  test "invitation mismatch has no accept control by construction" do
    source = File.read!(@invitation)

    mismatch =
      source
      |> String.split("defp render_mismatch")
      |> Enum.at(1)
      |> String.split("defp render_invalid")
      |> hd()

    assert mismatch =~ "This invitation belongs to another account"
    assert mismatch =~ "Sign out and switch account"
    refute mismatch =~ ~s(phx-click="accept)
    refute mismatch =~ ~s(phx-submit="accept)
    refute mismatch =~ ~s(id="accept-invitation-button")
  end

  test "auth templates do not cross admin or Tasklane ownership lanes" do
    for path <- Path.wildcard("priv/templates/sigra.install/{core,organizations}/**/*.ex") do
      source = File.read!(path)
      refute source =~ ~r/class="[^"]*\bsg-/, "#{path} crosses into the admin sg-* lane"
      refute source =~ ~r/class="[^"]*\bvt-/, "#{path} crosses into the Tasklane vt-* lane"
    end
  end

  test "modernized auth templates depend only on their semantic class contract" do
    components = File.read!(@auth_components)
    assert components =~ "def sigra_auth_button(assigns)"

    for path <- @modern_auth_templates do
      source = File.read!(path)

      class_tokens =
        ~r/class="([^"]*)"/
        |> Regex.scan(source, capture: :all_but_first)
        |> List.flatten()
        |> Enum.flat_map(&String.split/1)

      residual = Enum.reject(class_tokens, &String.starts_with?(&1, "sigra-auth"))

      assert residual == [],
             "#{path} still relies on utility/framework class tokens: #{inspect(residual)}"

      refute source =~ "<.button",
             "#{path} inherits unscoped host CoreComponents button styles"
    end
  end

  test "audit forms expose one named control per filter and label active state" do
    for path <- [
          "lib/sigra/admin/live/audit_index_live.ex",
          "lib/sigra/admin/live/audit_user_live.ex"
        ] do
      source = File.read!(path)

      assert length(Regex.scan(~r/name="outcome"/, source)) == 1
      assert length(Regex.scan(~r/name="action_prefix"/, source)) == 1

      assert source =~ ~s(aria-label="Audit filter presets") or
               source =~ ~s(aria-label="User audit filter presets")

      assert source =~ "Active filters"
      assert source =~ "preset_path("
      assert source =~ "<.applied_chip"
    end
  end
end
