  @doc """
  `on_mount` callback that assigns `@user_organizations` to the socket.

  Wired into `live_session` entries by the router injection. The switcher
  component reads this assign to render the list of orgs the current user
  can switch into (D-26).

  Shape: `[{%Organization{}, role}]` — the list returned by
  `list_organizations_for_user/1`. This is presentation-only data; security
  checks still go through the scope + membership plugs.
  """
  def on_mount(:assign_user_organizations, _params, _session, socket) do
    socket =
      case socket.assigns[:current_scope] do
        %{user: %{} = user} ->
          orgs_with_roles = <%= app_module %>.Organizations.list_organizations_for_user(user)
          Phoenix.Component.assign(socket, :user_organizations, orgs_with_roles)

        _ ->
          Phoenix.Component.assign(socket, :user_organizations, [])
      end

    {:cont, socket}
  end
