defmodule <%= context_module %>.JWT do
  @moduledoc """
  Host-policy JWT issuance and refresh delegates.

  This module deliberately accepts neither request parameters nor credentials.
  Call it only after the host has authenticated a user through its selected
  first-party flow and has selected allowed scopes in server-owned policy.
  """

  @doc "Issues access and refresh JWTs using server-owned scope policy."
  def create_jwt_tokens(user) do
    Sigra.Auth.generate_jwt_tokens(sigra_config(), user, jwt_scopes_for(user))
  end

  @doc "Rotates a JWT refresh credential."
  def refresh_jwt(raw_refresh_token) do
    Sigra.Auth.refresh_jwt(sigra_config(), raw_refresh_token)
  end

  @doc "Revokes a JWT refresh credential."
  def revoke_jwt_refresh(raw_refresh_token) do
    Sigra.Auth.revoke_jwt_refresh(sigra_config(), raw_refresh_token)
  end

  # Replace this conservative host policy with the scopes your server grants.
  # It is intentionally not selected by an HTTP request.
  defp jwt_scopes_for(_user), do: ["read"]

  defp sigra_config do
    <%= context_module %>.sigra_config()
  end
end
