if Code.ensure_loaded?(Oban.Worker) do
defmodule Sigra.Workers.AccountDeletion do
  @moduledoc """
  Oban worker for executing scheduled account deletions.

  Scheduled by `Sigra.Account.Deletion.schedule/3` when a grace period is
  configured. The job fires at `scheduled_deletion_at` and applies the
  configured deletion strategy.

  ## Job Args

    * `"user_id"` - The user ID to delete
    * `"strategy"` - The deletion strategy as a string ("soft_delete", "hard_delete", "anonymize")
    * `"repo"` - The repo module as a string (for runtime resolution)
    * `"user_schema"` - The user schema module as a string

  ## Queue

  Uses `:sigra_lifecycle` queue. Host apps must add this to their Oban config:

      config :my_app, Oban,
        queues: [sigra_lifecycle: 5, sigra_mailer: 10]
  """

  use Oban.Worker,
    queue: :sigra_lifecycle,
    max_attempts: 3,
    unique: [period: 300, keys: [:user_id]]

  alias Sigra.Account.Deletion

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id} = args}) do
    repo = Module.safe_concat([args["repo"]])
    user_schema = Module.safe_concat([args["user_schema"]])
    strategy = String.to_existing_atom(args["strategy"])

    case repo.get(user_schema, user_id) do
      nil ->
        {:ok, :user_not_found}

      user ->
        if Deletion.scheduled?(user) do
          opts = [
            config: %{deletion: %{strategy: strategy}},
            changeset_fn: &default_changeset_fn/2,
            token_query_fn: &default_token_query_fn/2
          ]

          opts =
            opts
            |> maybe_add_opt(:user_token_schema, args["user_token_schema"])
            |> maybe_add_opt(:session_store, args["session_store"])
            |> maybe_add_opt(:identity_schema, args["identity_schema"])
            |> maybe_add_opt(:api_token_schema, args["api_token_schema"])
            |> maybe_add_opt(:mfa_credential_schema, args["mfa_credential_schema"])
            |> maybe_add_opt(:backup_code_schema, args["backup_code_schema"])

          case Deletion.execute(repo, user, opts) do
            {:ok, _strategy} -> :ok
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, :not_scheduled}
        end
    end
  end

  defp maybe_add_opt(opts, _key, nil), do: opts

  defp maybe_add_opt(opts, key, module_string) when is_binary(module_string) do
    Keyword.put(opts, key, Module.safe_concat([module_string]))
  end

  defp default_changeset_fn(struct, attrs) do
    Ecto.Changeset.change(struct, attrs)
  end

  defp default_token_query_fn(user, _contexts) do
    import Ecto.Query
    from(t in "user_tokens", where: t.user_id == ^user.id)
  end
end
end
