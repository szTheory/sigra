defmodule Sigra.Admin.Users.Actions do
  @moduledoc """
  Scope-aware admin mutations for the user detail surface.
  """

  alias Sigra.Admin.Scope
  alias Sigra.Admin.Users.Detail

  @spec revoke_session(map(), Scope.t(), binary(), binary()) :: :ok
  def revoke_session(config, %Scope{} = admin_scope, user_id, hashed_token)
      when is_binary(user_id) and is_binary(hashed_token) do
    user = Detail.load_user!(config, admin_scope, user_id)
    Sigra.Auth.revoke_session(config, hashed_token, user_id: user.id)
  end

  @spec revoke_all_sessions(map(), Scope.t(), binary()) :: {non_neg_integer(), nil}
  def revoke_all_sessions(config, %Scope{} = admin_scope, user_id) when is_binary(user_id) do
    user = Detail.load_user!(config, admin_scope, user_id)
    Sigra.Auth.delete_all_sessions(config, user.id, user_id: user.id)
  end
end
