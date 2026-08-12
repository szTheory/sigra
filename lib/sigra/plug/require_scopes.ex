defmodule Sigra.Plug.RequireScopes do
  @moduledoc """
  Route-level scope enforcement plug for explicitly scoped credentials.

  Checks server-produced credential facts in `conn.private[:sigra_auth]` after
  identity has been established in `conn.assigns.current_scope`. It never uses
  authorization-shaped fields from a host Scope.

  ## Options

  - `:scopes` (required) - A non-empty list of required scope strings
  - `:error_handler` (required) - Module implementing `Sigra.Plug.ErrorHandler`
  - `:match` - `:all` (default) requires all scopes, `:any` requires at least one

  ## Examples

      # Require all listed scopes (AND mode, default)
      plug Sigra.Plug.RequireScopes,
        scopes: ["profile:read", "sessions:read"],
        error_handler: MyAppWeb.AuthErrorHandler

      # Require any listed scope (OR mode)
      plug Sigra.Plug.RequireScopes,
        scopes: ["admin:write", "profile:write"],
        error_handler: MyAppWeb.AuthErrorHandler,
        match: :any

  Browser and app-session credentials establish identity but do not receive a
  scope bypass. Only verified personal access tokens and JWTs can authorize
  scoped routes.
  """

  @behaviour Plug

  @doc """
  Initialize the plug with the given options.

  Validates that `:scopes` is a non-empty list and `:error_handler` is present.
  """
  @doc since: "0.7.0"
  @impl Plug
  def init(opts) do
    scopes = Keyword.fetch!(opts, :scopes)

    unless is_list(scopes) and scopes != [] do
      raise ArgumentError, "RequireScopes :scopes must be a non-empty list"
    end

    _ = Keyword.fetch!(opts, :error_handler)
    opts
  end

  @doc """
  Check scope requirements and halt if insufficient.
  """
  @doc since: "0.7.0"
  @impl Plug
  def call(conn, opts) do
    required = Keyword.fetch!(opts, :scopes)
    match_mode = Keyword.get(opts, :match, :all)
    error_handler = Keyword.fetch!(opts, :error_handler)
    scope = conn.assigns[:current_scope]
    provided_scopes = trusted_scopes(conn.private[:sigra_auth])

    cond do
      is_nil(scope) ->
        conn
        |> error_handler.auth_error(:unauthenticated, opts)
        |> Plug.Conn.halt()

      # Wildcard passes all
      "*" in provided_scopes ->
        conn

      has_required_scopes?(provided_scopes, required, match_mode) ->
        conn

      true ->
        error_opts =
          Keyword.merge(opts,
            required_scopes: required,
            provided_scopes: provided_scopes
          )

        conn
        |> error_handler.auth_error(:insufficient_scope, error_opts)
        |> Plug.Conn.halt()
    end
  end

  defp trusted_scopes(%{credential_kind: kind, scopes: scopes})
       when kind in [:personal_access_token, :jwt] and is_list(scopes),
       do: scopes

  defp trusted_scopes(_facts), do: []

  defp has_required_scopes?(provided_scopes, required, :all) do
    MapSet.subset?(MapSet.new(required), MapSet.new(provided_scopes))
  end

  defp has_required_scopes?(provided_scopes, required, :any) do
    Enum.any?(required, &(&1 in provided_scopes))
  end
end
