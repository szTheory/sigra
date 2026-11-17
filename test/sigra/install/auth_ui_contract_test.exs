defmodule Sigra.Install.AuthUIContractTest do
  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CopyScan

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

  test "organization templates use the neutral host-auth lane and preserve switch actions" do
    organization_templates = [
      "priv/templates/sigra.install/organizations/live/organization_members_live.ex",
      "priv/templates/sigra.install/organizations/live/organization_settings_live.ex",
      "priv/templates/sigra.install/organizations/live/organizations_live/index.ex",
      "priv/templates/sigra.install/organizations/live/organizations_live/new.ex",
      "priv/templates/sigra.install/organizations/components/org_switcher.ex"
    ]

    for path <- organization_templates do
      source = File.read!(path)

      markup_classes =
        Regex.scan(~r/<[^>]+\bclass="([^"]*)"/s, source, capture: :all_but_first)
        |> List.flatten()

      assert Enum.any?(markup_classes, &String.contains?(&1, "sigra-auth-")),
             "#{path} has no neutral auth styling"

      refute Enum.any?(markup_classes, &String.contains?(&1, "sg-")),
             "#{path} crosses into operator styling"

      refute Enum.any?(markup_classes, &String.contains?(&1, "vt-")),
             "#{path} crosses into Tasklane styling"

      refute Enum.any?(
               markup_classes,
               &Regex.match?(
                 ~r/\b(?:btn-primary|badge-(?:primary|neutral|ghost|secondary))\b/,
                 &1
               )
             ),
             "#{path} still depends on Daisy-style brand variants"
    end

    switcher = File.read!("priv/templates/sigra.install/organizations/components/org_switcher.ex")
    assert switcher =~ "form action={~p\"/organizations/switch\"} method=\"post\""
    assert switcher =~ "name=\"_csrf_token\" value={CSRFProtection.get_csrf_token()}"
    assert switcher =~ "name=\"organization_id\" value={org.id}"
    assert switcher =~ "name=\"return_to\" value={@return_to}"
    assert switcher =~ "@current_scope.active_organization"
  end

  test "demo primary actions and generated switcher mirror use neutral classes" do
    demo_pages = [
      "test/example/lib/example_web/live/confirmation_live.ex",
      "test/example/lib/example_web/live/reset_password_live.ex",
      "test/example/lib/example_web/live/registration_live.ex",
      "test/example/lib/example_web/live/invitation_accept_live.ex",
      "test/example/lib/example_web/controllers/confirmation_html.ex",
      "test/example/lib/example_web/controllers/reset_password_html.ex"
    ]

    primary_actions =
      Enum.sum(
        Enum.map(demo_pages, fn path ->
          source = File.read!(path)
          refute source =~ ~s(class="btn btn-primary)
          length(Regex.scan(~r/class="sigra-auth-action sigra-auth-action--primary/, source))
        end)
      )

    assert primary_actions == 17

    generated =
      File.read!("priv/templates/sigra.install/organizations/components/org_switcher.ex")

    example = File.read!("test/example/lib/example_web/components/org_switcher.ex")

    assert auth_class_values(generated) == auth_class_values(example)

    for source <- [generated, example] do
      assert source =~ "form action={~p\"/organizations/switch\"} method=\"post\""
      assert source =~ "name=\"_csrf_token\" value={CSRFProtection.get_csrf_token()}"
      assert source =~ "name=\"organization_id\" value={org.id}"
      assert source =~ "name=\"return_to\" value={@return_to}"
    end

    components = File.read!("lib/sigra/admin/components.ex")

    assert components =~
             ~s(class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--block">Send magic link)
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

  test "generated core auth copy contains no hard-coded library identity" do
    for path <- @modern_auth_templates do
      source = File.read!(path)

      refute source =~
               ~r/dgettext\(\s*"sigra"\s*,\s*"[^"]*\b(?:Sigra|Kiln)\b/i,
             "#{path} exposes a library identity in translated host-auth copy"

      refute source =~ ~r/\b(?:alt|aria-label|title)="[^"]*\b(?:Sigra|Kiln)\b/i,
             "#{path} exposes a library identity in visible or accessible markup"

      refute source =~
               ~r/<(?:p|span|strong|h[1-6])\b[^>]*>\s*(?:Sigra|Kiln)\b/i,
             "#{path} exposes a library identity in host-auth text"
    end
  end

  test "confirmation feedback uses localized shared live regions and keeps retry state" do
    confirmation = File.read!("priv/templates/sigra.install/core/confirmation_live.ex")
    components = File.read!(@auth_components)

    assert components =~ ~s(role="status")
    assert components =~ ~s(role="alert")
    assert components =~ ~s(aria-live="assertive")
    assert components =~ "@success_message"
    assert components =~ "@error_message"

    assert confirmation =~ "dgettext(\"sigra\", \"Your email has been confirmed.\")"
    assert confirmation =~ "dgettext(\"sigra\", \"Invalid confirmation code. Please try again.\")"
    assert confirmation =~ "clear_flash(:error)"
    assert confirmation =~ "assign(form: to_form(%{\"code\" => code}, as: \"confirmation\"))"
    assert confirmation =~ "assign(live_action: :confirmed)"
    refute confirmation =~ "push_event"
    refute confirmation =~ "JS.focus"
  end

  test "registration renders flash so the enumeration-safe duplicate-email message is visible" do
    registration = File.read!("priv/templates/sigra.install/core/registration_live.ex")

    assert registration =~ "<.sigra_auth_page flash={@flash}>"
    assert registration =~ "If this email is available, your account has been created."
  end

  test "confirmation validation removes only ASCII spaces before strict ASCII digit matching" do
    confirmation = File.read!("priv/templates/sigra.install/core/confirmation_live.ex")
    submit_handler = confirmation |> String.split("defp do_confirm(socket, code)") |> Enum.at(1)

    assert confirmation =~ "def handle_event(\"validate\""
    assert confirmation =~ "{:noreply, assign(socket, form: form)}"
    assert submit_handler =~ "String.replace(code, \" \", \"\")"
    assert submit_handler =~ "~r/\\A[0-9]{6}\\z/"

    assert elem(:binary.match(submit_handler, "Regex.match?"), 0) <
             elem(:binary.match(submit_handler, "Auth.confirm_user_by_code"), 0)
  end

  test "link confirmation handles missing and nonbinary tokens safely" do
    confirmation = File.read!("priv/templates/sigra.install/core/confirmation_live.ex")

    assert confirmation =~ "case socket.assigns[:confirmation_token] do"
    assert confirmation =~ "when is_binary(token) and byte_size(token) > 0"
    assert confirmation =~ "invalid_confirmation_link_response(socket)"
  end

  test "generated copy exception baseline accepts only matched removals" do
    kept = %{scope: "generated", kind: "banned_term", file: "core/login_html.ex", line: "Log in"}
    removed = %{scope: "generated", kind: "banned_term", file: "core/emails.ex", line: "Log in:"}
    added = %{scope: "generated", kind: "banned_term", file: "core/new_auth.ex", line: "Log in"}

    # A legitimate cleanup removes the source hit and its exception entry together.
    assert CopyScan.diff_baseline([kept], [kept]) == [new: [], stale: []]

    # A copied-in exception with no source hit is stale; a new violation without an
    # exception entry is new. Either direction blocks growth or mismatched cleanup.
    assert CopyScan.diff_baseline([kept], [kept, removed]) == [new: [], stale: [removed]]
    assert CopyScan.diff_baseline([kept, added], [kept]) == [new: [added], stale: []]
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

  defp auth_class_values(source) do
    Regex.scan(~r/sigra-auth-[a-zA-Z0-9_-]+/, source)
    |> List.flatten()
    |> Enum.uniq()
  end
end
