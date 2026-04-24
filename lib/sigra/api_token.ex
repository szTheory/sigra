defmodule Sigra.APIToken do
  @moduledoc """
  Core API token operations: creation, verification, revocation, and scope checks.

  API tokens (also called personal access tokens or secret keys) allow users to
  authenticate API requests without session cookies. Tokens use a prefix format
  (e.g., `my_app_sk_...`) for easy identification and are stored as SHA-256 hashes
  in the database.

  ## Token Lifecycle

  1. **Create** -- `create/3` generates a prefixed token, validates scopes, and
     stores the SHA-256 hash. The raw token is returned once and never stored.

  2. **Verify** -- `verify/2` hashes the submitted token and looks up the hash.
     Revoked and expired tokens are rejected. Successful verification does not
     write a durable audit row (D-27); `maybe_update_last_used/2` bumps
     `last_used_at` asynchronously via `Task.start/1` so the hot path stays
     low-latency while telemetry covers observability. When `:audit_schema` is
     configured, **`api.token_verify.failure`** rows are written inside
     **`Repo.transaction/1`** via **`Ecto.Multi`** + **`Audit.log_multi_safe/3`**
     (audit-only transaction; success remains unaudited per D-27).

  3. **Revoke** -- `revoke/2` soft-deletes a token by setting `revoked_at`.
     `revoke_all/2` revokes all active tokens for a user. With `:audit_schema`
     configured, both operations append `api.token_revoke` /
     `api.token_revoke_all` on the same `Ecto.Multi` as the DB write (AUD-07).

  4. **JWT refresh auditing** -- `audit_jwt_refresh/2` and `audit_jwt_refresh_reuse/2`
     emit `api.jwt_refresh` / `api.jwt_refresh_reuse` rows when `:audit_schema` is
     set, using **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Audit.log_multi_safe/3`**
     (audit-only transaction; AUD-18). When `:audit_schema` is set, **`Sigra.JWT.refresh/3`**
     also performs **persistence + audit co-fate** in one transaction — do not call
     **`audit_jwt_refresh/2`** afterward or you risk double-audit rows.

  ## Scope System

  Tokens carry a list of scopes in `resource:action` format (e.g., `"profile:read"`).
  The `can?/2` function checks whether a token's scopes satisfy requirements.
  The special `"*"` wildcard scope grants access to all resources.

  ## Security

  - Raw tokens are never stored; only SHA-256 hashes are persisted
  - Token prefix is validated to prevent JWT collision (`eyJ` prefix blocked)
  - All operations emit telemetry events for observability
  """

  alias Ecto.Multi
  alias Sigra.APIToken.ScopeRegistry
  alias Sigra.Audit
  alias Sigra.Telemetry
  alias Sigra.Token

  @prefix_format ~r/^[a-z0-9_]+$/

  @doc """
  Creates a new API token for the given user.

  Returns `{:ok, raw_key, token_record}` on success. The `raw_key` includes
  the configured prefix and should be shown to the user exactly once.

  ## Parameters

  - `config` - A `%Sigra.Config{}` struct
  - `user` - The user struct (must have an `:id` field)
  - `attrs` - A map with:
    - `:name` (required) - Human-readable token name, max 255 chars
    - `:scopes` (required) - List of scope strings
    - `:expires_at` (optional) - Expiration datetime

  ## Examples

      {:ok, raw_key, token} = Sigra.APIToken.create(config, user, %{
        name: "CI Deploy Key",
        scopes: ["profile:read", "api_tokens:read"]
      })

  """
  @doc since: "0.7.0"
  @spec create(Sigra.Config.t(), map(), map()) ::
          {:ok, String.t(), map()} | {:error, term()}
  def create(config, user, attrs) do
    api_token_opts = config.api_token
    prefix = resolve_prefix(config)

    with :ok <- validate_prefix(prefix),
         :ok <- validate_name(attrs),
         :ok <- ScopeRegistry.validate_scopes(config, Map.get(attrs, :scopes, [])),
         :ok <- validate_expiry(api_token_opts, attrs) do
      Telemetry.span([:sigra, :api_token, :create], %{user_id: user.id}, fn ->
        do_create(config, user, attrs, prefix)
      end)
    end
  end

  defp do_create(config, user, attrs, prefix) do
    {raw_random, _hash_of_random} = Token.generate_hashed_token()
    raw_key = prefix <> raw_random
    hashed_token = Token.hash_token(raw_key)

    schema = Keyword.fetch!(config.api_token, :api_token_schema)

    changeset =
      schema.changeset(struct(schema), %{
        user_id: user.id,
        hashed_token: hashed_token,
        prefix: prefix,
        name: attrs.name,
        scopes: attrs.scopes,
        expires_at: Map.get(attrs, :expires_at)
      })

    scope =
      case config.scope_module do
        nil -> nil
        mod -> Sigra.Scope.build(mod, user, active_organization: nil)
      end

    merged_scope_fields =
      Keyword.merge(api_token_scope_fields(scope), actor_id: user.id, target_id: user.id)

    audit_opts =
      api_token_audit_opts(config)
      |> Keyword.merge(merged_scope_fields)
      |> Keyword.merge(metadata: %{name: attrs.name, scopes: attrs.scopes})

    multi =
      Multi.new()
      |> Multi.insert(:api_token, changeset)
      |> Audit.log_multi_safe("api.token_create", audit_opts)

    case config.repo.transaction(multi) do
      {:ok, %{api_token: token_record} = changes} ->
        Audit.emit_telemetry_from_changes(changes)
        {:ok, raw_key, token_record}

      {:error, :api_token, %Ecto.Changeset{} = cs, _} ->
        {:error, cs}

      {:error, failed, reason, _} ->
        raise "unexpected Ecto.Multi failure from Sigra.APIToken.do_create/4: " <>
                "#{inspect(failed)} => #{inspect(reason)}"
    end
  end

  defp api_token_scope_fields(nil) do
    [organization_id: nil, effective_user_id: nil, actor_id: nil]
  end

  defp api_token_scope_fields(%{user: user} = scope) do
    org = Map.get(scope, :active_organization)
    actor = Map.get(scope, :impersonating_from) || user

    [
      organization_id: org && org.id,
      effective_user_id: user && user.id,
      actor_id: actor && actor.id
    ]
  end

  defp api_token_scope_fields(_other) do
    [organization_id: nil, effective_user_id: nil, actor_id: nil]
  end

  # --- Audit integration helpers (Plan 09-03) ---
  defp api_token_audit_opts(config) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema)
    ]
  end

  defp verify_failure_audit_scope_fields(scope) do
    case scope do
      nil ->
        [organization_id: nil, effective_user_id: nil, actor_id: nil]

      %{user: user} = s ->
        org = Map.get(s, :active_organization)
        actor = Map.get(s, :impersonating_from) || user

        [
          organization_id: org && org.id,
          effective_user_id: user && user.id,
          actor_id: actor && actor.id
        ]

      _ ->
        [organization_id: nil, effective_user_id: nil, actor_id: nil]
    end
  end

  defp verify_failure_audit_opts(config, scope, metadata, overrides)
       when is_map(metadata) and is_list(overrides) do
    Keyword.merge(
      Keyword.merge(
        verify_failure_audit_scope_fields(scope),
        api_token_audit_opts(config) ++ [outcome: "failure", metadata: metadata]
      ),
      overrides
    )
  end

  defp commit_api_token_verify_failure_audit(config, opts) do
    case Keyword.get(opts, :audit_schema) do
      nil ->
        :ok

      _ ->
        multi =
          Multi.new()
          |> Audit.log_multi_safe(
            "api.token_verify.failure",
            Keyword.put(opts, :audit_multi_step, :audit_api_token_verify_failure)
          )

        try do
          case config.repo.transaction(multi) do
            {:ok, changes} ->
              Audit.emit_telemetry_from_changes(changes, [:audit_api_token_verify_failure])

            {:error, :audit_api_token_verify_failure, %Ecto.Changeset{} = cs, _} ->
              verify_failure_audit_emit_invalid_changeset(cs)

            {:error, failed, reason, _} ->
              raise "unexpected Ecto.Multi failure from Sigra.APIToken.verify failure audit: " <>
                      "#{inspect(failed)} => #{inspect(reason)}"
          end
        rescue
          e ->
            if verify_failure_audit_rescue?(e) do
              :telemetry.execute(
                [:sigra, :audit, :log_safe_error],
                %{count: 1},
                %{action: "api.token_verify.failure", reason: :constraint_violation}
              )
            else
              reraise(e, __STACKTRACE__)
            end
        end
    end
  end

  @doc """
  Appends a JWT audit insert step to the given `Ecto.Multi`.

  Delegates to `Sigra.Audit.log_multi_safe/3` (no-op when `:audit_schema` is `nil`).

  For internal composition from `Sigra.JWT.refresh/3` when `:audit_schema` is set.
  Host applications should not compose arbitrary multis unless they own the
  outer `Repo.transaction/1`.
  """
  @doc since: "0.9.1"
  def append_api_token_jwt_audit_to_multi(%Ecto.Multi{} = multi, action, opts)
      when is_binary(action) and is_list(opts) do
    Audit.log_multi_safe(multi, action, opts)
  end

  @doc false
  def jwt_refresh_audit_multi_opts(config, user_id, kind) when kind in [:refresh, :reuse] do
    jwt_refresh_audit_merged_opts(config, user_id, kind)
  end

  defp jwt_refresh_audit_merged_opts(config, user_id, :refresh) do
    scope = Sigra.Scope.from_config(config, %{id: user_id})

    Keyword.merge(
      api_token_scope_fields(scope),
      api_token_audit_opts(config) ++
        [
          actor_id: user_id,
          target_id: user_id,
          metadata: %{},
          audit_multi_step: :audit_api_token_jwt_refresh
        ]
    )
  end

  defp jwt_refresh_audit_merged_opts(config, user_id, :reuse) do
    scope = Sigra.Scope.from_config(config, %{id: user_id})

    Keyword.merge(
      api_token_scope_fields(scope),
      api_token_audit_opts(config) ++
        [
          actor_id: user_id,
          target_id: user_id,
          outcome: "failure",
          metadata: %{reason: "refresh_token_reuse_detected"},
          audit_multi_step: :audit_api_token_jwt_refresh_reuse
        ]
    )
  end

  defp commit_api_token_jwt_audit(config, action, opts)
       when is_binary(action) and is_list(opts) do
    case Keyword.get(opts, :audit_schema) do
      nil ->
        :ok

      _ ->
        audit_step = Keyword.fetch!(opts, :audit_multi_step)

        multi =
          Multi.new()
          |> append_api_token_jwt_audit_to_multi(action, opts)

        try do
          case config.repo.transaction(multi) do
            {:ok, changes} ->
              Audit.emit_telemetry_from_changes(changes, [audit_step])

            {:error, failed_step, %Ecto.Changeset{} = cs, _}
            when failed_step == audit_step ->
              jwt_audit_emit_invalid_changeset(action, cs)

            {:error, failed, reason, _} ->
              raise "unexpected Ecto.Multi failure from Sigra.APIToken jwt audit: " <>
                      "#{inspect(failed)} => #{inspect(reason)}"
          end
        rescue
          e ->
            if verify_failure_audit_rescue?(e) do
              :telemetry.execute(
                [:sigra, :audit, :log_safe_error],
                %{count: 1},
                %{action: action, reason: :constraint_violation}
              )
            else
              reraise(e, __STACKTRACE__)
            end
        end
    end
  end

  defp jwt_audit_emit_invalid_changeset(action, %Ecto.Changeset{} = cs) do
    error_fields =
      cs.errors
      |> Enum.map(fn {field, _} -> field end)
      |> Enum.uniq()

    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{
        action: action,
        reason: :invalid_changeset,
        error_fields: error_fields
      }
    )
  end

  defp verify_failure_audit_rescue?(e) do
    match?(%Ecto.ConstraintError{}, e) or
      (is_exception(e) and match?(%{table: _}, Map.get(e, :postgres)))
  end

  defp verify_failure_audit_emit_invalid_changeset(%Ecto.Changeset{} = cs) do
    error_fields =
      cs.errors
      |> Enum.map(fn {field, _} -> field end)
      |> Enum.uniq()

    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{
        action: "api.token_verify.failure",
        reason: :invalid_changeset,
        error_fields: error_fields
      }
    )
  end

  @doc """
  Verifies a raw API token string.

  Hashes the token and looks up the hash in the database. Returns
  `{:ok, token}` for valid active tokens, or an error tuple.

  ## Error Returns

  - `{:error, :invalid_token}` - Token not found
  - `{:error, :token_revoked}` - Token has been revoked
  - `{:error, :token_expired}` - Token has expired

  ## Examples

      case Sigra.APIToken.verify(config, raw_token) do
        {:ok, token} -> # authenticated
        {:error, reason} -> # rejected
      end

  """
  @doc since: "0.7.0"
  @spec verify(Sigra.Config.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_token | :token_revoked | :token_expired}
  def verify(config, raw_token) when is_binary(raw_token) do
    Telemetry.span([:sigra, :api_token, :verify], %{}, fn ->
      hashed = Token.hash_token(raw_token)
      schema = Keyword.fetch!(config.api_token, :api_token_schema)

      case config.repo.get_by(schema, hashed_token: hashed) do
        nil ->
          # D-27: failure rows only; success is still not audited.
          commit_api_token_verify_failure_audit(
            config,
            verify_failure_audit_opts(config, nil, %{reason: "invalid_token"},
              actor_id: nil,
              target_id: nil
            )
          )

          {:error, :invalid_token}

        token ->
          cond do
            token.revoked_at != nil ->
              scope = Sigra.Scope.from_config(config, %{id: Map.get(token, :user_id)})
              user_id = Map.get(token, :user_id)

              commit_api_token_verify_failure_audit(
                config,
                verify_failure_audit_opts(config, scope, %{reason: "token_revoked"},
                  actor_id: user_id,
                  target_id: user_id
                )
              )

              {:error, :token_revoked}

            token.expires_at != nil and
                DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt ->
              scope = Sigra.Scope.from_config(config, %{id: Map.get(token, :user_id)})
              user_id = Map.get(token, :user_id)

              commit_api_token_verify_failure_audit(
                config,
                verify_failure_audit_opts(config, scope, %{reason: "token_expired"},
                  actor_id: user_id,
                  target_id: user_id
                )
              )

              {:error, :token_expired}

            true ->
              # D-27: api.token_verify success is intentionally NOT audited
              # (too noisy; covered by telemetry).
              maybe_update_last_used(config, token)
              {:ok, token}
          end
      end
    end)
  end

  @doc """
  Revokes a single API token by ID.

  Sets `revoked_at` to the current UTC time. Returns `{:ok, token}` on
  success or `{:error, :not_found}` if the token does not exist.

  ## Examples

      {:ok, revoked_token} = Sigra.APIToken.revoke(config, token_id)

  """
  @doc since: "0.7.0"
  @spec revoke(Sigra.Config.t(), term()) ::
          {:ok, map()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def revoke(config, token_id) do
    schema = Keyword.fetch!(config.api_token, :api_token_schema)

    case config.repo.get(schema, token_id) do
      nil ->
        {:error, :not_found}

      token ->
        user_id = Map.get(token, :user_id)
        scope = Sigra.Scope.from_config(config, %{id: user_id})

        merged_scope_fields =
          Keyword.merge(api_token_scope_fields(scope), actor_id: user_id, target_id: user_id)

        audit_opts =
          api_token_audit_opts(config)
          |> Keyword.merge(merged_scope_fields)
          |> Keyword.merge(metadata: %{token_id: to_string(token_id)})

        changeset =
          Ecto.Changeset.change(token,
            revoked_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )

        multi =
          Multi.new()
          |> Multi.update(:token, changeset)
          |> Audit.log_multi_safe("api.token_revoke", audit_opts)

        case config.repo.transaction(multi) do
          {:ok, %{token: updated} = changes} ->
            Audit.emit_telemetry_from_changes(changes)

            Telemetry.event([:sigra, :api_token, :revoke, :stop], %{}, %{
              token_id: token_id
            })

            {:ok, updated}

          {:error, :token, %Ecto.Changeset{} = cs, _} ->
            {:error, cs}

          {:error, failed, reason, _} ->
            raise "unexpected Ecto.Multi failure from Sigra.APIToken.revoke/2: " <>
                    "#{inspect(failed)} => #{inspect(reason)}"
        end
    end
  end

  @doc """
  Emit **api.jwt_refresh** audit row (called from Sigra.JWT refresh flow).

  When **`:audit_schema`** is configured, the row is written inside
  **`Repo.transaction/1`** via audit-only **`Ecto.Multi`** + **`Audit.log_multi_safe/3`**
  (same durability posture as verify-failure auditing).

  Returns **`:ok`** even when auditing is disabled or when the audit insert is
  rejected or rolled back after the host transaction has already committed elsewhere.
  **`:ok` does not prove** the audit row exists; monitor **`[:sigra, :audit, :log_safe_error]`**
  for **`reason: :invalid_changeset`** or **`:constraint_violation`**.

  This is exposed so the JWT refresh implementation (potentially a separate module)
  can write a consistent audit row through this module's helpers.
  """
  @doc since: "0.9.0"
  @spec audit_jwt_refresh(Sigra.Config.t(), term()) :: :ok
  def audit_jwt_refresh(config, user_id) do
    commit_api_token_jwt_audit(
      config,
      "api.jwt_refresh",
      jwt_refresh_audit_merged_opts(config, user_id, :refresh)
    )
  end

  @doc """
  Emit **api.jwt_refresh_reuse** audit row (detected refresh-token reuse).

  When **`:audit_schema`** is configured, uses the same transactional **`Multi`** +
  **`log_multi_safe`** path as **`audit_jwt_refresh/2`**.

  Returns **`:ok`** regardless of whether a durable audit row was persisted; see
  **`audit_jwt_refresh/2`** and **`[:sigra, :audit, :log_safe_error]`** for operational honesty.
  """
  @doc since: "0.9.0"
  @spec audit_jwt_refresh_reuse(Sigra.Config.t(), term()) :: :ok
  def audit_jwt_refresh_reuse(config, user_id) do
    commit_api_token_jwt_audit(
      config,
      "api.jwt_refresh_reuse",
      jwt_refresh_audit_merged_opts(config, user_id, :reuse)
    )
  end

  @doc """
  Revokes all active API tokens for a user.

  Sets `revoked_at` on all tokens where `revoked_at IS NULL` for the given user.
  Returns `{:ok, count}` with the number of tokens revoked.

  ## Examples

      {:ok, 3} = Sigra.APIToken.revoke_all(config, user)

  """
  @doc since: "0.7.0"
  @spec revoke_all(Sigra.Config.t(), map()) :: {:ok, non_neg_integer()}
  def revoke_all(config, user) do
    import Ecto.Query

    schema = Keyword.fetch!(config.api_token, :api_token_schema)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from(t in schema,
        where: t.user_id == ^user.id and is_nil(t.revoked_at),
        update: [set: [revoked_at: ^now]]
      )

    audit_schema = Keyword.get(api_token_audit_opts(config), :audit_schema)

    if audit_schema do
      scope = Sigra.Scope.from_config(config, user)

      merged_scope_fields =
        Keyword.merge(api_token_scope_fields(scope), actor_id: user.id, target_id: user.id)

      audit_opts =
        api_token_audit_opts(config)
        |> Keyword.merge(merged_scope_fields)
        |> Keyword.merge(
          metadata_resolver: fn changes ->
            %{count: changes.revoke_bulk}
          end
        )

      multi =
        Multi.new()
        |> Multi.run(:revoke_bulk, fn repo, _ ->
          {count, _} = repo.update_all(query, [])
          {:ok, count}
        end)
        |> Audit.log_multi_safe("api.token_revoke_all", audit_opts)

      case config.repo.transaction(multi) do
        {:ok, %{revoke_bulk: count} = changes} ->
          Audit.emit_telemetry_from_changes(changes)

          Telemetry.event([:sigra, :api_token, :revoke_all, :stop], %{count: count}, %{
            user_id: user.id
          })

          {:ok, count}

        {:error, failed, reason, _} ->
          raise "unexpected Ecto.Multi failure from Sigra.APIToken.revoke_all/2: " <>
                  "#{inspect(failed)} => #{inspect(reason)}"
      end
    else
      {count, _} = config.repo.update_all(query, [])

      Telemetry.event([:sigra, :api_token, :revoke_all, :stop], %{count: count}, %{
        user_id: user.id
      })

      {:ok, count}
    end
  end

  @doc """
  Lists active (non-revoked, non-expired) API tokens for a user with cursor pagination.

  Returns `{tokens, next_cursor}` where `next_cursor` is `nil` on the last page.

  ## Options

  - `:limit` - Page size (default from config, max from config)
  - `:cursor` - Opaque cursor string from a previous call

  ## Examples

      {tokens, cursor} = Sigra.APIToken.list_active(config, user_id)
      {more_tokens, nil} = Sigra.APIToken.list_active(config, user_id, cursor: cursor)

  """
  @doc since: "0.7.0"
  @spec list_active(Sigra.Config.t(), term(), keyword()) :: {[map()], String.t() | nil}
  def list_active(config, user_id, opts \\ []) do
    import Ecto.Query

    api_opts = config.api_token
    default_size = Keyword.get(api_opts, :default_page_size, 50)
    max_size = Keyword.get(api_opts, :max_page_size, 200)
    limit = min(Keyword.get(opts, :limit, default_size), max_size)
    cursor = Keyword.get(opts, :cursor)
    schema = Keyword.fetch!(api_opts, :api_token_schema)
    now = DateTime.utc_now()

    query =
      from(t in schema,
        where: t.user_id == ^user_id,
        where: is_nil(t.revoked_at),
        where: is_nil(t.expires_at) or t.expires_at > ^now,
        order_by: [asc: t.inserted_at, asc: t.id],
        limit: ^(limit + 1)
      )

    query =
      if cursor do
        {cursor_at, cursor_id} = decode_cursor(cursor)

        from(t in query,
          where:
            t.inserted_at > ^cursor_at or
              (t.inserted_at == ^cursor_at and t.id > ^cursor_id)
        )
      else
        query
      end

    results = config.repo.all(query)

    if length(results) > limit do
      tokens = Enum.take(results, limit)
      last = List.last(tokens)
      next_cursor = encode_cursor(last.inserted_at, last.id)
      {tokens, next_cursor}
    else
      {results, nil}
    end
  end

  @doc """
  Checks whether a token or scope struct has the required scopes.

  Accepts either a map with `:scopes` (token struct) or `:token_scopes`
  (scope struct from conn.assigns).

  ## Options

  - `:match` - `:all` (default) requires all scopes, `:any` requires at least one

  ## Examples

      Sigra.APIToken.can?(token, ["profile:read"])
      #=> true

      Sigra.APIToken.can?(token, ["admin:write"], match: :any)
      #=> false

  """
  @doc since: "0.7.0"
  @spec can?(map(), [String.t()], keyword()) :: boolean()
  def can?(token_or_scope, required_scopes, opts \\ []) do
    token_scopes = extract_scopes(token_or_scope)
    match_mode = Keyword.get(opts, :match, :all)

    cond do
      "*" in token_scopes ->
        true

      match_mode == :all ->
        MapSet.subset?(MapSet.new(required_scopes), MapSet.new(token_scopes))

      match_mode == :any ->
        Enum.any?(required_scopes, &(&1 in token_scopes))
    end
  end

  @doc """
  Returns all registered scopes (built-in + custom).

  Delegates to `Sigra.APIToken.ScopeRegistry.all_scopes/1`.

  ## Examples

      scopes = Sigra.APIToken.list_scopes(config)
      #=> ["profile:read", "profile:write", ...]

  """
  @doc since: "0.7.0"
  @spec list_scopes(Sigra.Config.t()) :: [String.t()]
  def list_scopes(config) do
    ScopeRegistry.all_scopes(config)
  end

  @doc """
  Encodes an inserted_at timestamp and ID into an opaque cursor string.
  """
  @doc since: "0.7.0"
  @spec encode_cursor(DateTime.t(), term()) :: String.t()
  def encode_cursor(inserted_at, id) do
    Base.url_encode64("#{DateTime.to_iso8601(inserted_at)}|#{id}", padding: false)
  end

  @doc """
  Decodes an opaque cursor string into `{inserted_at, id}`.
  """
  @doc since: "0.7.0"
  @spec decode_cursor(String.t()) :: {DateTime.t(), integer()}
  def decode_cursor(cursor) when is_binary(cursor) do
    decoded = Base.url_decode64!(cursor, padding: false)
    [iso_string, id_string] = String.split(decoded, "|", parts: 2)
    {:ok, datetime, _} = DateTime.from_iso8601(iso_string)
    {datetime, String.to_integer(id_string)}
  end

  # -- Private helpers --

  defp resolve_prefix(config) do
    case Keyword.get(config.api_token, :prefix) do
      nil -> "#{config.otp_app}_sk_"
      prefix -> prefix
    end
  end

  defp validate_prefix(prefix) do
    cond do
      String.starts_with?(prefix, "eyJ") -> {:error, :invalid_prefix}
      not Regex.match?(@prefix_format, prefix) -> {:error, :invalid_prefix}
      true -> :ok
    end
  end

  defp validate_name(%{name: name}) when is_binary(name) and byte_size(name) > 0 do
    if String.length(name) > 255 do
      {:error, :name_too_long}
    else
      :ok
    end
  end

  defp validate_name(_), do: {:error, :name_required}

  defp validate_expiry(api_token_opts, attrs) do
    require_expiry = Keyword.get(api_token_opts, :require_expiry, false)
    max_ttl = Keyword.get(api_token_opts, :max_ttl)
    expires_at = Map.get(attrs, :expires_at)

    cond do
      require_expiry and is_nil(expires_at) ->
        {:error, :expiry_required}

      not is_nil(max_ttl) and not is_nil(expires_at) ->
        max_datetime = DateTime.add(DateTime.utc_now(), max_ttl, :second)

        if DateTime.compare(expires_at, max_datetime) == :gt do
          {:error, :ttl_exceeded}
        else
          :ok
        end

      true ->
        :ok
    end
  end

  defp extract_scopes(%{scopes: scopes}) when is_list(scopes), do: scopes
  defp extract_scopes(%{token_scopes: scopes}) when is_list(scopes), do: scopes
  defp extract_scopes(_), do: []

  defp maybe_update_last_used(config, token) do
    schema = Keyword.fetch!(config.api_token, :api_token_schema)
    threshold = Keyword.get(config.api_token, :activity_update_threshold, 300)

    should_update =
      is_nil(token.last_used_at) or
        DateTime.diff(DateTime.utc_now(), token.last_used_at, :second) > threshold

    # `repo.get_by/2` normally returns a schema struct; test doubles may return
    # plain maps. `Ecto.Changeset.change/2` requires a struct or changeset.
    if should_update and match?(%{__struct__: ^schema}, token) do
      Task.start(fn ->
        changeset = Ecto.Changeset.change(token, last_used_at: DateTime.utc_now())
        config.repo.update(changeset)
      end)
    end

    :ok
  end
end
