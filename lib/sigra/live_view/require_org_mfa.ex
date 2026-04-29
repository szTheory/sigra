defmodule Sigra.LiveView.RequireOrgMfa do
  @moduledoc """
  LiveView `on_mount` companion for `Sigra.Plug.RequireOrgMfa`.
  """

  @default_enrollment_path "/users/settings/mfa"

  def on_mount(opts, _params, _session, socket) when is_list(opts) do
    mfa_check_fn = Keyword.fetch!(opts, :mfa_check_fn)
    enrollment_path = Keyword.get(opts, :enrollment_path, @default_enrollment_path)
    scope = socket.assigns[:current_scope]

    cond do
      is_nil(scope) or is_nil(scope.user) or is_nil(scope.active_organization) ->
        {:cont, socket}

      Map.get(scope.active_organization, :enforce_mfa_for_members, false) == false ->
        {:cont, socket}

      mfa_check_fn.(scope.user) ->
        {:cont, socket}

      true ->
        {:halt, put_in(socket.assigns[:sigra_redirect_to], enrollment_path)}
    end
  end
end
