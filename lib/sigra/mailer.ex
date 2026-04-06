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

  @doc "Delivers an email to the given recipient."
  @doc since: "0.1.0"
  @callback deliver(to :: String.t(), subject :: String.t(), body :: map()) ::
              {:ok, term()} | {:error, term()}
end
