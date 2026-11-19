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

  test "MFA and auth feedback is localized while machine responses stay literal" do
    mfa_controller =
      File.read!("priv/templates/sigra.install/core/mfa_challenge_controller.ex")

    settings_controller =
      File.read!("priv/templates/sigra.install/core/settings_live.ex")

    session_controller =
      File.read!("priv/templates/sigra.install/core/session_controller.ex")

    error_handler = File.read!("priv/templates/sigra.install/core/error_handler.ex")
    token_controller = File.read!("priv/templates/sigra.install/core/token_controller.ex")

    assert mfa_controller =~
             ~S|dgettext("sigra", "Invalid verification code. %{remaining} attempts remaining.", remaining: remaining)|

    assert settings_controller =~
             ~S|dgettext("sigra", "Your account is scheduled for deletion on %{date}. You can cancel this from your settings.", date: scheduled_date)|

    assert session_controller =~
             ~S|dgettext("sigra", "If your email is registered, you will receive a magic link shortly.")|

    assert error_handler =~ ~S|send_resp(429, "Too many requests. Please try again later.")|
    assert token_controller =~ ~S|detail: "Too many failed attempts."|
    assert token_controller =~ ~S|error: "mfa_locked"|
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

  test "registration renders the same generic response for new and duplicate addresses" do
    registration = File.read!("priv/templates/sigra.install/core/registration_live.ex")

    assert registration =~ "<.sigra_auth_page flash={@flash}>"
    assert registration =~ "registration_response(socket)"
    assert registration =~ "If an account can be created for this email"
    refute registration =~ "assign(trigger_submit: true)"
  end

  test "registration copy uses the sigra domain and the approved sign-in wording" do
    for path <- [
          "priv/templates/sigra.install/core/registration_live.ex",
          "priv/templates/sigra.install/core/registration_html.ex"
        ] do
      source = File.read!(path)

      assert source =~ "dgettext(\"sigra\", \"Sign in\")"
      assert source =~ "dgettext(\"sigra\", \"Already registered?\")"
      assert source =~ "dgettext(\"sigra\", \"Create an account\")"
      assert source =~ "dgettext(\"sigra\", \"Email\")"
      assert source =~ "dgettext(\"sigra\", \"Password\")"
      refute source =~ ~r/>\s*Log in\s*</
      refute source =~ ~r/label="(?:Email|Password)"/
    end

    registration = File.read!("priv/templates/sigra.install/core/registration_live.ex")

    assert registration =~
             "If an account can be created for this email, check for any confirmation instructions, then sign in."
  end

  test "confirmation and reset copy uses the approved sign-in wording" do
    confirmation_live = File.read!("priv/templates/sigra.install/core/confirmation_live.ex")
    confirmation_html = File.read!("priv/templates/sigra.install/core/confirmation_html.ex")
    reset_live = File.read!("priv/templates/sigra.install/core/reset_password_live.ex")
    reset_html = File.read!("priv/templates/sigra.install/core/reset_password_html.ex")

    assert length(Regex.scan(~r/dgettext\("sigra", "Sign in"\)/, confirmation_live)) == 3

    for source <- [confirmation_live, confirmation_html] do
      assert source =~
               "dgettext(\"sigra\", \"Your email was already confirmed. You can sign in below.\")"

      refute source =~ "You can log in below."
    end

    assert confirmation_html =~ "dgettext(\"sigra\", \"Sign in\")"

    for source <- [reset_live, reset_html] do
      assert source =~ "dgettext(\"sigra\", \"Back to sign in\")"
      refute source =~ "Back to log in"
    end

    # These generic responses deliberately do not distinguish known from unknown identities.
    assert File.read!("priv/templates/sigra.install/core/registration_live.ex") =~
             "If an account can be created for this email, check for any confirmation instructions, then sign in."

    assert reset_live =~
             "If your email is in our system, you will receive reset instructions shortly."
  end

  test "generated auth copy guide documents host-owned Gettext catalogs" do
    guide = File.read!("guides/reference/generated-auth-copy.md")

    assert guide =~ "mix gettext.extract"
    assert guide =~ "mix gettext.merge priv/gettext --locale es"
    assert guide =~ "fixed `sigra` Gettext domain"
    assert guide =~ "host's configured Gettext backend loads the catalogs"
    assert guide =~ "does not keep a runtime copy map"
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

  test "auth email actions precede their ignored-request outcomes in both body formats" do
    emails = File.read!("priv/templates/sigra.install/core/emails.ex")

    assert_email_order(
      emails,
      "confirmation_email",
      "Confirm email address",
      "expires in 48 hours"
    )

    assert_email_order(emails, "reset_password_email", "Reset", "you can ignore this email")
    assert_email_order(emails, "magic_link_email", "Log in", "expires in 10 minutes")
    assert_email_order(emails, "oauth_reset_email", "Sign in with", "set a password")

    assert_email_order(
      emails,
      "enterprise_sso_reset_email",
      "Continue with enterprise sign-in",
      "before requesting local account recovery"
    )

    assert_email_order(emails, "suspicious_login_email", "Secure your account", "If this was you")

    assert_email_order(
      emails,
      "passkey_registration_email",
      "Secure your account",
      "If this was you"
    )

    assert_email_order(
      emails,
      "lockout_notification_email",
      "Change your password",
      "If this was you"
    )

    assert_email_order(
      emails,
      "mfa_enabled_email",
      "Change your password",
      "If you did not enable this"
    )

    assert_email_order(
      emails,
      "mfa_disabled_email",
      "Secure your account",
      "was disabled on your"
    )

    assert_email_order(
      emails,
      "backup_code_used_email",
      "Generate new backup codes",
      "A backup code was used"
    )

    assert_email_order(emails, "mfa_lockout_email", "Change your password", "If this was you")

    assert_email_order(
      emails,
      "email_changed_email",
      "Secure your account",
      "has been changed to this address"
    )

    assert_email_order(
      emails,
      "deletion_cancelled_email",
      "Log in to your account",
      "account deletion has been cancelled"
    )

    assert_email_order(
      emails,
      "password_changed_email",
      "Reset your password",
      "account password was changed"
    )

    assert_email_order(
      emails,
      "deletion_scheduled_email",
      "Cancel",
      "permanent deletion on"
    )

    assert_email_order(
      emails,
      "organization_invitation",
      "Accept",
      "safely ignore this email"
    )
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

  defp assert_email_order(source, function_name, action, outcome) do
    function = source |> String.split("def #{function_name}", parts: 2) |> Enum.fetch!(1)
    function = function |> String.split("\n  def ", parts: 2) |> hd()
    html = function |> String.split("html_content = \"\"\"", parts: 2) |> Enum.fetch!(1)
    html = html |> String.split("\"\"\"", parts: 2) |> hd()
    text = function |> String.split("text_body = \"\"\"", parts: 2) |> Enum.fetch!(1)
    text = text |> String.split("\"\"\"", parts: 2) |> hd()

    for body <- [html, text] do
      action_at = :binary.match(body, action)
      outcome_at = :binary.match(body, outcome)

      assert match?({action_index, _} when action_index >= 0, action_at),
             "#{function_name} is missing its action #{inspect(action)}"

      assert match?({outcome_index, _} when outcome_index >= 0, outcome_at),
             "#{function_name} is missing its outcome #{inspect(outcome)}"

      assert elem(action_at, 0) < elem(outcome_at, 0),
             "#{function_name} must place #{inspect(action)} before #{inspect(outcome)}"
    end
  end
end
