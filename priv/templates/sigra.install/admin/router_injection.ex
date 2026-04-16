  pipeline :admin_global do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: <%= web_module %>.AuthErrorHandler,
      policy: <%= app_module %>.SigraAdminPolicy,
      mode: :global
  end

  pipeline :admin_organization do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: <%= web_module %>.AuthErrorHandler,
      policy: <%= app_module %>.SigraAdminPolicy,
      mode: :organization,
      organizations: <%= app_module %>.Organizations
  end

  # Sigra admin
  scope "/", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_global]

    live_session :admin_global,
      layout: {<%= web_module %>.Layouts, :admin},
      on_mount: [
        {<%= web_module %>.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [mode: :global, policy: <%= app_module %>.SigraAdminPolicy, login_path: "/users/log_in"]}
      ] do
      live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
    end
  end

  scope "/admin/organizations/:org", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_organization]

    live_session :admin_organization,
      layout: {<%= web_module %>.Layouts, :admin},
      on_mount: [
        {<%= web_module %>.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [
           mode: :organization,
           organizations: <%= app_module %>.Organizations,
           policy: <%= app_module %>.SigraAdminPolicy,
           login_path: "/users/log_in"
         ]}
      ] do
      live "/", Elixir.Sigra.Admin.Live.OrganizationLive, :show
    end
  end
