defmodule Sigra.Delivery do
  @moduledoc """
  Email delivery orchestration.

  Provides three delivery modes:

  - `:async` - Delivers via Oban worker (requires Oban)
  - `:sync` - Delivers synchronously in calling process
  - `:auto` - Auto-detects Oban presence, falls back to sync

  ## Threat Mitigation

  When using async delivery, only `email_type`, `user_id`, and minimal
  metadata (token, code, URL) are stored in the Oban jobs table. The full
  email body is reconstructed at delivery time to avoid storing sensitive
  content in the database (T-3-INFRA-01).
  """

  alias Sigra.OptionalDeps
  alias Sigra.Telemetry

  @doc """
  Delivers email using the configured delivery mode.

  ## Options

  - `:delivery_mode` - `:auto` (default), `:async`, or `:sync`
  - `:mailer` - Module implementing `Sigra.Mailer` (required for `:sync`)
  - `:oban_queue` - Oban queue name (default: `"sigra_mailer"`)
  """
  @spec deliver(atom(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def deliver(email_type, args, opts \\ []) do
    case delivery_mode(opts) do
      :async -> deliver_async(email_type, args, opts)
      :sync -> deliver_sync(email_type, args, opts)
    end
  end

  @doc """
  Delivers email asynchronously via Oban.

  Inserts an Oban job with minimal args (email_type, user_id, token/code/url).
  The full email is reconstructed at delivery time.
  """
  @spec deliver_async(atom(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def deliver_async(email_type, args, opts \\ []) do
    OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
    changeset = build_job(email_type, args, opts)
    oban = Keyword.get(opts, :oban, Oban)

    case oban.insert(changeset) do
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds an Oban job changeset for async email delivery without inserting it.

  Useful for testing and for inspecting the job that would be created.

  ## Returns

  An `Ecto.Changeset` for an `Oban.Job`.
  """
  @spec build_job(atom(), map(), keyword()) :: Ecto.Changeset.t()
  def build_job(email_type, args, opts \\ []) do
    OptionalDeps.ensure_available!(:async_email, async_email_context(opts))
    queue = Keyword.get(opts, :oban_queue, "sigra_mailer")

    job_args = %{
      "email_type" => to_string(email_type),
      "user_id" => Map.fetch!(args, :user_id),
      "token" => Map.get(args, :token),
      "code" => Map.get(args, :code),
      "url" => Map.get(args, :url)
    }

    Sigra.Workers.EmailDelivery.new(job_args, queue: queue)
  end

  @doc """
  Delivers email synchronously in the calling process.

  Calls the configured mailer's `deliver/3` callback directly.

  ## Options

  - `:mailer` - Module implementing `Sigra.Mailer` (required)
  """
  @spec deliver_sync(atom(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def deliver_sync(_email_type, args, opts \\ []) do
    mailer = Keyword.fetch!(opts, :mailer)
    to = Map.fetch!(args, :to)
    subject = Map.fetch!(args, :subject)
    body = Map.fetch!(args, :body)

    Telemetry.span([:sigra, :email, :deliver], %{delivery_method: :sync}, fn ->
      case mailer.deliver(to, subject, body) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp delivery_mode(opts) do
    case Keyword.get(opts, :delivery_mode, :auto) do
      :auto -> if oban_running?(), do: :async, else: :sync
      mode -> mode
    end
  end

  # :auto must only route to :async when Oban is actually supervised in the
  # host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
  # mix.exs without wiring the supervisor would otherwise crash on insert.
  defp oban_running? do
    Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
  end

  defp async_email_context(opts) do
    [
      delivery_mode: :async,
      dependency_loaded?: Keyword.get(opts, :dependency_loaded?, &dependency_loaded?/1)
    ]
  end

  defp dependency_loaded?(spec) do
    Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
  end
end
