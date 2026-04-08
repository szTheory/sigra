defmodule Sigra.EmailTemplates do
  @moduledoc """
  Behaviour for generated email template modules.

  The generated `MyApp.Auth.Emails` module implements this behaviour.
  Each callback builds a map with `:to`, `:subject`, and `:body` keys
  that can be delivered via `Sigra.Delivery`.

  ## Security Notification Emails

  These templates are called by the library layer inside `Auth.authenticate/2`
  to ensure security notifications are always sent, regardless of how the
  developer's generated code calls authenticate.
  """

  @doc "Build a suspicious login notification email."
  @doc since: "0.4.0"
  @callback suspicious_login_email(user :: struct(), details :: map()) :: map()

  @doc "Build an account lockout notification email."
  @doc since: "0.4.0"
  @callback lockout_notification_email(user :: struct(), details :: map()) :: map()

  @doc "Build a confirmation email."
  @doc since: "0.3.0"
  @callback confirmation_email(user :: struct(), url :: String.t(), code :: String.t()) :: map()

  @doc "Build a password reset email."
  @doc since: "0.3.0"
  @callback reset_password_email(user :: struct(), url :: String.t()) :: map()

  @doc "Build a magic link email."
  @doc since: "0.3.0"
  @callback magic_link_email(user :: struct(), url :: String.t()) :: map()

  @doc "Build an API token created notification email."
  @doc since: "0.7.0"
  @callback api_token_created_email(user :: struct(), token :: struct()) :: map()
end
