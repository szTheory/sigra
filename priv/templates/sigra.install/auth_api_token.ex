  ## API Token Management

  alias <%= context_module %>.UserAPIToken

  @doc "Creates a new API token for the user. Returns `{:ok, raw_key, token}` on success."
  def create_api_token(user, attrs) do
    Sigra.Auth.create_api_token(sigra_config(), user, attrs)
  end

  @doc "Revokes a specific API token by ID."
  def revoke_api_token(token_id) do
    Sigra.Auth.revoke_api_token(sigra_config(), token_id)
  end

  @doc "Revokes all API tokens for a user."
  def revoke_all_api_tokens(user) do
    Sigra.Auth.revoke_all_api_tokens(sigra_config(), user)
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
