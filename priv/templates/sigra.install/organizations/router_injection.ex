  # Phase 17 D-06: single unscoped InvitationAcceptLive at
  # /invitations/:token/accept. This route MUST remain outside any
  # `:require_authenticated` pipeline so both anonymous visitors
  # (signup branch) and signed-in visitors (accept / mismatch branch)
  # reach the same LiveView, which branches on `@branch` at mount.
  scope "/", <%= web_module %> do
    pipe_through [:browser]

    live_session :invitations_public,
      on_mount: [{<%= web_module %>.UserAuth, :mount_current_scope}] do
      live "/invitations/:token/accept", InvitationAcceptLive
    end
  end

  # Sigra organizations
  pipeline :org_scoped do
    plug Sigra.Plug.LoadOrganizationFromSlug
    plug Sigra.Plug.RequireMembership,
      error_handler: <%= web_module %>.AuthErrorHandler
  end

  scope "/", <%= web_module %> do
    pipe_through [:browser, :require_authenticated]

    # POST /organizations/switch MUST be defined before the scoped block
    # below so Phoenix's definition-order matching doesn't interpret
    # "switch" as a slug (D-06).
    post "/organizations/switch", OrganizationSwitchController, :update

    live_session :organizations_unscoped,
      on_mount: [
        {<%= web_module %>.UserAuth, :ensure_authenticated},
        {<%= web_module %>.UserAuth, :assign_user_organizations}
      ] do
      live "/organizations", OrganizationsLive.Index, :index
      live "/organizations/new", OrganizationsLive.New, :new
    end
  end

  scope "/organizations/:org", <%= web_module %> do
    pipe_through [:browser]

    get "/sso", EnterpriseSSOController, :new
    post "/sso", EnterpriseSSOController, :create
    get "/sso/callback", EnterpriseSSOController, :callback
  end

  scope "/organizations/:org", <%= web_module %> do
    pipe_through [:browser, :require_authenticated, :org_scoped]

    live_session :organization_scoped,
      on_mount: [
        {<%= web_module %>.UserAuth, :ensure_authenticated},
        {<%= web_module %>.UserAuth, :assign_user_organizations},
        {Sigra.LiveView.OrganizationScope, []}
      ] do
      live "/settings", OrganizationSettingsLive, :edit
      live "/members", OrganizationMembersLive, :index
    end
  end
