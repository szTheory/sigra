defmodule Sigra.Plug.CredentialAuth do
  @moduledoc false

  @spec put_verified_scope(Plug.Conn.t(), module(), struct() | map(), atom(), map()) ::
          Plug.Conn.t()
  def put_verified_scope(conn, scope_module, user, credential_kind, credential) do
    facts = %{
      credential_kind: credential_kind,
      credential_id: Map.fetch!(credential, :id),
      scopes: Map.fetch!(credential, :scopes),
      auth_method: Map.fetch!(credential, :auth_method),
      assurance: Map.fetch!(credential, :assurance)
    }

    conn
    |> Plug.Conn.assign(:current_scope, build_scope(scope_module, user))
    |> Plug.Conn.put_private(:sigra_auth, facts)
  end

  @spec build_scope(module(), struct() | map()) :: struct() | map()
  def build_scope(scope_module, user) do
    if struct_scope_module?(scope_module) do
      Sigra.Scope.build(scope_module, user, [])
    else
      scope_module.new(user)
    end
  end

  defp struct_scope_module?(scope_module) do
    is_map(scope_module.__struct__())
  rescue
    UndefinedFunctionError -> false
  end
end
