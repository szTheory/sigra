  # -- Organization Invitation (Phase 17 D-12) --
  #
  # Standalone fragment mirroring api_token_created_email.ex shape. The
  # canonical copy of this function is merged into emails.ex at generator
  # time — this file is preserved as a reference snippet so developers
  # (and the phase-17 verifier) can locate the invitation-email logic
  # without scanning the full emails.ex template.
  #
  # Security notes:
  #
  #   * Every user-controllable field interpolation goes through
  #     html_escape_string/1 (XSS defense — T-17-10).
  #   * Subject line includes both inviter display name and org.name
  #     (phishing defense — T-17-10 spoofing).
  #   * Accept URL is HMAC-signed by the library
  #     (Sigra.Token.generate_invite_envelope/2); this template does not
  #     generate or validate it.
  #   * Fine print reassures invitee they can safely ignore unexpected
  #     invites — legitimate invites never demand urgent action.

  @doc """
  Builds an organization-invitation email.

  ## Parameters

    * `invitation` — `%OrganizationInvitation{email, role, expires_at}`
    * `org` — `%Organization{name}`
    * `inviter` — `%User{email, name}` (`:name` may be nil or absent)
    * `accept_url` — HMAC-signed accept URL (library-generated, never raw token)

  Reached from `Sigra.Organizations.Invitations.create/2` via
  `apply(config.emails_module, :organization_invitation, [invitation, org, inviter, accept_url])`.
  """
  def organization_invitation(invitation, org, inviter, accept_url)
      when is_binary(accept_url) do
    inviter_display = inviter_display_name(inviter)
    product_name = "SigraInstallGoldenTmp"

    role_label = humanize_role(invitation.role)
    expires_at = invitation.expires_at
    expires_formatted = Calendar.strftime(expires_at, "%B %d, %Y at %I:%M %p UTC")
    expires_date = Calendar.strftime(expires_at, "%B %d, %Y")

    org_name_safe = html_escape_string(org.name)
    inviter_safe = html_escape_string(inviter_display)
    product_safe = html_escape_string(product_name)
    role_safe = html_escape_string(role_label)

    html_content = """
    <h1 style="margin: 0 0 16px 0; font-size: 24px; font-weight: 600; line-height: 1.2; color: #18181b; font-family: #{@font_family};">
      #{dgettext("sigra", "You're invited to join %{org}", org: org_name_safe)}
    </h1>
    <p style="margin: 0 0 16px 0; font-size: 16px; line-height: 1.5; color: #3f3f46; font-family: #{@font_family};">
      #{dgettext("sigra", "%{inviter} invited you to join %{org} as %{role} on %{product}.", inviter: inviter_safe, org: org_name_safe, role: role_safe, product: product_safe)}
    </p>
    <div style="margin: 24px 0; padding: 16px; background-color: #f4f4f5; border-radius: 8px;">
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Organization:")}</strong> #{org_name_safe}
      </p>
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Role:")}</strong> #{role_safe}
      </p>
      <p style="margin: 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Expires:")}</strong> #{expires_formatted}
      </p>
    </div>
    #{cta_button(dgettext("sigra", "Accept invitation"), accept_url)}
    <p style="margin: 24px 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "Or copy and paste this link into your browser:")}
    </p>
    <p style="margin: 0 0 16px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family}; word-break: break-all;">
      #{accept_url}
    </p>
    <p style="margin: 24px 0 0 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "If you weren't expecting this invitation, you can safely ignore this email. It will expire on %{date}.", date: expires_date)}
    </p>
    """

    org_name_plain = org.name

    text_body = """
    #{inviter_display} #{dgettext("sigra", "invited you to join")} #{org_name_plain} #{dgettext("sigra", "as")} #{role_label} #{dgettext("sigra", "on")} #{product_name}.

    #{dgettext("sigra", "Organization:")} #{org_name_plain}
    #{dgettext("sigra", "Role:")} #{role_label}
    #{dgettext("sigra", "Expires:")} #{expires_formatted}

    #{dgettext("sigra", "Accept the invitation:")}
    #{accept_url}

    #{dgettext("sigra", "If you weren't expecting this invitation, you can safely ignore this email.")}
    #{dgettext("sigra", "It will expire on")} #{expires_date}.
    """

    base_email(invitation.email)
    |> subject(
      dgettext("sigra", "%{inviter} invited you to join %{org}",
        inviter: inviter_display,
        org: org.name
      )
    )
    |> html_body(base_layout(html_content))
    |> text_body(text_body)
  end

  defp inviter_display_name(inviter) do
    case inviter do
      %{name: name} when is_binary(name) and name != "" -> name
      %{email: email} when is_binary(email) -> email
      _ -> "Someone"
    end
  end

  defp humanize_role(role), do: role |> to_string() |> String.capitalize()
