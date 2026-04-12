defmodule Sigra.Plug.RequireMembership do
  @moduledoc """
  Halts the pipeline unless `conn.assigns[:current_scope]` has a non-nil
  `active_organization` and (optionally) a membership role in the configured
  `:roles` list.

  Structural twin of `Sigra.Plug.RequireScopes` — same `init/1` validation
  pattern, same `error_handler` delegation, same halt shape. Any divergence
  from RequireScopes is a bug. Phase 14 D-05 / D-06 / D-07 / D-21.

  ## Options

    * `:error_handler` — **required**. Module implementing
      `Sigra.Plug.ErrorHandler`.

    * `:roles` — optional list of atoms. Must be a subset of the host's
      organization role universe (typically `[:owner, :admin, :member]`).
      Validated at `init/1`; raises `ArgumentError` on typos.
      Default: `[]` (any active membership accepted — D-07).

  Reads `scope.membership.role` from assigns. **Never re-queries the DB** —
  the membership lookup was already performed by
  `Sigra.Plug.LoadActiveOrganization` and stashed on the scope struct. Set
  membership semantics (D-06): `[:owner]` means "owner only"; it does NOT
  imply admin.

  ## Example

      plug Sigra.Plug.RequireAuthenticated, error_handler: MyAppWeb.AuthErrorHandler
      plug Sigra.Plug.LoadActiveOrganization,
        organizations: MyApp.Organizations,
        session_store: Sigra.SessionStores.Ecto
      plug Sigra.Plug.RequireMembership,
        error_handler: MyAppWeb.AuthErrorHandler,
        roles: [:owner, :admin]
  """

  @behaviour Plug

  # The canonical role universe. The host may pass any subset of these atoms
  # via :roles. If the host org config's role list grows, update this module
  # attribute (or switch to a runtime lookup) in lockstep.
  @role_universe [:owner, :admin, :member]

  @doc """
  Initialize the plug with the given options.

  Validates that `:error_handler` is present and that `:roles` (when given) is
  a list of atoms drawn from the canonical role universe. Raises
  `ArgumentError` with a helpful message on typos.
  """
  @doc since: "0.8.0"
  @impl Plug
  def init(opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    required_roles = Keyword.get(opts, :roles, [])

    unless is_list(required_roles) and Enum.all?(required_roles, &is_atom/1) do
      raise ArgumentError,
            "Sigra.Plug.RequireMembership :roles must be a list of atoms, got: " <>
              inspect(required_roles)
    end

    invalid = required_roles -- @role_universe

    unless invalid == [] do
      raise ArgumentError,
            "Sigra.Plug.RequireMembership :roles contains unknown atoms: " <>
              inspect(invalid) <>
              ". Valid roles: " <> inspect(@role_universe)
    end

    opts
    |> Keyword.put(:error_handler, error_handler)
    |> Keyword.put(:roles, required_roles)
  end

  @doc """
  Enforce membership presence and (optionally) role membership, halting via
  the configured error handler on failure.
  """
  @doc since: "0.8.0"
  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    required = Keyword.fetch!(opts, :roles)
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) or is_nil(scope.active_organization) ->
        conn
        |> error_handler.auth_error(:no_active_org, opts)
        |> Plug.Conn.halt()

      required != [] and scope.membership.role not in required ->
        error_opts = Keyword.put(opts, :required_roles, required)

        conn
        |> error_handler.auth_error(:insufficient_role, error_opts)
        |> Plug.Conn.halt()

      true ->
        conn
    end
  end
end
