  # -- API Token Notification (D-62) --

  @doc "Builds a notification email when a new API token is created."
  def api_token_created_email(user, token) do
    html_content = """
    <p style="margin: 0 0 12px 0; font-size: 16px; color: #3f3f46; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "A new API token was created for your account.")}
    </p>
    <div style="margin: 24px 0; padding: 16px; background-color: #f4f4f5; border-radius: 8px;">
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Token name:")}</strong> #{html_escape(token.name)}
      </p>
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Scopes:")}</strong> #{html_escape(Enum.join(token.scopes || [], ", "))}
      </p>
      <p style="margin: 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Created:")}</strong> #{Calendar.strftime(token.inserted_at, "%B %d, %Y at %I:%M %p UTC")}
      </p>
    </div>
    <p style="margin: 0 0 12px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "If you did not create this token, you should revoke it immediately from your account settings.")}
    </p>
    #{cta_button(dgettext("sigra", "Manage API tokens"), "<%= settings_url %>/api-tokens")}
    """

    text_content = """
    #{dgettext("sigra", "A new API token was created for your account.")}

    #{dgettext("sigra", "Token name:")} #{token.name}
    #{dgettext("sigra", "Scopes:")} #{Enum.join(token.scopes || [], ", ")}
    #{dgettext("sigra", "Created:")} #{Calendar.strftime(token.inserted_at, "%B %d, %Y at %I:%M %p UTC")}

    #{dgettext("sigra", "If you did not create this token, you should revoke it immediately:")}
    <%= settings_url %>/api-tokens
    """

    base_email()
    |> to(user.email)
    |> subject(dgettext("sigra", "New API token created"))
    |> html_body(wrap_html(html_content))
    |> text_body(text_content)
  end

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
  defp html_escape(text), do: html_escape(to_string(text))
