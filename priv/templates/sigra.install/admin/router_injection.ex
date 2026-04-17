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

    post "/admin/users/:id/impersonation", <%= web_module %>.Admin.ImpersonationController, :create
    get "/admin/audit/export.csv", <%= web_module %>.Admin.AuditExportController, :index
    get "/admin/users/:id/audit/export.csv", <%= web_module %>.Admin.AuditExportController, :index
  end

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
      live "/admin/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
      live "/admin/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
      live "/admin/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
      live "/admin/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
    end
  end

  scope "/admin/organizations/:org", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_organization]

    post "/users/:id/impersonation", <%= web_module %>.Admin.ImpersonationController, :create
    get "/audit/export.csv", <%= web_module %>.Admin.AuditExportController, :index
    get "/users/:id/audit/export.csv", <%= web_module %>.Admin.AuditExportController, :index
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
      live "/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
      live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
      live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
      live "/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
    end
  end

  scope "/", <%= web_module %> do
    pipe_through [:browser, :require_authenticated]

    delete "/impersonation", Admin.ImpersonationController, :delete
  end
