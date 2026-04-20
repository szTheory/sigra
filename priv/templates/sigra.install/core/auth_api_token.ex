  ## API Token Management

  alias <%= context_module %>.UserAPIToken

  @impersonation_denial_message "You can't manage API tokens while impersonating."

  @doc "Creates a new API token for the user. Returns `{:ok, raw_key, token}` on success."
  def create_api_token(user, attrs, opts \\ []) do
    with :ok <- forbid_api_token_operation(user, "api_token.create", opts) do
      Sigra.Auth.create_api_token(sigra_config(), user, attrs)
    end
  end

  @doc "Revokes a specific API token by ID."
  def revoke_api_token(token_id, opts \\ []) do
    with :ok <- forbid_api_token_operation(nil, "api_token.revoke", opts) do
      Sigra.Auth.revoke_api_token(sigra_config(), token_id)
    end
  end

  @doc "Revokes all API tokens for a user."
  def revoke_all_api_tokens(user, opts \\ []) do
    with :ok <- forbid_api_token_operation(user, "api_token.revoke_all", opts) do
      Sigra.Auth.revoke_all_api_tokens(sigra_config(), user)
    end
  end

  @doc "Lists active API tokens for a user (paginated)."
  def list_api_tokens(user_id, opts \\ []) do
    Sigra.Auth.list_api_tokens(sigra_config(), user_id, opts)
  end

  @doc "Returns available API token scopes."
  def list_api_scopes do
    Sigra.Auth.list_api_scopes(sigra_config())
  end
<%= if jwt do %>
  ## JWT Authentication

  @doc "Generates JWT access and refresh tokens for a user."
  def generate_jwt_tokens(user, scopes) do
    Sigra.Auth.generate_jwt_tokens(sigra_config(), user, scopes)
  end

  @doc "Refreshes JWT tokens using a refresh token."
  def refresh_jwt(raw_refresh_token) do
    Sigra.Auth.refresh_jwt(sigra_config(), raw_refresh_token)
  end

  @doc "Revokes a JWT refresh token."
  def revoke_jwt_refresh(raw_refresh_token) do
    Sigra.Auth.revoke_jwt_refresh(sigra_config(), raw_refresh_token)
  end
<% end %>

  defp forbid_api_token_operation(user, operation, opts) do
    case Keyword.get(opts, :scope) do
      %{impersonating_from: impersonator} = scope when not is_nil(impersonator) ->
        Sigra.Audit.log_safe("admin.impersonation.denied", scope,
          Sigra.Auth.audit_opts_from_config(sigra_config())
          |> Keyword.merge(
            actor_id: impersonator.id,
            target_id: api_token_target_id(user, scope),
            outcome: "failure",
            metadata: %{operation: operation}
          )
        )

        {:error, :impersonation_forbidden, @impersonation_denial_message}

      _ ->
        :ok
    end
  end

  defp api_token_target_id(%{id: id}, _scope), do: id
  defp api_token_target_id(_user, %{user: %{id: id}}), do: id
  defp api_token_target_id(_user, _scope), do: nil
