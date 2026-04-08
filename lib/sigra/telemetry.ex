defmodule Sigra.Telemetry do
  @moduledoc """
  Telemetry integration for Sigra authentication events.

  Sigra emits telemetry events for all authentication operations, enabling
  observability, monitoring, and custom instrumentation. Attach handlers to
  these events to integrate with your preferred monitoring solution.

  ## Event Catalog

  ### Authentication

    * `[:sigra, :auth, :login, :start | :stop | :exception]` - User login attempts
    * `[:sigra, :auth, :logout, :start | :stop | :exception]` - User logout operations
    * `[:sigra, :auth, :register, :start | :stop | :exception]` - User registration

  ### Token Operations

    * `[:sigra, :token, :generate, :start | :stop | :exception]` - Token generation
    * `[:sigra, :token, :verify, :start | :stop | :exception]` - Token verification

  ### Email Delivery

    * `[:sigra, :email, :deliver, :start | :stop | :exception]` - Email delivery attempts

  ### Confirmation

    * `[:sigra, :confirmation, :verify, :start | :stop | :exception]` - Confirmation verification

  ### Session Lifecycle (span events — :start/:stop/:exception)

    * `[:sigra, :session, :create, :start | :stop | :exception]` - Session creation
    * `[:sigra, :session, :delete, :start | :stop | :exception]` - Session deletion
    * `[:sigra, :session, :sudo, :start | :stop | :exception]` - Sudo mode confirmation

  ### Session Signals (one-shot events)

    * `[:sigra, :session, :revoke_all, :stop]` - All sessions revoked for a user

  ### OAuth (span events)

    * `[:sigra, :oauth, :authorize, :start | :stop | :exception]` - OAuth authorize URL generation
    * `[:sigra, :oauth, :callback, :start | :stop | :exception]` - OAuth callback processing

  ### OAuth Signals (one-shot events)

    * `[:sigra, :oauth, :link, :stop]` - OAuth provider linked to account
    * `[:sigra, :oauth, :unlink, :stop]` - OAuth provider unlinked from account
    * `[:sigra, :oauth, :refresh, :stop]` - OAuth token refreshed
    * `[:sigra, :oauth, :register, :stop]` - New user registered via OAuth
    * `[:sigra, :oauth, :login, :stop]` - Existing user logged in via OAuth

  ### MFA (span events -- :start/:stop/:exception)

    * `[:sigra, :mfa, :enroll, :start | :stop | :exception]` - TOTP enrollment.
      Metadata: `%{user_id: id}`. On stop: `%{user_id: id, result: :success | :failure}`.
    * `[:sigra, :mfa, :verify, :start | :stop | :exception]` - MFA verification.
      Metadata: `%{user_id: id, method: :totp | :backup_code}`. On stop: `%{user_id: id, method: atom, result: :success | :failure, attempts_remaining: integer}`.
    * `[:sigra, :mfa, :disable, :start | :stop | :exception]` - MFA disable.
      Metadata: `%{user_id: id}`. On stop: `%{user_id: id, admin: boolean}`.
    * `[:sigra, :mfa, :backup_codes, :regenerate, :start | :stop | :exception]` - Backup code regeneration.
      Metadata: `%{user_id: id}`.

  ### MFA Signals (one-shot events)

    * `[:sigra, :mfa, :lockout]` - MFA lockout triggered. Metadata: `%{user_id: id, ip: string}`. Log level: `:warning`.
    * `[:sigra, :mfa, :pending_expired]` - mfa_pending session expired. Metadata: `%{user_id: id, ip: string}`. Log level: `:warning`.
    * `[:sigra, :mfa, :trust, :granted]` - Trust cookie granted. Metadata: `%{user_id: id}`.
    * `[:sigra, :mfa, :trust, :revoked_all]` - All trust revoked. Metadata: `%{user_id: id}`.

  ### Security Signals (one-shot events)

    * `[:sigra, :security, :rate_limited]` - Rate limit exceeded
    * `[:sigra, :security, :lockout]` - Account locked after failed attempts
    * `[:sigra, :security, :suspicious_login]` - Login from new IP/device detected
    * `[:sigra, :security, :invalid_credentials]` - Invalid credential submission
    * `[:sigra, :confirmation, :sent]` - Confirmation email dispatched
    * `[:sigra, :reset, :requested]` - Password reset requested
    * `[:sigra, :reset, :completed]` - Password reset completed
    * `[:sigra, :token, :expired]` - Token expired during verification

  ## Metadata Policy

  NEVER included: passwords, hashes, TOTP codes, bearer tokens, OAuth secrets.
  ALWAYS included: user_id (not email), boolean outcome, operation context.

  ## Default Logger

  Call `attach_default_logger/1` to attach a handler that logs all Sigra events
  at a configurable level (default `:info`). This follows the Oban pattern for
  instant structured logging.

      Sigra.Telemetry.attach_default_logger()
      Sigra.Telemetry.attach_default_logger(level: :warning)

  """

  require Logger

  @handler_name "sigra-default-logger"

  # Security events that should be logged at :warning level
  @security_events [
    [:sigra, :security, :rate_limited],
    [:sigra, :security, :lockout],
    [:sigra, :security, :suspicious_login],
    [:sigra, :security, :invalid_credentials],
    [:sigra, :mfa, :lockout],
    [:sigra, :mfa, :pending_expired]
  ]

  @logged_events [
    # Authentication
    [:sigra, :auth, :login, :stop],
    [:sigra, :auth, :logout, :stop],
    [:sigra, :auth, :register, :stop],
    # Token
    [:sigra, :token, :generate, :stop],
    [:sigra, :token, :verify, :stop],
    # Session lifecycle
    [:sigra, :session, :create, :stop],
    [:sigra, :session, :delete, :stop],
    [:sigra, :session, :sudo, :stop],
    [:sigra, :session, :revoke_all, :stop],
    # Security signals
    [:sigra, :security, :rate_limited],
    [:sigra, :security, :lockout],
    [:sigra, :security, :suspicious_login],
    [:sigra, :security, :invalid_credentials],
    # OAuth
    [:sigra, :oauth, :authorize, :stop],
    [:sigra, :oauth, :callback, :stop],
    [:sigra, :oauth, :link, :stop],
    [:sigra, :oauth, :unlink, :stop],
    [:sigra, :oauth, :refresh, :stop],
    [:sigra, :oauth, :register, :stop],
    [:sigra, :oauth, :login, :stop],
    # MFA
    [:sigra, :mfa, :enroll, :stop],
    [:sigra, :mfa, :verify, :stop],
    [:sigra, :mfa, :disable, :stop],
    [:sigra, :mfa, :backup_codes, :regenerate, :stop],
    [:sigra, :mfa, :lockout],
    [:sigra, :mfa, :pending_expired],
    [:sigra, :mfa, :trust, :granted],
    [:sigra, :mfa, :trust, :revoked_all],
    # Email
    [:sigra, :email, :deliver, :stop],
    [:sigra, :email, :deliver, :exception],
    # Confirmation & Reset
    [:sigra, :confirmation, :verify, :stop],
    [:sigra, :confirmation, :sent],
    [:sigra, :reset, :requested],
    [:sigra, :reset, :completed],
    [:sigra, :token, :expired]
  ]

  @doc """
  Execute a function within a telemetry span.

  Wraps `:telemetry.span/3` to emit `:start`, `:stop`, and `:exception` events
  for the given `event_prefix`.

  ## Examples

      Sigra.Telemetry.span([:sigra, :auth, :login], %{user_id: 1}, fn ->
        {:ok, user}
      end)

  """
  @doc since: "0.1.0"
  @spec span([atom()], map(), (-> result)) :: result when result: term()
  def span(event_prefix, metadata, fun) when is_list(event_prefix) and is_map(metadata) and is_function(fun, 0) do
    :telemetry.span(event_prefix, metadata, fn ->
      result = fun.()
      {result, metadata}
    end)
  end

  @doc """
  Emit a one-shot telemetry event.

  Wraps `:telemetry.execute/3` for security signal events and other non-span
  occurrences.

  ## Examples

      Sigra.Telemetry.event([:sigra, :security, :rate_limited], %{count: 1}, %{key: "ip:1.2.3.4"})

  """
  @doc since: "0.1.0"
  @spec event([atom()], map(), map()) :: :ok
  def event(event_name, measurements \\ %{}, metadata \\ %{}) do
    :telemetry.execute(event_name, measurements, metadata)
  end

  @mfa_events [
    [:sigra, :mfa, :enroll, :stop],
    [:sigra, :mfa, :verify, :stop],
    [:sigra, :mfa, :disable, :stop],
    [:sigra, :mfa, :backup_codes, :regenerate, :stop],
    [:sigra, :mfa, :lockout],
    [:sigra, :mfa, :pending_expired],
    [:sigra, :mfa, :trust, :granted],
    [:sigra, :mfa, :trust, :revoked_all]
  ]

  @oauth_events [
    [:sigra, :oauth, :authorize, :stop],
    [:sigra, :oauth, :callback, :stop],
    [:sigra, :oauth, :link, :stop],
    [:sigra, :oauth, :unlink, :stop],
    [:sigra, :oauth, :refresh, :stop],
    [:sigra, :oauth, :register, :stop],
    [:sigra, :oauth, :login, :stop]
  ]

  @doc """
  Returns the list of MFA-specific telemetry event names.

  Useful for attaching custom handlers to all MFA events.
  """
  @doc since: "0.6.0"
  @spec mfa_events() :: [[atom()]]
  def mfa_events, do: @mfa_events

  @doc """
  Returns the list of OAuth-specific telemetry event names.

  Useful for attaching custom handlers to all OAuth events.
  """
  @doc since: "0.5.0"
  @spec oauth_events() :: [[atom()]]
  def oauth_events, do: @oauth_events

  @doc """
  Attach the default Sigra logger handler.

  Attaches a telemetry handler named `"sigra-default-logger"` that logs all
  Sigra `:stop` events and one-shot security events using Elixir's `Logger`.

  ## Options

    * `:level` - The log level to use. Defaults to `:info`.
    * `:filter` - A list of category atoms to filter events (e.g., `[:auth, :security]`).
      When not provided, all events are logged.

  ## Examples

      :ok = Sigra.Telemetry.attach_default_logger()
      {:error, :already_exists} = Sigra.Telemetry.attach_default_logger()

      :ok = Sigra.Telemetry.attach_default_logger(level: :warning)

  """
  @doc since: "0.1.0"
  @spec attach_default_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) do
    :telemetry.attach_many(
      @handler_name,
      @logged_events,
      &__MODULE__.handle_event/4,
      opts
    )
  end

  @doc false
  def handle_event(event, measurements, metadata, opts) do
    level =
      if event in @security_events do
        :warning
      else
        Keyword.get(opts, :level, :info)
      end

    Logger.log(level, fn -> format_event(event, measurements, metadata) end)
  end

  defp format_event(event, measurements, metadata) do
    [_sigra | rest] = event
    label = rest |> Enum.map_join(".", &Atom.to_string/1)
    "[Sigra] #{label} #{inspect(measurements)} #{inspect(metadata)}"
  end
end
