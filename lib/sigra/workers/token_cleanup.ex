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
    {"session", 60 * 24 * 60 * 60}
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

  defp get_repo(%{"repo" => repo_string}), do: String.to_existing_atom(repo_string)
  defp get_token_schema(%{"token_schema" => schema_string}), do: String.to_existing_atom(schema_string)
end
