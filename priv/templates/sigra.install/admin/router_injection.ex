  # Sigra admin
  scope "/", <%= web_module %> do
    pipe_through [:browser, :require_authenticated]

    live_session :admin_global,
      on_mount: [{<%= web_module %>.UserAuth, :ensure_authenticated}] do
      live "/admin", Sigra.Admin.Live.IndexLive, :index
    end
  end

  scope "/admin/organizations/:org", <%= web_module %> do
    pipe_through [:browser, :require_authenticated]

    live_session :admin_organization,
      on_mount: [{<%= web_module %>.UserAuth, :ensure_authenticated}] do
      live "/", Sigra.Admin.Live.OrganizationLive, :show
    end
  end
