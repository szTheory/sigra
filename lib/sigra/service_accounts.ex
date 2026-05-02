defmodule Sigra.ServiceAccounts do
  @moduledoc """
  Service-account CRUD, credential rotation, and audit orchestration.

  Phase 93 adds org-scoped machine principals that authenticate through the
  existing JWT bearer path. This module owns the atomic state changes and
  audit composition for those principals.
  """

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Sigra.{Audit, JWT, Token}

  @type scope_like :: map() | struct() | nil

  @doc """
  Creates a service account for the organization in `attrs`.
  """
  @spec create(Sigra.Config.t(), scope_like(), map()) ::
          {:ok, struct()} | {:error, Changeset.t() | atom()}
  def create(config, scope, attrs) when is_map(attrs) do
    schema = service_account_schema!(config)
    changeset = schema.changeset(struct(schema), attrs)

    scope = ensure_user_scope!(scope, "create/3")

    result =
      try do
        Multi.new()
        |> Multi.insert(:service_account, changeset)
        |> append_audit(config, "service_account.create", scope,
          target_type: "service_account",
          target_resolver: &Map.fetch!(&1, :service_account).id,
          organization_id_resolver: &Map.fetch!(&1, :service_account).organization_id,
          metadata: service_account_create_metadata(attrs)
        )
        |> config.repo.transaction()
        |> normalize_multi_result()
      rescue
        e ->
          emit_constraint_or_reraise(e, "service_account.create", :service_account_aborted)
      end

    case result do
      {:ok, %{service_account: service_account}} -> {:ok, service_account}
      other -> other
    end
  end

  @doc """
  Revokes a service account and bumps its token epoch in one transaction.
  """
  @spec revoke(Sigra.Config.t(), scope_like(), struct()) ::
          {:ok, struct()} | {:error, Changeset.t() | atom()}
  def revoke(config, scope, service_account) do
    scope = ensure_user_scope!(scope, "revoke/3")

    changeset =
      service_account
      |> Changeset.change(
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        token_epoch: Map.get(service_account, :token_epoch, 0) + 1
      )

    result =
      try do
        Multi.new()
        |> Multi.update(:service_account, changeset)
        |> append_audit(config, "service_account.revoke", scope,
          target_type: "service_account",
          target_id: service_account.id,
          organization_id: Map.get(service_account, :organization_id),
          metadata: %{
            service_account_id: service_account.id,
            name: Map.get(service_account, :name)
          }
        )
        |> config.repo.transaction()
        |> normalize_multi_result()
      rescue
        e ->
          emit_constraint_or_reraise(e, "service_account.revoke", :service_account_aborted)
      end

    case result do
      {:ok, %{service_account: updated}} -> {:ok, updated}
      other -> other
    end
  end

  @doc """
  Creates a new credential for a service account and returns the plaintext
  secret exactly once.
  """
  @spec create_credential(Sigra.Config.t(), scope_like(), struct(), map()) ::
          {:ok, struct(), String.t()} | {:error, Changeset.t() | atom()}
  def create_credential(config, scope, service_account, attrs \\ %{}) when is_map(attrs) do
    scope = ensure_user_scope!(scope, "create_credential/4")
    schema = credential_schema!(config)
    {raw_secret, _hashed_secret} = Token.generate_hashed_token()

    client_id = build_client_id(config)

    changeset =
      schema.changeset(struct(schema), %{
        client_id: client_id,
        hashed_client_secret: Token.hash_token(raw_secret),
        expires_at: Map.get(attrs, :expires_at),
        service_account_id: service_account.id
      })

    result =
      try do
        Multi.new()
        |> Multi.insert(:credential, changeset)
        |> append_audit(config, "service_account.credential_create", scope,
          target_type: "service_account_credential",
          target_resolver: &Map.fetch!(&1, :credential).id,
          organization_id: Map.get(service_account, :organization_id),
          metadata: %{
            service_account_id: service_account.id,
            client_id_prefix: client_id_prefix(client_id),
            expires_at: Map.get(attrs, :expires_at)
          }
        )
        |> config.repo.transaction()
        |> normalize_multi_result()
      rescue
        e ->
          emit_constraint_or_reraise(
            e,
            "service_account.credential_create",
            :service_account_credential_aborted
          )
      end

    case result do
      {:ok, %{credential: credential}} -> {:ok, credential, raw_secret}
      other -> other
    end
  end

  @doc """
  Revokes a service-account credential.
  """
  @spec revoke_credential(Sigra.Config.t(), scope_like(), struct()) ::
          {:ok, struct()} | {:error, Changeset.t() | atom()}
  def revoke_credential(config, scope, credential) do
    scope = ensure_user_scope!(scope, "revoke_credential/3")

    changeset =
      Changeset.change(
        credential,
        revoked_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      )

    service_account =
      load_service_account(config, Map.get(credential, :service_account_id))

    result =
      try do
        Multi.new()
        |> Multi.update(:credential, changeset)
        |> append_audit(config, "service_account.credential_revoke", scope,
          target_type: "service_account_credential",
          target_id: credential.id,
          organization_id: service_account && Map.get(service_account, :organization_id),
          metadata: %{
            credential_id: credential.id,
            service_account_id: Map.get(credential, :service_account_id),
            client_id_prefix: client_id_prefix(Map.get(credential, :client_id))
          }
        )
        |> config.repo.transaction()
        |> normalize_multi_result()
      rescue
        e ->
          emit_constraint_or_reraise(
            e,
            "service_account.credential_revoke",
            :service_account_credential_aborted
          )
      end

    case result do
      {:ok, %{credential: updated}} -> {:ok, updated}
      other -> other
    end
  end

  @doc """
  Delegates JWT issuance for a verified service-account credential.
  """
  @spec issue_token(Sigra.Config.t(), struct(), struct(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def issue_token(config, service_account, credential, _opts \\ []) do
    try do
      case JWT.generate_service_account_tokens(config, service_account, credential) do
        {:error, _step, reason, _changes} ->
          :telemetry.execute(
            [:sigra, :audit, :log_safe_error],
            %{count: 1},
            %{action: "service_account.token_issued", reason: classify_error(reason)}
          )

          {:error, :service_account_token_issuance_aborted}

        other ->
          other
      end
    rescue
      e ->
        :telemetry.execute(
          [:sigra, :audit, :log_safe_error],
          %{count: 1},
          %{action: "service_account.token_issued", reason: classify_error(e)}
        )

        {:error, :service_account_token_issuance_aborted}
    end
  end

  # CHECK / FK / UNIQUE constraint violations bubble up as either
  # Ecto.ConstraintError (changeset-driven constraints) or Postgrex.Error
  # with a postgres-side error code in the integrity-violation class.
  # Both should classify as :constraint_violation for D-AUD-08 telemetry.
  defp classify_error(%Ecto.ConstraintError{}), do: :constraint_violation

  defp classify_error(%{__struct__: Postgrex.Error, postgres: %{code: code}})
       when code in [
              :check_violation,
              :foreign_key_violation,
              :unique_violation,
              :integrity_constraint_violation,
              :restrict_violation,
              :exclusion_violation,
              :not_null_violation
            ],
       do: :constraint_violation

  defp classify_error(_other), do: :database_error

  @doc """
  Appends the token-issued audit row and the credential last-used update to the
  issuance multi.
  """
  @spec append_token_issued_audit(Multi.t(), Sigra.Config.t(), struct(), struct()) :: Multi.t()
  def append_token_issued_audit(%Multi{} = multi, config, service_account, credential) do
    timestamp = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    credential_changeset =
      Changeset.change(credential, last_used_at: timestamp)

    multi
    |> Multi.update(:credential_last_used, credential_changeset)
    |> Audit.log_multi_safe("service_account.token_issued",
      repo: config.repo,
      audit_schema: audit_schema(config),
      actor_type: "service_account",
      actor_id: service_account.id,
      target_type: "service_account_credential",
      target_id: credential.id,
      organization_id: Map.get(service_account, :organization_id),
      metadata: %{
        service_account_id: service_account.id,
        credential_id: credential.id,
        client_id_prefix: client_id_prefix(Map.get(credential, :client_id)),
        scopes: Map.get(service_account, :scopes, []),
        ip_address: Map.get(service_account, :ip_address)
      }
    )
  end

  @doc """
  Emits a best-effort audit row for JWT verification failures on
  service-account tokens.
  """
  @spec commit_verify_failure_audit(Sigra.Config.t(), map(), atom()) :: :ok
  def commit_verify_failure_audit(config, claims, audit_reason) when is_map(claims) do
    case audit_schema(config) do
      nil ->
        :ok

      audit_schema ->
        multi =
          Multi.new()
          |> Audit.log_multi_safe(
            "api.token_verify.failure",
            repo: config.repo,
            audit_schema: audit_schema,
            actor_type: "service_account",
            actor_id: claims["service_account_id"],
            target_type: "service_account_credential",
            target_id: claims["credential_id"],
            organization_id: claims["org_id"],
            outcome: "failure",
            metadata: %{
              reason: audit_reason,
              service_account_id: claims["service_account_id"],
              credential_id: claims["credential_id"],
              client_id_prefix: client_id_prefix(claims["sub"])
            },
            audit_multi_step: :audit_service_account_verify_failure
          )

        try do
          case config.repo.transaction(multi) do
            {:ok, changes} ->
              Audit.emit_telemetry_from_changes(changes, [:audit_service_account_verify_failure])

            {:error, :audit_service_account_verify_failure, %Changeset{} = _changeset, _} ->
              :telemetry.execute(
                [:sigra, :audit, :log_safe_error],
                %{count: 1},
                %{action: "api.token_verify.failure", reason: :constraint_violation}
              )

            {:error, failed, reason, _} ->
              raise "unexpected Ecto.Multi failure from service-account verify failure audit: " <>
                      "#{inspect(failed)} => #{inspect(reason)}"
          end
        rescue
          e in Ecto.ConstraintError ->
            :telemetry.execute(
              [:sigra, :audit, :log_safe_error],
              %{count: 1},
              %{action: "api.token_verify.failure", reason: :constraint_violation}
            )

            _ = e
            :ok
        end
    end

    :ok
  end

  @doc false
  def fetch_credential_by_client_id(config, client_id) do
    config.repo.get_by(credential_schema!(config), client_id: client_id)
  end

  defp append_audit(multi, config, action, scope, extra) do
    # Use direct field access instead of get_in/2: plain structs (like the
    # generated host Scope module) do not implement the Access behaviour in
    # Elixir 1.19+, so get_in/2 would raise UndefinedFunctionError. Direct
    # dot-notation access with the &./1 safe-navigation idiom avoids this.
    user = Map.get(scope, :user)
    org = Map.get(scope, :active_organization)

    Audit.log_multi_safe(
      multi,
      action,
      Keyword.merge(
        [
          repo: config.repo,
          audit_schema: audit_schema(config),
          actor_id: user && Map.get(user, :id),
          actor_type: "user",
          organization_id: org && Map.get(org, :id),
          effective_user_id: user && Map.get(user, :id)
        ],
        extra
      )
    )
  end

  defp normalize_multi_result({:ok, changes}), do: {:ok, changes}
  defp normalize_multi_result({:error, _step, %Changeset{} = cs, _}), do: {:error, cs}
  defp normalize_multi_result({:error, _step, reason, _}), do: {:error, reason}

  defp emit_constraint_or_reraise(e, action, atom) do
    if integrity_violation?(e) do
      :telemetry.execute(
        [:sigra, :audit, :log_safe_error],
        %{count: 1},
        %{action: action, reason: :constraint_violation}
      )

      {:error, atom}
    else
      # Non-DB-integrity exceptions (RuntimeError, ArgumentError,
      # FunctionClauseError, etc.) are programming errors — surface them
      # via Logger and reraise so callers see real failures instead of a
      # tagged :aborted tuple. __STACKTRACE__ cannot cross a function
      # boundary, so the reraise here loses the original stacktrace; the
      # Logger line preserves the diagnostic context.
      require Logger

      Logger.error(
        "service-account mutation #{action} aborted by unexpected exception: " <>
          "#{inspect(e.__struct__)} #{Exception.message(e)}"
      )

      reraise e, []
    end
  end

  @integrity_codes [
    :check_violation,
    :foreign_key_violation,
    :unique_violation,
    :integrity_constraint_violation,
    :restrict_violation,
    :exclusion_violation,
    :not_null_violation
  ]

  # Postgrex is a runtime dep only via Ecto; we cannot pattern-match its
  # struct module from a function head when MIX_ENV=dev (where Postgrex.Error
  # may not be loaded by the host app). Use a structural map match instead.
  defp integrity_violation?(%Ecto.ConstraintError{}), do: true

  defp integrity_violation?(%{__struct__: Postgrex.Error, postgres: %{code: code}})
       when code in @integrity_codes,
       do: true

  defp integrity_violation?(_), do: false

  defp ensure_user_scope!(%{user: %{id: _}} = scope, _fun), do: scope

  defp ensure_user_scope!(scope, fun) do
    raise ArgumentError, "Sigra.ServiceAccounts.#{fun} requires a scope with a loaded user, got: #{inspect(scope)}"
  end

  defp service_account_schema!(config),
    do: Keyword.fetch!(Map.get(config, :service_accounts, []), :service_account_schema)

  defp credential_schema!(config),
    do: Keyword.fetch!(Map.get(config, :service_accounts, []), :service_account_credential_schema)

  defp audit_schema(config), do: config.audit |> Keyword.get(:audit_schema)

  defp load_service_account(_config, nil), do: nil
  defp load_service_account(config, id), do: config.repo.get(service_account_schema!(config), id)

  defp service_account_create_metadata(attrs) do
    %{
      name: Map.get(attrs, :name) || Map.get(attrs, "name"),
      scopes: Map.get(attrs, :scopes) || Map.get(attrs, "scopes") || [],
      organization_id: Map.get(attrs, :organization_id) || Map.get(attrs, "organization_id"),
      role: Map.get(attrs, :role) || Map.get(attrs, "role")
    }
  end

  defp build_client_id(config) do
    opts = Map.get(config, :service_accounts, [])
    prefix = Keyword.get(opts, :client_id_prefix, "sigra_sa_")
    size = Keyword.get(opts, :client_id_byte_size, 24)
    {raw, _hash} = Token.generate_hashed_token()
    prefix <> String.slice(raw, 0, size)
  end

  defp client_id_prefix(nil), do: nil
  defp client_id_prefix(client_id) when is_binary(client_id), do: String.slice(client_id, 0, 12)
end
