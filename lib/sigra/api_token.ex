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
     Revoked and expired tokens are rejected.

  3. **Revoke** -- `revoke/2` soft-deletes a token by setting `revoked_at`.
     `revoke_all/2` revokes all active tokens for a user.

  ## Scope System

  Tokens carry a list of scopes in `resource:action` format (e.g., `"profile:read"`).
  The `can?/2` function checks whether a token's scopes satisfy requirements.
  The special `"*"` wildcard scope grants access to all resources.

  ## Security

  - Raw tokens are never stored; only SHA-256 hashes are persisted
  - Token prefix is validated to prevent JWT collision (`eyJ` prefix blocked)
  - All operations emit telemetry events for observability
  """

  alias Sigra.APIToken.ScopeRegistry
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

    case config.repo.insert(changeset) do
      {:ok, token_record} ->
        # D-26: api.token_create audit row (standalone, D-28). Metadata
        # never contains the raw token or hash — only name and scopes
        # (D-23 forbidden keys enforced by Sigra.Audit.Changeset).
        # 15-02 Category 2: user resolved, config.scope_module available —
        # build a user-only scope (org intentionally nil at token create).
        scope =
          case config.scope_module do
            nil -> nil
            mod -> Sigra.Scope.build(mod, user, active_organization: nil)
          end

        Sigra.Audit.log_safe("api.token_create", scope,
          api_token_audit_opts(config) ++ [
            actor_id: user.id,
            target_id: user.id,
            metadata: %{name: attrs.name, scopes: attrs.scopes}
          ]
        )

        {:ok, raw_key, token_record}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # --- Audit integration helpers (Plan 09-03) ---
  defp api_token_audit_opts(config) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema)
    ]
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
          # D-27: api.token_verify.failure only (success is NOT audited
          # because it would be too noisy; observability is covered by
          # telemetry).
          Sigra.Audit.log_safe("api.token_verify.failure", nil,
            api_token_audit_opts(config) ++ [
              actor_id: nil,
              target_id: nil,
              outcome: "failure",
              metadata: %{reason: "invalid_token"}
            ]
          )

          {:error, :invalid_token}

        token ->
          cond do
            token.revoked_at != nil ->
              Sigra.Audit.log_safe(
                "api.token_verify.failure",
                Sigra.Scope.from_config(config, %{id: Map.get(token, :user_id)}),
                api_token_audit_opts(config) ++ [
                  actor_id: Map.get(token, :user_id),
                  target_id: Map.get(token, :user_id),
                  outcome: "failure",
                  metadata: %{reason: "token_revoked"}
                ]
              )

              {:error, :token_revoked}

            token.expires_at != nil and
                DateTime.compare(token.expires_at, DateTime.utc_now()) == :lt ->
              Sigra.Audit.log_safe(
                "api.token_verify.failure",
                Sigra.Scope.from_config(config, %{id: Map.get(token, :user_id)}),
                api_token_audit_opts(config) ++ [
                  actor_id: Map.get(token, :user_id),
                  target_id: Map.get(token, :user_id),
                  outcome: "failure",
                  metadata: %{reason: "token_expired"}
                ]
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
  @spec revoke(Sigra.Config.t(), term()) :: {:ok, map()} | {:error, :not_found}
  def revoke(config, token_id) do
    schema = Keyword.fetch!(config.api_token, :api_token_schema)

    case config.repo.get(schema, token_id) do
      nil ->
        {:error, :not_found}

      token ->
        changeset = Ecto.Changeset.change(token, revoked_at: DateTime.utc_now())

        case config.repo.update(changeset) do
          {:ok, updated} ->
            Telemetry.event([:sigra, :api_token, :revoke, :stop], %{}, %{
              token_id: token_id
            })

            # D-26: api.token_revoke audit row
            Sigra.Audit.log_safe(
              "api.token_revoke",
              Sigra.Scope.from_config(config, %{id: Map.get(token, :user_id)}),
              api_token_audit_opts(config) ++ [
                actor_id: Map.get(token, :user_id),
                target_id: Map.get(token, :user_id),
                metadata: %{token_id: to_string(token_id)}
              ]
            )

            {:ok, updated}

          error ->
            error
        end
    end
  end

  @doc """
  Emit api.jwt_refresh audit row (called from Sigra.JWT refresh flow).

  This is exposed so the JWT refresh implementation (potentially a
  separate module) can write a consistent audit row through this
  module's helpers.
  """
  @doc since: "0.9.0"
  @spec audit_jwt_refresh(Sigra.Config.t(), term()) :: :ok
  def audit_jwt_refresh(config, user_id) do
    Sigra.Audit.log_safe("api.jwt_refresh", Sigra.Scope.from_config(config, %{id: user_id}),
      api_token_audit_opts(config) ++ [
        actor_id: user_id,
        target_id: user_id,
        metadata: %{}
      ]
    )
  end

  @doc """
  Emit api.jwt_refresh_reuse audit row (detected refresh-token reuse).
  """
  @doc since: "0.9.0"
  @spec audit_jwt_refresh_reuse(Sigra.Config.t(), term()) :: :ok
  def audit_jwt_refresh_reuse(config, user_id) do
    Sigra.Audit.log_safe("api.jwt_refresh_reuse", Sigra.Scope.from_config(config, %{id: user_id}),
      api_token_audit_opts(config) ++ [
        actor_id: user_id,
        target_id: user_id,
        outcome: "failure",
        metadata: %{reason: "refresh_token_reuse_detected"}
      ]
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
    now = DateTime.utc_now()

    query =
      from(t in schema,
        where: t.user_id == ^user.id and is_nil(t.revoked_at),
        update: [set: [revoked_at: ^now]]
      )

    {count, _} = config.repo.update_all(query, [])

    Telemetry.event([:sigra, :api_token, :revoke_all, :stop], %{count: count}, %{
      user_id: user.id
    })

    {:ok, count}
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
    threshold = Keyword.get(config.api_token, :activity_update_threshold, 300)

    should_update =
      is_nil(token.last_used_at) or
        DateTime.diff(DateTime.utc_now(), token.last_used_at, :second) > threshold

    if should_update do
      Task.start(fn ->
        changeset = Ecto.Changeset.change(token, last_used_at: DateTime.utc_now())
        config.repo.update(changeset)
      end)
    end

    :ok
  end
end
