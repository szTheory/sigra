defmodule Sigra.Passkeys do
  @moduledoc """
  Public passkey context for registration and credential management helpers.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Sigra.Passkeys.{Authentication, Credential, Registration}

  @config_cache_key {__MODULE__, :config}
  @runtime_timeout_range 1_000..120_000
  @schema_opts [
    user_passkey_schema: [type: {:or, [:atom, nil]}, default: nil]
  ]

  @register_opts_schema @schema_opts ++
                          [
                            max_per_user: [type: :pos_integer, required: false]
                          ]

  @authenticate_opts_schema @schema_opts ++
                              [
                                sign_count_policy: [
                                  type: {:in, [:warn, :require_reauth, :revoke]},
                                  required: false
                                ]
                              ]

  @rename_opts_schema @schema_opts

  @delete_opts_schema @schema_opts

  defmodule DeleteResult do
    @moduledoc """
    Outcome metadata for a passkey deletion.
    """

    @enforce_keys [:credential, :deleted_last_passkey?, :remaining_passkeys]
    defstruct [:credential, :deleted_last_passkey?, :remaining_passkeys]

    @type t :: %__MODULE__{
            credential: Sigra.Passkeys.Credential.t(),
            deleted_last_passkey?: boolean(),
            remaining_passkeys: non_neg_integer()
          }
  end

  @known_transports ~w(usb nfc ble internal hybrid)

  @spec config() :: Sigra.Config.t()
  def config do
    case :persistent_term.get(@config_cache_key, :not_loaded) do
      %Sigra.Config{} = config ->
        config

      :not_loaded ->
        runtime_config = load_runtime_config!()
        :persistent_term.put(@config_cache_key, runtime_config)
        runtime_config
    end
  end

  @spec reset_cached_config() :: :ok
  def reset_cached_config do
    :persistent_term.erase(@config_cache_key)
    :ok
  end

  @spec rate_limit_ceremony(Sigra.Config.t(), user_id :: term(), :registration | :authentication) ::
          :ok | {:error, :rate_limited, %{retry_after_ms: pos_integer()}}
  def rate_limit_ceremony(%Sigra.Config{} = config, user_id, ceremony)
      when ceremony in [:registration, :authentication] do
    limiter = config.rate_limiting[:limiter]
    rate_limit = config.passkeys[:ceremony_rate_limit] || []
    key = ceremony_rate_limit_key(ceremony, user_id)
    limit = Keyword.fetch!(rate_limit, :limit)
    window_ms = Keyword.fetch!(rate_limit, :window_ms)

    case limiter do
      nil ->
        :ok

      module ->
        case module.check_rate(key, limit, window_ms) do
          {:allow, _count} ->
            :ok

          {:deny, retry_after_ms} ->
            {:error, :rate_limited, %{retry_after_ms: retry_after_ms}}
        end
    end
  end

  @spec register(Sigra.Config.t(), user :: map(), map(), keyword()) ::
          {:ok, Credential.t()}
          | {:error, :passkey_cap_reached, %{count: non_neg_integer(), cap: pos_integer()}}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def register(%Sigra.Config{} = config, user, attestation_params, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @register_opts_schema)
    schema = resolve_user_passkey_schema!(config, validated)
    cap = Keyword.get(validated, :max_per_user, config.passkeys[:max_per_user] || 10)

    Sigra.Telemetry.span([:sigra, :passkeys, :register], %{user_id: user.id}, fn ->
      with {:ok, extracted} <- Registration.verify(config, user, attestation_params, validated) do
        attrs = build_registration_attrs(user, extracted)

        multi =
          Multi.new()
          |> Multi.run(:cap_check, fn repo, _changes ->
            enforce_cap(repo, schema, user.id, cap)
          end)
          |> Multi.insert(:passkey, schema.create_changeset(struct(schema), attrs))
          |> Sigra.Audit.log_multi_safe(
            "passkey.register.success",
            passkey_audit_opts(config) ++
              [
                actor_id: user.id,
                target_id: user.id,
                metadata: %{
                  credential_id: Base.url_encode64(attrs.credential_id, padding: false),
                  rp_id: attrs.rp_id,
                  aaguid: attrs.aaguid
                }
              ]
          )

        normalize_register_result(config.repo.transact(multi))
      end
    end)
  end

  @spec list_for_user(Sigra.Config.t(), user :: map(), keyword()) :: [Credential.t()]
  def list_for_user(%Sigra.Config{} = config, user, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @schema_opts)
    schema = resolve_user_passkey_schema!(config, validated)

    from(p in schema, where: p.user_id == ^user.id, order_by: [desc: p.inserted_at])
    |> config.repo.all()
    |> Enum.map(&Credential.from_schema/1)
  end

  @spec count_for_user(Sigra.Config.t(), user :: map(), keyword()) :: non_neg_integer()
  def count_for_user(%Sigra.Config{} = config, user, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @schema_opts)
    schema = resolve_user_passkey_schema!(config, validated)

    from(p in schema, where: p.user_id == ^user.id)
    |> config.repo.aggregate(:count)
  end

  @spec authenticate(Sigra.Config.t(), user :: map(), map(), keyword()) ::
          {:ok, Credential.t()}
          | {:error, :credential_not_owned}
          | {:error, :sign_count_regression}
          | {:error, term()}
  def authenticate(%Sigra.Config{} = config, user, assertion, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @authenticate_opts_schema)
    schema = resolve_user_passkey_schema!(config, validated)

    policy =
      Keyword.get(validated, :sign_count_policy, config.passkeys[:sign_count_policy] || :warn)

    Sigra.Telemetry.span([:sigra, :passkeys, :authenticate], %{user_id: user.id}, fn ->
      with {:ok, row, auth_data} <-
             Authentication.verify(config, user, assertion, user_passkey_schema: schema) do
        persist_authentication_result(config, row, auth_data, policy)
      end
    end)
  end

  @spec rename(
          Sigra.Config.t(),
          user :: map(),
          credential_id :: binary(),
          new_nickname :: String.t(),
          keyword()
        ) ::
          {:ok, Credential.t()}
          | {:error, :not_found}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def rename(%Sigra.Config{} = config, user, credential_id, new_nickname, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @rename_opts_schema)
    schema = resolve_user_passkey_schema!(config, validated)

    case get_owned_passkey(config.repo, schema, user.id, credential_id) do
      nil ->
        {:error, :not_found}

      row ->
        multi =
          Multi.new()
          |> Multi.update(:passkey, update_changeset(row, %{nickname: new_nickname}))
          |> Sigra.Audit.log_multi_safe(
            "passkey.rename",
            passkey_audit_opts(config) ++
              [
                actor_id: user.id,
                target_id: user.id,
                metadata: %{
                  credential_id: Base.url_encode64(row.credential_id, padding: false),
                  rp_id: row.rp_id,
                  nickname: new_nickname
                }
              ]
          )

        normalize_mutation_result(config.repo.transact(multi))
    end
  end

  @spec delete(Sigra.Config.t(), user :: map(), credential_id :: binary(), keyword()) ::
          {:ok, Credential.t()} | {:error, :not_found} | {:error, term()}
  def delete(%Sigra.Config{} = config, user, credential_id, opts \\ []) do
    case delete_with_posture(config, user, credential_id, opts) do
      {:ok, %DeleteResult{credential: credential}} -> {:ok, credential}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec delete_with_posture(Sigra.Config.t(), user :: map(), credential_id :: binary(), keyword()) ::
          {:ok, DeleteResult.t()} | {:error, :not_found} | {:error, term()}
  def delete_with_posture(%Sigra.Config{} = config, user, credential_id, opts \\ []) do
    validated = NimbleOptions.validate!(opts, @delete_opts_schema)
    schema = resolve_user_passkey_schema!(config, validated)

    case get_owned_passkey(config.repo, schema, user.id, credential_id) do
      nil ->
        {:error, :not_found}

      row ->
        multi =
          Multi.new()
          |> Multi.run(:remaining_passkeys_before_delete, fn repo, _changes ->
            {:ok, count_owned_passkeys(repo, schema, user.id)}
          end)
          |> Multi.delete(:passkey, row)
          |> Sigra.Audit.log_multi_safe(
            "passkey.delete",
            passkey_audit_opts(config) ++
              [
                actor_id: user.id,
                target_id: user.id,
                metadata: %{
                  credential_id: Base.url_encode64(row.credential_id, padding: false),
                  rp_id: row.rp_id,
                  nickname: row.nickname
                }
              ]
          )

        normalize_delete_result(config.repo.transact(multi))
    end
  end

  @spec known_transport?(String.t() | atom()) :: boolean()
  def known_transport?(transport) when is_atom(transport) do
    known_transport?(Atom.to_string(transport))
  end

  def known_transport?(transport) when is_binary(transport), do: transport in @known_transports
  def known_transport?(_transport), do: false

  defp load_runtime_config! do
    otp_app =
      Application.get_env(:sigra, :otp_app) ||
        raise ArgumentError,
              "Sigra.Passkeys.config/0 requires Application.get_env(:sigra, :otp_app) to be set"

    host_config =
      case Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) ->
          opts

        nil ->
          raise ArgumentError,
                "Sigra.Passkeys.config/0 requires Application.get_env(#{inspect(otp_app)}, :sigra_config) to be set"

        other ->
          raise ArgumentError,
                "Sigra.Passkeys.config/0 expected #{inspect(otp_app)} :sigra_config to be a keyword list, got: #{inspect(other)}"
      end

    host_config
    |> Sigra.Config.new!()
    |> validate_runtime_passkeys!()
  end

  defp validate_runtime_passkeys!(%Sigra.Config{} = config) do
    passkeys = config.passkeys
    rp_id = Keyword.get(passkeys, :rp_id)
    origin = Keyword.get(passkeys, :origin)
    timeout_ms = Keyword.get(passkeys, :timeout_ms)

    ceremony_rate_limit =
      normalize_ceremony_rate_limit(Keyword.get(passkeys, :ceremony_rate_limit, []))

    ensure_present!(rp_id, "passkeys[:rp_id] is required for passkeys; set it to your RP ID")

    ensure_present!(
      origin,
      "passkeys[:origin] is required for passkeys; set it to your HTTPS origin"
    )

    if timeout_ms not in @runtime_timeout_range do
      raise ArgumentError,
            "passkeys[:timeout_ms] must be within #{Enum.min(@runtime_timeout_range)}..#{Enum.max(@runtime_timeout_range)}"
    end

    %{config | passkeys: Keyword.put(passkeys, :ceremony_rate_limit, ceremony_rate_limit)}
  end

  defp ensure_present!(value, message) when is_binary(value) do
    if byte_size(String.trim(value)) > 0 do
      :ok
    else
      raise ArgumentError, message
    end
  end

  defp ensure_present!(_value, message), do: raise(ArgumentError, message)

  defp ceremony_rate_limit_key(ceremony, user_id) do
    "sigra:passkeys:#{ceremony}:user:#{normalize_rate_limit_user_id(user_id)}"
  end

  defp normalize_ceremony_rate_limit(rate_limit) do
    [limit: Keyword.fetch!(rate_limit, :limit), window_ms: Keyword.fetch!(rate_limit, :window_ms)]
  end

  defp normalize_rate_limit_user_id(user_id) when is_binary(user_id), do: user_id

  defp normalize_rate_limit_user_id(user_id) when is_integer(user_id),
    do: Integer.to_string(user_id)

  defp normalize_rate_limit_user_id(user_id) when is_atom(user_id), do: Atom.to_string(user_id)
  defp normalize_rate_limit_user_id(user_id), do: inspect(user_id)

  defp normalize_register_result({:ok, %{passkey: row}}), do: {:ok, Credential.from_schema(row)}

  defp normalize_register_result({:error, :cap_check, {:passkey_cap_reached, info}, _changes}),
    do: {:error, :passkey_cap_reached, info}

  defp normalize_register_result({:error, _step, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp normalize_register_result({:error, _step, reason, _changes}), do: {:error, reason}
  defp normalize_register_result({:error, reason}), do: {:error, reason}

  defp normalize_mutation_result({:ok, %{passkey: row}}), do: {:ok, Credential.from_schema(row)}

  defp normalize_mutation_result({:error, _step, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp normalize_mutation_result({:error, _step, reason, _changes}), do: {:error, reason}
  defp normalize_mutation_result({:error, reason}), do: {:error, reason}

  defp normalize_delete_result(
         {:ok, %{remaining_passkeys_before_delete: count_before_delete, passkey: row}}
       ) do
    {:ok,
     %DeleteResult{
       credential: Credential.from_schema(row),
       deleted_last_passkey?: count_before_delete == 1,
       remaining_passkeys: max(count_before_delete - 1, 0)
     }}
  end

  defp normalize_delete_result({:error, _step, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp normalize_delete_result({:error, _step, reason, _changes}), do: {:error, reason}
  defp normalize_delete_result({:error, reason}), do: {:error, reason}

  defp passkey_audit_opts(%Sigra.Config{} = config) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema)
    ]
  end

  defp resolve_user_passkey_schema!(%Sigra.Config{} = config, opts) do
    Keyword.get(opts, :user_passkey_schema) || config.passkeys[:user_passkey_schema] ||
      raise ArgumentError,
            "passkey functions require :user_passkey_schema in opts or config.passkeys[:user_passkey_schema]"
  end

  defp enforce_cap(repo, schema, user_id, cap) do
    count =
      from(p in schema, where: p.user_id == ^user_id)
      |> repo.aggregate(:count)

    if count >= cap do
      {:error, {:passkey_cap_reached, %{count: count, cap: cap}}}
    else
      {:ok, :ok}
    end
  end

  defp get_owned_passkey(repo, schema, user_id, credential_id) do
    from(p in schema, where: p.user_id == ^user_id and p.credential_id == ^credential_id)
    |> repo.one()
  end

  defp count_owned_passkeys(repo, schema, user_id) do
    from(p in schema, where: p.user_id == ^user_id)
    |> repo.aggregate(:count)
  end

  defp build_registration_attrs(user, extracted) do
    %{
      user_id: user.id,
      credential_id: extracted.credential_id,
      public_key: extracted.public_key,
      sign_count: extracted.sign_count,
      aaguid: extracted.aaguid,
      nickname: extracted.nickname,
      device_hint: extracted.device_hint,
      transports: extracted.transports,
      rp_id: extracted.rp_id
    }
  end

  defp persist_authentication_result(config, row, auth_data, policy) do
    stored = row.sign_count || 0
    presented = auth_data.sign_count

    case Authentication.handle_sign_count(
           stored,
           presented,
           policy,
           sign_count_metadata(row, presented, policy)
         ) do
      :ok ->
        apply_authentication_multi(config, row, presented, audit_metadata: nil)

      {:regression, :warn, metadata} ->
        apply_authentication_multi(config, row, stored, audit_metadata: metadata)

      {:regression, :require_reauth, metadata} ->
        case sign_count_audit_multi(config, row, metadata) |> config.repo.transact() do
          {:ok, _changes} -> {:error, :sign_count_regression}
          {:error, _step, reason, _changes} -> {:error, reason}
          {:error, reason} -> {:error, reason}
        end

      {:regression, :revoke, metadata} ->
        multi =
          sign_count_audit_multi(config, row, metadata)
          |> Multi.delete(:passkey, row)

        case config.repo.transact(multi) do
          {:ok, _changes} -> {:error, :sign_count_regression}
          {:error, _step, reason, _changes} -> {:error, reason}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp apply_authentication_multi(config, row, presented_sign_count, opts) do
    attrs = %{
      sign_count: max(row.sign_count || 0, presented_sign_count),
      last_used_at: DateTime.utc_now()
    }

    multi =
      Multi.new()
      |> Multi.update(:passkey, update_changeset(row, attrs))
      |> maybe_append_sign_count_audit(config, row, Keyword.get(opts, :audit_metadata))

    case config.repo.transact(multi) do
      {:ok, %{passkey: updated}} -> {:ok, Credential.from_schema(updated)}
      {:error, _step, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sign_count_audit_multi(config, row, metadata) do
    Multi.new()
    |> maybe_append_sign_count_audit(config, row, metadata)
  end

  defp maybe_append_sign_count_audit(multi, _config, _row, nil), do: multi

  defp maybe_append_sign_count_audit(multi, config, row, metadata) do
    Sigra.Audit.log_multi_safe(
      multi,
      "passkey.sign_count_regression",
      passkey_audit_opts(config) ++
        [
          actor_id: row.user_id,
          target_id: row.user_id,
          metadata: metadata
        ]
    )
  end

  defp sign_count_metadata(row, presented, policy) do
    %{
      credential_id: Base.url_encode64(row.credential_id, padding: false),
      previous_count: row.sign_count || 0,
      presented_count: presented,
      policy_applied: policy,
      delta: presented - (row.sign_count || 0),
      rp_id: row.rp_id
    }
  end

  defp update_changeset(row, attrs) do
    if function_exported?(row.__struct__, :update_changeset, 2) do
      row.__struct__.update_changeset(row, attrs)
    else
      Ecto.Changeset.change(row, attrs)
    end
  end
end
