if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.AccountDeletion do
    @moduledoc """
    Oban worker for executing scheduled account deletions.

    Scheduled by `Sigra.Account.Deletion.schedule/3` when a grace period is
    configured. The job fires at `scheduled_deletion_at` and applies the
    configured deletion strategy.

    Implements `Sigra.Workers` so the perform callback receives a
    reconstructed, audit-only `%Scope{}` built from the stringified args.

    ## Job Args

    Required by `Sigra.Workers.new/3`:

      * `"organization_id"` - May be `nil`. Resolves to `scope.active_organization`.
      * `"actor_id"`        - May be `nil`. The user who enqueued the job.

    Required by this worker's `perform/2` (belt + suspenders via
    `Sigra.Workers.fetch_arg!/2`):

      * `"user_id"`              - The user ID to delete.
      * `"strategy"`             - Deletion strategy ("soft_delete", "hard_delete", "anonymize").
      * `"repo"`                 - Repo module as a stringified module name.
      * `"user_schema"`          - User schema as a stringified module name.
      * `"scope_module"`         - Host scope module as a stringified module name.
      * `"organization_schema"`  - Organization schema stringified, or `nil`.
      * `"audit_schema"`         - Audit event schema as a stringified module name.
                                   Required for `account.deletion_executed`
                                   emission.

    Optional:

      * `"user_token_schema"`
      * `"session_store"`
      * `"identity_schema"`
      * `"api_token_schema"`
      * `"mfa_credential_schema"`
      * `"backup_code_schema"`

    ## Queue

    Uses `:sigra_lifecycle` queue. Host apps must add this to their Oban config:

        config :my_app, Oban,
          queues: [sigra_lifecycle: 5, sigra_mailer: 10]
    """

    use Oban.Worker,
      queue: :sigra_lifecycle,
      max_attempts: 3,
      unique: [period: 300, keys: [:user_id]]

    @behaviour Sigra.Workers

    alias Sigra.{Account, Account.Deletion}

    @impl Oban.Worker
    def perform(%Oban.Job{args: args}) do
      # 15-02 D-22/D-24: reconstruct a minimal, audit-only scope from the
      # stringified args before delegating to the behaviour callback.

      # Step 1: validate ALL required keys up front via fetch_arg!/2 so
      # hand-built jobs fail with KeyError BEFORE any Module.safe_concat
      # call that could mask the error as ArgumentError (belt + suspenders
      # over Sigra.Workers.new/3 — D-20).
      _organization_id_key = Sigra.Workers.fetch_arg!(args, "organization_id")
      _actor_id_key = Sigra.Workers.fetch_arg!(args, "actor_id")
      _audit_schema_key = Sigra.Workers.fetch_arg!(args, "audit_schema")
      _scope_module_key = Sigra.Workers.fetch_arg!(args, "scope_module")
      _organization_schema_key = Sigra.Workers.fetch_arg!(args, "organization_schema")
      _repo_key = Sigra.Workers.fetch_arg!(args, "repo")
      _user_schema_key = Sigra.Workers.fetch_arg!(args, "user_schema")
      _user_id_key = Sigra.Workers.fetch_arg!(args, "user_id")

      # Step 2: resolve stringified modules (safe for known good keys).
      repo = Module.safe_concat([args["repo"]])
      user_schema = Module.safe_concat([args["user_schema"]])
      scope_module = Module.safe_concat([args["scope_module"]])

      organization_schema =
        case args["organization_schema"] do
          nil -> nil
          mod when is_binary(mod) -> Module.safe_concat([mod])
        end

      user_id = args["user_id"]
      organization_id = args["organization_id"]

      user = repo.get(user_schema, user_id)

      active_org =
        case {organization_schema, organization_id} do
          {nil, _} -> nil
          {_, nil} -> nil
          {mod, id} -> repo.get(mod, id)
        end

      scope = Sigra.Scope.build(scope_module, user, active_organization: active_org)

      perform(scope, args)
    end

    @impl Sigra.Workers
    def perform(_scope, args) do
      repo = Module.safe_concat([Map.fetch!(args, "repo")])
      user_schema = Module.safe_concat([Map.fetch!(args, "user_schema")])
      audit_schema = Module.safe_concat([Map.fetch!(args, "audit_schema")])
      scope_module = Module.safe_concat([Map.fetch!(args, "scope_module")])
      user_id = Map.fetch!(args, "user_id")
      strategy = String.to_existing_atom(Map.fetch!(args, "strategy"))

      case repo.get(user_schema, user_id) do
        nil ->
          {:ok, :user_not_found}

        user ->
          if Deletion.scheduled?(user) do
            exec_opts = [
              config: %{deletion: %{strategy: strategy}},
              changeset_fn: &default_changeset_fn/2,
              token_query_fn: &default_token_query_fn/2,
              audit_schema: audit_schema,
              scope_module: scope_module
            ]

            exec_opts =
              exec_opts
              |> maybe_add_opt(:user_token_schema, args["user_token_schema"])
              |> maybe_add_opt(:session_store, args["session_store"])
              |> maybe_add_opt(:identity_schema, args["identity_schema"])
              |> maybe_add_opt(:api_token_schema, args["api_token_schema"])
              |> maybe_add_opt(:mfa_credential_schema, args["mfa_credential_schema"])
              |> maybe_add_opt(:backup_code_schema, args["backup_code_schema"])

            case Account.execute_deletion(repo, user, exec_opts) do
              {:ok, _strategy} ->
                :ok

              {:error, reason} ->
                {:error, reason}
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
