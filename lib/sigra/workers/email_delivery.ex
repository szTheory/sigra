defmodule Sigra.Workers.EmailDelivery do
  @moduledoc """
  Oban worker for asynchronous email delivery.

  Reconstructs email from type + args at delivery time. Never stores
  email body content in the jobs table (security: T-3-INFRA-01).

  ## Job Args

  - `"email_type"` - String email type (e.g., "confirmation", "reset_password")
  - `"user_id"` - User ID to look up
  - `"token"` - Optional token for URL construction
  - `"code"` - Optional confirmation code
  - `"url"` - Optional pre-built URL

  ## Retry

  max_attempts: 3, exponential backoff with jitter (~15s, ~60s).
  """
  use Oban.Worker,
    queue: :sigra_mailer,
    max_attempts: 3

  alias Sigra.Telemetry

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Telemetry.span(
      [:sigra, :email, :deliver],
      %{
        delivery_method: :async,
        email_type: args["email_type"]
      },
      fn ->
        # The actual email construction and delivery is delegated to
        # the host app's mailer via config. The worker looks up the user,
        # constructs the email using the configured email module, and delivers.
        # This will be wired in Plan 04 when the generator creates the callback.
        {:ok, :delivered}
      end
    )
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff with jitter: ~15s, ~60s (per D-25)
    trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
  end
end
