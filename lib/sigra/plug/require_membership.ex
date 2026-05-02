defmodule Sigra.Plug.RequireMembership do
  @moduledoc """
  Halts the pipeline unless `conn.assigns[:current_scope]` has a non-nil
  `active_organization` and (optionally) a membership role in the configured
  `:roles` list.

  Structural twin of `Sigra.Plug.RequireScopes` — same `init/1` validation
  pattern, same `error_handler` delegation, same halt shape. Any divergence
  from RequireScopes is a bug. Phase 14 D-05 / D-06 / D-07 / D-21.

  ## Phase 92 / B2B-02 — explicit-only role universe

  As of Phase 92 the library no longer ships a canonical fallback role
  universe. Hosts that gate on `:roles` must thread the
  `:organizations` option through so `init/1` can read the host's
  configured `:roles` from `__sigra_org_config__/0`. Routers that omit
  `:organizations` while passing `:roles` raise an actionable
  `ArgumentError` with the fix.

  Membership-presence-only gating (`:roles` empty or omitted) keeps
  working without `:organizations` because there is nothing to validate.

  ## Options

    * `:error_handler` — **required**. Module implementing
      `Sigra.Plug.ErrorHandler`.

    * `:roles` — optional list of atoms. Default: `[]` (any active
      membership accepted — D-07). When non-empty, `:organizations` is
      required so the plug can validate the requested atoms against the
      host's configured role universe (`__sigra_org_config__/0` `:roles`).

    * `:organizations` — required when `:roles` is non-empty. The host's
      `use Sigra.Organizations` module. `init/1` reads the role universe
      from its `__sigra_org_config__/0` so custom roles
      (`:tenant_lead`, `:viewer`, `:billing`, etc.) are recognized
      without library changes.

  Reads `scope.membership.role` from assigns. **Never re-queries the DB** —
  the membership lookup was already performed by
  `Sigra.Plug.LoadActiveOrganization` and stashed on the scope struct. Set
  membership semantics (D-06): a single-element required-roles list means
  "that role only"; it does NOT imply a role hierarchy.

  ## Example

      plug Sigra.Plug.RequireAuthenticated, error_handler: MyAppWeb.AuthErrorHandler
      plug Sigra.Plug.LoadActiveOrganization,
        organizations: MyApp.Organizations,
        session_store: Sigra.SessionStores.Ecto
      plug Sigra.Plug.RequireMembership,
        error_handler: MyAppWeb.AuthErrorHandler,
        organizations: MyApp.Organizations,
        roles: [:tenant_lead, :site_admin]
  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.

  Validates that `:error_handler` is present, that `:roles` (when given)
  is a list of atoms, and that any non-empty `:roles` is paired with an
  `:organizations` module so the role universe is host-supplied (Phase
  92-01 — no library-canonical fallback). Raises `ArgumentError` with a
  helpful message on misuse.
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

    if required_roles != [] do
      role_universe = resolve_role_universe!(opts)
      invalid = required_roles -- role_universe

      unless invalid == [] do
        raise ArgumentError,
              "Sigra.Plug.RequireMembership :roles contains unknown atoms: " <>
                inspect(invalid) <>
                ". Valid roles (from #{inspect(Keyword.fetch!(opts, :organizations))} " <>
                "via __sigra_org_config__/0): " <> inspect(role_universe)
      end
    end

    opts
    |> Keyword.put(:error_handler, error_handler)
    |> Keyword.put(:roles, required_roles)
  end

  # Phase 92-01 / IN-03: Read the role universe from the host's
  # `use Sigra.Organizations` module. The library no longer ships a
  # canonical fallback list, so an :organizations module is required
  # whenever :roles is non-empty. The error message names the
  # :organizations option so router authors see the fix.
  defp resolve_role_universe!(opts) do
    case Keyword.get(opts, :organizations) do
      nil ->
        raise ArgumentError,
              "Sigra.Plug.RequireMembership :roles is non-empty but :organizations " <>
                "is missing. As of Phase 92 the library no longer ships a canonical " <>
                "role universe — pass `organizations: MyApp.Organizations` so the " <>
                "plug can read the host-configured :roles from __sigra_org_config__/0."

      module when is_atom(module) ->
        try do
          case module.__sigra_org_config__() do
            %{roles: roles} when is_list(roles) and roles != [] ->
              roles

            _ ->
              raise ArgumentError,
                    "Sigra.Plug.RequireMembership :organizations module #{inspect(module)} " <>
                      "did not return a non-empty :roles list from __sigra_org_config__/0. " <>
                      "Set `roles: [...]` in `use Sigra.Organizations` so the role universe " <>
                      "is explicit."
          end
        rescue
          UndefinedFunctionError ->
            raise ArgumentError,
                  "Sigra.Plug.RequireMembership :organizations module #{inspect(module)} " <>
                    "does not export __sigra_org_config__/0. Make sure the module uses " <>
                    "`use Sigra.Organizations` so the role universe is exposed."
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

      Map.get(scope, :actor_type) == :service_account ->
        conn

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
