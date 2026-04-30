defmodule Sigra.Plug.FetchBearer do
  @moduledoc """
  Extracts a bearer token from the Authorization header and assigns current_scope.

  Auto-detects token type by format:
  - Tokens starting with the configured API token prefix -> opaque API token (DB lookup)
  - Tokens starting with "eyJ" and JWT enabled -> JWT (signature verification)
  - All other tokens -> opaque API token path (DB lookup)

  Assigns `current_scope` with `token_scopes`, `auth_method`, and `token_id` fields.
  Skips if `current_scope` is already assigned.

  ## Options

    * `:config` - A `%Sigra.Config{}` struct (required)
    * `:scope_module` - The module to call `.new/1` on (the host app's Scope module)

  ## Example

      plug Sigra.Plug.FetchBearer,
        config: @sigra_config,
        scope_module: MyApp.Auth.Scope
  """

  @behaviour Plug

  alias Sigra.ServiceAccounts

  @doc """
  Initialize the plug with the given options.
  """
  @doc since: "0.7.0"
  @impl Plug
  def init(opts), do: opts

  @doc """
  Extract bearer token from Authorization header and assign `current_scope`.

  Skips processing if `current_scope` is already assigned (D-53).
  """
  @doc since: "0.7.0"
  @impl Plug
  def call(conn, opts) do
    # D-53: skip if current_scope already assigned
    if conn.assigns[:current_scope] do
      conn
    else
      do_fetch(conn, opts)
    end
  end

  defp do_fetch(conn, opts) do
    config = Keyword.fetch!(opts, :config)
    scope_module = Keyword.fetch!(opts, :scope_module)

    case extract_bearer_token(conn) do
      {:ok, raw_token} ->
        case detect_and_verify(config, raw_token) do
          {:ok, :api_token, token} ->
            scope =
              build_user_scope(config, scope_module, token.user_id, %{
                token_scopes: token.scopes,
                auth_method: :api_token,
                token_id: token.id
              })

            Plug.Conn.assign(conn, :current_scope, scope)

          {:ok, :jwt, claims} ->
            case build_jwt_scope(config, scope_module, claims) do
              nil ->
                Plug.Conn.assign(conn, :current_scope, nil)

              scope ->
                Plug.Conn.assign(conn, :current_scope, scope)
            end

          {:error, reason} ->
            maybe_audit_jwt_failure(config, raw_token, reason)
            Plug.Conn.assign(conn, :current_scope, nil)
        end

      :error ->
        Plug.Conn.assign(conn, :current_scope, nil)
    end
  end

  defp detect_and_verify(config, raw_token) do
    prefix = get_prefix(config)
    jwt_enabled = Keyword.get(config.jwt, :enabled, false)

    cond do
      # Prefix match -> always opaque (checked first per D-38)
      prefix && String.starts_with?(raw_token, prefix) ->
        verify_opaque(config, raw_token)

      # eyJ prefix and JWT enabled -> JWT path
      jwt_enabled && String.starts_with?(raw_token, "eyJ") ->
        case Sigra.JWT.verify_access(config, raw_token) do
          {:ok, claims} -> {:ok, :jwt, claims}
          error -> error
        end

      # Default: try opaque
      true ->
        verify_opaque(config, raw_token)
    end
  end

  defp verify_opaque(config, raw_token) do
    case Sigra.APIToken.verify(config, raw_token) do
      {:ok, token} -> {:ok, :api_token, token}
      error -> error
    end
  end

  defp get_prefix(config) do
    Keyword.get(config.api_token, :prefix) ||
      if config.otp_app, do: "#{config.otp_app}_sk_"
  end

  defp build_jwt_scope(config, scope_module, %{"actor_type" => "service_account"} = claims) do
    service_account_schema = Keyword.get(config.service_accounts, :service_account_schema)

    with schema when not is_nil(schema) <- service_account_schema,
         service_account_id when not is_nil(service_account_id) <- claims["service_account_id"],
         %_{} = service_account <- config.repo.get(schema, service_account_id),
         nil <- service_account.revoked_at,
         %_{} = organization <- load_organization(config, claims["org_id"]) do
      build_scope(scope_module, %{
        user: nil,
        active_organization: organization,
        membership: nil,
        impersonating_from: nil,
        role: Map.get(service_account, :role),
        actor_type: :service_account,
        service_account_id: service_account.id,
        token_scopes: claims["scopes"],
        auth_method: :jwt,
        token_id: claims["jti"]
      })
    else
      _ -> nil
    end
  end

  defp build_jwt_scope(config, scope_module, claims) do
    build_user_scope(config, scope_module, claims["sub"], %{
      token_scopes: claims["scopes"],
      auth_method: :jwt,
      token_id: claims["jti"],
      actor_type: :user
    })
  end

  defp build_user_scope(config, scope_module, user_id, extra) do
    case config.repo.get(config.user_schema, user_id) do
      nil -> nil
      user -> build_scope(scope_module, Map.merge(%{user: user}, extra))
    end
  end

  defp build_scope(scope_module, attrs) do
    scope_module.new(attrs)
  end

  defp load_organization(config, org_id) do
    with organizations_module when not is_nil(organizations_module) <- Map.get(config, :organizations_module),
         %{schemas: %{organization: org_schema}} <- organizations_module.__sigra_org_config__() do
      config.repo.get(org_schema, org_id)
    else
      _ -> nil
    end
  end

  defp maybe_audit_jwt_failure(config, raw_token, reason) do
    if Keyword.get(config.jwt, :enabled, false) and String.starts_with?(raw_token, "eyJ") do
      claims = peek_jwt_payload(raw_token)

      if claims["actor_type"] == "service_account" do
        audit_reason =
          case reason do
            :epoch_mismatch -> :token_revoked
            :token_expired -> :token_expired
            _ -> :invalid_token
          end

        ServiceAccounts.commit_verify_failure_audit(config, claims, audit_reason)
      end
    end
  rescue
    _ -> :ok
  end

  defp peek_jwt_payload(raw_token) do
    if Code.ensure_loaded?(JOSE.JWT) and function_exported?(JOSE.JWT, :peek_payload, 1) do
      apply(JOSE.JWT, :peek_payload, [raw_token]).fields
    else
      %{}
    end
  end

  defp extract_bearer_token(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ -> :error
    end
  end
end
