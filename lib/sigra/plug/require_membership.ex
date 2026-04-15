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
      organization role universe. Default: `[]` (any active membership
      accepted — D-07). Validation behavior depends on `:organizations`:

        - **Without `:organizations`:** Validated at `init/1` against the
          library's canonical role universe (`[:owner, :admin, :member]`);
          raises `ArgumentError` on typos.

        - **With `:organizations`:** Validated at `init/1` against
          `organizations.__sigra_org_config__().roles`, which is the
          host's actual role list (Phase 14 D-05 / IN-03). This lets hosts
          extend roles (`:viewer`, `:billing`, etc.) via the
          `Sigra.Organizations` config without editing the library.

    * `:organizations` — optional. The host's `use Sigra.Organizations`
      module. When given, `init/1` reads the role universe from its
      `__sigra_org_config__/0` so custom roles are recognized (IN-03). If the
      org module is not yet compiled when the router is compiled, pass
      nothing and the plug falls back to the canonical universe.

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
        organizations: MyApp.Organizations,
        roles: [:owner, :admin]
  """

  @behaviour Plug

  # Canonical fallback universe when no `:organizations` module is provided.
  # Hosts with extended role lists (`:viewer`, `:billing`, etc.) should pass
  # `:organizations` so validation reads the host's actual `:roles` (IN-03).
  @default_role_universe [:owner, :admin, :member]

  @doc """
  Initialize the plug with the given options.

  Validates that `:error_handler` is present and that `:roles` (when given) is
  a list of atoms drawn from the role universe. The role universe is the
  host's `__sigra_org_config__/0` `:roles` when `:organizations` is passed,
  otherwise `[:owner, :admin, :member]`. Raises `ArgumentError` with a
  helpful message on typos.
  """
  @doc since: "0.8.0"
  @impl Plug
  def init(opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    required_roles = Keyword.get(opts, :roles, [])
    role_universe = resolve_role_universe(opts)

    unless is_list(required_roles) and Enum.all?(required_roles, &is_atom/1) do
      raise ArgumentError,
            "Sigra.Plug.RequireMembership :roles must be a list of atoms, got: " <>
              inspect(required_roles)
    end

    invalid = required_roles -- role_universe

    unless invalid == [] do
      raise ArgumentError,
            "Sigra.Plug.RequireMembership :roles contains unknown atoms: " <>
              inspect(invalid) <>
              ". Valid roles: " <> inspect(role_universe)
    end

    opts
    |> Keyword.put(:error_handler, error_handler)
    |> Keyword.put(:roles, required_roles)
  end

  # IN-03: When a host `use Sigra.Organizations` module is passed, read its
  # validated `:roles` list so hosts can extend the role universe without
  # editing the library. If the module is present but not compiled yet (rare
  # — would require a circular compile dep), or the accessor raises, fall
  # back to the canonical list so `init/1` never crashes at compile time on a
  # module-load race.
  defp resolve_role_universe(opts) do
    case Keyword.get(opts, :organizations) do
      nil ->
        @default_role_universe

      module when is_atom(module) ->
        try do
          case module.__sigra_org_config__() do
            %{roles: roles} when is_list(roles) -> roles
            _ -> @default_role_universe
          end
        rescue
          UndefinedFunctionError -> @default_role_universe
        end
    end
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
