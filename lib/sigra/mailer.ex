defmodule Sigra.Mailer do
  @moduledoc """
  Behaviour for email delivery implementations.

  Sigra uses this behaviour to abstract email delivery, allowing
  host applications to provide their own mailer (typically Swoosh-based).

  ## Default Implementation

  The install generator creates a mailer module in the host application
  that delegates to Swoosh. The library itself does not ship a default
  mailer implementation -- the host app must provide one.

  ## Mox Usage

      Mox.defmock(MockMailer, for: Sigra.Mailer)
  """

  @typedoc """
  Email body content.

  Accepts a plain string (backward compatible), a map with `:html` and `:text`
  keys for multipart emails, or a map with only `:text` for plain-text emails.
  """
  @type body :: String.t() | %{html: String.t(), text: String.t()} | %{text: String.t()}

  @doc "Delivers an email to the given recipient."
  @doc since: "0.1.0"
  @callback deliver(to :: String.t(), subject :: String.t(), body :: body()) ::
              {:ok, term()} | {:error, term()}
end
