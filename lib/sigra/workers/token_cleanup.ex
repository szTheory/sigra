defmodule Sigra.Workers.TokenCleanup do
  @moduledoc """
  Oban cron worker for cleaning up expired tokens.

  Runs daily. Deletes tokens older than the maximum TTL for each context:

  - `"confirm"` / `"confirm_code"`: 48 hours
  - `"reset_password"`: 1 hour
  - `"magic_link"`: 15 minutes
  - `"session"`: 60 days

  Also callable directly via `cleanup_expired_tokens/2` for opportunistic
  cleanup during token verification (belt and suspenders).

  ## Threat Mitigation

  Uses conservative max TTL values to ensure only truly expired tokens
  are deleted (T-3-INFRA-02). Never deletes tokens within their TTL.
  """
  use Oban.Worker,
    queue: :sigra_mailer,
    max_attempts: 1

  import Ecto.Query

  @contexts_and_ttls [
    {"confirm", 48 * 60 * 60},
    {"confirm_code", 48 * 60 * 60},
    {"reset_password", 60 * 60},
    {"magic_link", 15 * 60},
    {"session", 60 * 24 * 60 * 60},
    {"api_refresh", 30 * 24 * 60 * 60}
  ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    repo = get_repo(args)
    token_schema = get_token_schema(args)

    cleanup_expired_tokens(repo, token_schema)
    {:ok, :cleaned}
  end

  @doc """
  Deletes expired tokens from the database.

  Called by the Oban worker on schedule and optionally called
  opportunistically during token verification.

  ## Parameters

  - `repo` - The Ecto Repo module
  - `token_schema` - The token Ecto schema module
  """
  @spec cleanup_expired_tokens(module(), module()) :: :ok
  def cleanup_expired_tokens(repo, token_schema) do
    now = DateTime.utc_now()

    Enum.each(@contexts_and_ttls, fn {context, ttl_seconds} ->
      cutoff = DateTime.add(now, -ttl_seconds, :second)

      from(t in token_schema,
        where: t.context == ^context,
        where: t.inserted_at < ^cutoff
      )
      |> repo.delete_all()
    end)

    :ok
  end

  @doc """
  Deletes expired mfa_pending sessions from the database.

  Cleans up sessions with `type = "mfa_pending"` that are older than
  the configured `pending_timeout` (default: 300 seconds / 5 minutes).

  Emits `[:sigra, :mfa, :pending_expired]` telemetry event for each
  batch of expired sessions found.

  ## Parameters

  - `config` - `%Sigra.Config{}` struct with MFA and session configuration
  """
  @spec cleanup_mfa_pending_sessions(Sigra.Config.t()) :: :ok
  def cleanup_mfa_pending_sessions(config) do
    repo = config.repo
    session_schema = Keyword.get(config.session, :session_schema)

    if session_schema do
      pending_timeout = Keyword.get(config.mfa, :pending_timeout, 300)
      cutoff = DateTime.add(DateTime.utc_now(), -pending_timeout, :second)

      # Find expired mfa_pending sessions for telemetry
      expired_sessions =
        from(s in session_schema,
          where: s.type == "mfa_pending" and s.inserted_at < ^cutoff,
          select: s.user_id
        )
        |> repo.all()

      if expired_sessions != [] do
        # Delete them
        from(s in session_schema,
          where: s.type == "mfa_pending" and s.inserted_at < ^cutoff
        )
        |> repo.delete_all()

        # Emit telemetry for each expired session
        Enum.each(expired_sessions, fn user_id ->
          Sigra.Telemetry.event(
            [:sigra, :mfa, :pending_expired],
            %{count: 1},
            %{user_id: user_id}
          )
        end)
      end
    end

    :ok
  end

  @doc """
  Deletes expired sessions from the database.

  Cleans up:
  - Standard sessions older than `absolute_timeout`
  - Remember-me sessions older than `remember_me_max_age`

  ## Parameters

  - `config` - `%Sigra.Config{}` struct with session configuration
  """
  @spec cleanup_expired_sessions(Sigra.Config.t()) :: :ok
  def cleanup_expired_sessions(config) do
    repo = config.repo
    session_schema = Keyword.get(config.session, :session_schema)

    if session_schema do
      absolute_timeout = Keyword.get(config.session, :absolute_timeout, 86_400)
      remember_me_max_age = Keyword.get(config.session, :remember_me_max_age, 5_184_000)

      cutoff_standard = DateTime.add(DateTime.utc_now(), -absolute_timeout, :second)
      cutoff_remember = DateTime.add(DateTime.utc_now(), -remember_me_max_age, :second)

      # Delete standard sessions older than absolute timeout
      from(s in session_schema,
        where: s.type == "standard" and s.inserted_at < ^cutoff_standard
      )
      |> repo.delete_all()

      # Delete remember_me sessions older than remember_me_max_age
      from(s in session_schema,
        where: s.type == "remember_me" and s.inserted_at < ^cutoff_remember
      )
      |> repo.delete_all()
    end

    :ok
  end

  @doc """
  Deletes revoked and expired API tokens past the retention period.

  Retention period defaults to 90 days (configurable via `api_token[:cleanup_retention]`).

  ## Parameters

  - `config` - A `%Sigra.Config{}` struct with API token configuration
  """
  @doc since: "0.7.0"
  @spec cleanup_revoked_api_tokens(Sigra.Config.t()) :: :ok
  def cleanup_revoked_api_tokens(config) do
    api_token_schema = Keyword.get(config.api_token, :api_token_schema)

    if api_token_schema do
      retention = Keyword.get(config.api_token, :cleanup_retention, 90 * 24 * 60 * 60)
      cutoff = DateTime.add(DateTime.utc_now(), -retention, :second)

      # Delete revoked tokens past retention
      from(t in api_token_schema,
        where: not is_nil(t.revoked_at) and t.revoked_at < ^cutoff
      )
      |> config.repo.delete_all()

      # Delete expired tokens past retention
      from(t in api_token_schema,
        where: not is_nil(t.expires_at) and t.expires_at < ^cutoff
      )
      |> config.repo.delete_all()
    end

    :ok
  end

  @doc """
  Deletes superseded JWT refresh tokens past retention period.

  Cleans up tokens with context `"api_refresh"` older than 90 days.

  ## Parameters

  - `repo` - The Ecto Repo module
  - `token_schema` - The token Ecto schema module
  """
  @doc since: "0.7.0"
  @spec cleanup_refresh_tokens(module(), module()) :: :ok
  def cleanup_refresh_tokens(repo, token_schema) do
    cutoff = DateTime.add(DateTime.utc_now(), -(90 * 24 * 60 * 60), :second)

    from(t in token_schema,
      where: t.context == "api_refresh" and t.inserted_at < ^cutoff
    )
    |> repo.delete_all()

    :ok
  end

  defp get_repo(%{"repo" => repo_string}), do: String.to_existing_atom(repo_string)
  defp get_token_schema(%{"token_schema" => schema_string}), do: String.to_existing_atom(schema_string)
end
