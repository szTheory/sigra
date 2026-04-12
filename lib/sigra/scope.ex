defmodule Sigra.Scope do
  @moduledoc """
  Library-side scope helpers. The `%Scope{}` struct itself is generated
  into the host app — this module only provides constructors that work
  via `struct/2` reflection on the host's module.

  Used by:
  - Login-time scope synthesis in `Sigra.Auth` (D-27 in 15-CONTEXT.md)
  - Worker reference implementation `Sigra.Workers.AccountDeletion` (D-21, D-22)

  **Worker scopes are audit-only.** Host apps MUST NOT pass a worker-reconstructed
  scope to authorization functions — the minimal skeleton does not carry a real
  request context.
  """

  @spec build(scope_module :: module(), user :: struct() | map() | nil, opts :: keyword()) ::
          struct()
  def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
    struct(scope_module,
      user: user,
      active_organization: Keyword.get(opts, :active_organization),
      membership: Keyword.get(opts, :membership),
      impersonating_from: nil
    )
  end
end
