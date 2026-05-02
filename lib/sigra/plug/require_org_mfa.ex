defmodule Sigra.Plug.RequireOrgMfa do
  @moduledoc """
  Halts org-scoped requests when the active organization requires MFA and the
  current user is not enrolled.
  """

  @behaviour Plug

  import Plug.Conn

  @default_enrollment_path "/users/settings/mfa"

  @impl Plug
  def init(opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    mfa_check_fn = Keyword.fetch!(opts, :mfa_check_fn)
    enrollment_path = Keyword.get(opts, :enrollment_path, @default_enrollment_path)

    unless is_atom(error_handler) do
      raise ArgumentError,
            "Sigra.Plug.RequireOrgMfa :error_handler must be a module atom, got: #{inspect(error_handler)}"
    end

    unless is_function(mfa_check_fn, 1) do
      raise ArgumentError,
            "Sigra.Plug.RequireOrgMfa :mfa_check_fn must be a 1-arity function, got: #{inspect(mfa_check_fn)}"
    end

    Keyword.merge(opts,
      error_handler: error_handler,
      mfa_check_fn: mfa_check_fn,
      enrollment_path: enrollment_path
    )
  end

  @impl Plug
  def call(%Plug.Conn{} = conn, opts) do
    error_handler = Keyword.fetch!(opts, :error_handler)
    mfa_check_fn = Keyword.fetch!(opts, :mfa_check_fn)
    enrollment_path = Keyword.fetch!(opts, :enrollment_path)
    scope = conn.assigns[:current_scope]

    cond do
      is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization) ->
        conn

      Map.get(scope, :actor_type) == :service_account ->
        conn

      Map.get(scope.active_organization, :enforce_mfa_for_members, false) == false ->
        conn

      mfa_check_fn.(scope.user) ->
        conn

      true ->
        conn
        |> put_session(:user_return_to, safe_return_to(current_request_path(conn), scope))
        |> error_handler.auth_error(:org_mfa_required, enrollment_path: enrollment_path)
        |> halt()
    end
  end

  defp current_request_path(%Plug.Conn{request_path: path, query_string: ""}), do: path
  defp current_request_path(%Plug.Conn{request_path: path, query_string: qs}), do: path <> "?" <> qs

  defp safe_return_to(path, %{active_organization: %{slug: slug}})
       when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      "/organizations/#{slug}"
    end
  end

  defp safe_return_to(_path, %{active_organization: %{slug: slug}}),
    do: "/organizations/#{slug}"

  defp safe_return_to(_path, _scope), do: "/organizations"
end
