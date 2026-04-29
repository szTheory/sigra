defmodule SigraInstallGoldenTmpWeb.Router do
  use SigraInstallGoldenTmpWeb, :router

  import SigraInstallGoldenTmpWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SigraInstallGoldenTmpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SigraInstallGoldenTmpWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", SigraInstallGoldenTmpWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sigra_install_golden_tmp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SigraInstallGoldenTmpWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Sigra authentication

  pipeline :require_authenticated do
    plug :require_authenticated_user
    plug :require_mfa
  end

  pipeline :require_sudo do
    plug Sigra.Plug.RequireSudo, error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler
  end

  # Phase 14 Plan 03 / Phase 92 (CR-01): organization-aware pipeline (opt-in).
  # Apps that want to gate routes by active organization membership
  # pipe_through :require_org. Role-gated pipelines are intentionally
  # NOT generated — Phase 92 makes the role taxonomy host-owned, so
  # the library cannot ship a `:require_org_owner` pipeline without
  # baking an opinion. See guides/recipes/role-based-access-control.md
  # for the recipe pattern (host writes its own role-gated pipeline
  # threading `organizations: MyApp.Organizations, roles: [...]`).
  pipeline :require_org do
    plug Sigra.Plug.RequireMembership, error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler
  end

  # MFA challenge (accessible with mfa_pending sessions, D-24)
  scope "/users", SigraInstallGoldenTmpWeb do
    pipe_through [:browser]

    live "/mfa", MFAChallengeLive

  end

  scope "/users", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    # Phase 10.1.1 B9: login page is a plain controller, not a LiveView.
    get "/log_in", SessionController, :new

    live "/register", RegistrationLive

    post "/log_in", SessionController, :create
    get "/log_in/:token", SessionController, :magic_link

    live "/confirm", ConfirmationLive
    live "/confirm/:token", ConfirmationLive, :confirm


    live "/reset-password", ResetPasswordLive
    live "/reset-password/:token", ResetPasswordLive, :edit

  end

  scope "/users", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/log_out", SessionController, :delete

    live "/sessions", Auth.SessionLive, :index

      get "/sudo", Auth.SudoController, :new
      post "/sudo", Auth.SudoController, :create

    live "/settings", SettingsLive, :edit
    live "/reactivation", ReactivationLive

  end

  scope "/users", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :require_authenticated, :require_sudo]

    live "/settings/mfa", MFASettingsLive

  end


  # Phase 17 D-06: single unscoped InvitationAcceptLive at
  # /invitations/:token/accept. This route MUST remain outside any
  # `:require_authenticated` pipeline so both anonymous visitors
  # (signup branch) and signed-in visitors (accept / mismatch branch)
  # reach the same LiveView, which branches on `@branch` at mount.
  scope "/", SigraInstallGoldenTmpWeb do
    pipe_through [:browser]

    live_session :invitations_public,
      on_mount: [{SigraInstallGoldenTmpWeb.UserAuth, :mount_current_scope}] do
      live "/invitations/:token/accept", InvitationAcceptLive
    end
  end

  # Sigra organizations
  pipeline :org_scoped do
    plug Sigra.Plug.LoadOrganizationFromSlug
    plug Sigra.Plug.RequireMembership,
      error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler
    plug Sigra.Plug.RequireOrgMfa,
      error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler,
      mfa_check_fn: &SigraInstallGoldenTmp.Accounts.mfa_enabled?/1
  end

  scope "/", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :require_authenticated]

    # POST /organizations/switch MUST be defined before the scoped block
    # below so Phoenix's definition-order matching doesn't interpret
    # "switch" as a slug (D-06).
    post "/organizations/switch", OrganizationSwitchController, :update

    live_session :organizations_unscoped,
      on_mount: [
        {SigraInstallGoldenTmpWeb.UserAuth, :ensure_authenticated},
        {SigraInstallGoldenTmpWeb.UserAuth, :assign_user_organizations}
      ] do
      live "/organizations", OrganizationsLive.Index, :index
      live "/organizations/new", OrganizationsLive.New, :new
    end
  end

  scope "/organizations/:org", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :require_authenticated, :org_scoped]

    live_session :organization_scoped,
      on_mount: [
        {SigraInstallGoldenTmpWeb.UserAuth, :ensure_authenticated},
        {SigraInstallGoldenTmpWeb.UserAuth, :assign_user_organizations},
        {Sigra.LiveView.OrganizationScope, []},
        {Sigra.LiveView.RequireOrgMfa, [mfa_check_fn: &SigraInstallGoldenTmp.Accounts.mfa_enabled?/1]}
      ] do
      live "/settings", OrganizationSettingsLive, :edit
      live "/members", OrganizationMembersLive, :index
    end
  end


# Sigra passkeys
scope "/users", SigraInstallGoldenTmpWeb do
  pipe_through [:browser]

  post "/mfa/passkey", SessionController, :complete_mfa_passkey
  post "/mfa/passkey/options", SessionController, :passkey_mfa_options
end

scope "/users", SigraInstallGoldenTmpWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  post "/log_in/passkey", SessionController, :complete_passkey
  post "/log_in/passkey/options", SessionController, :passkey_authentication_options
end

scope "/users", SigraInstallGoldenTmpWeb do
  pipe_through [:browser, :require_authenticated, :require_sudo]

  post "/settings/mfa/passkeys/options", SessionController, :passkey_registration_options
  post "/settings/mfa/passkeys", SessionController, :complete_passkey_registration
  post "/settings/mfa/passkeys/:id/delete", SessionController, :delete_passkey
end


  pipeline :admin_global do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler,
      policy: SigraInstallGoldenTmp.SigraAdminPolicy,
      mode: :global
  end

  pipeline :admin_organization do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: SigraInstallGoldenTmpWeb.AuthErrorHandler,
      policy: SigraInstallGoldenTmp.SigraAdminPolicy,
      mode: :organization,
      organizations: SigraInstallGoldenTmp.Organizations
  end

  # Sigra admin
  scope "/", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_global]

    post "/admin/users/:id/impersonation", SigraInstallGoldenTmpWeb.Admin.ImpersonationController, :create
    get "/admin/audit/export.csv", SigraInstallGoldenTmpWeb.Admin.AuditExportController, :index
    get "/admin/users/:id/audit/export.csv", SigraInstallGoldenTmpWeb.Admin.AuditExportController, :index
  end

  scope "/", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_global]

    live_session :admin_global,
      layout: {SigraInstallGoldenTmpWeb.Layouts, :admin},
      on_mount: [
        {SigraInstallGoldenTmpWeb.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [mode: :global, policy: SigraInstallGoldenTmp.SigraAdminPolicy, login_path: "/users/log_in"]}
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

    post "/users/:id/impersonation", SigraInstallGoldenTmpWeb.Admin.ImpersonationController, :create
    get "/audit/export.csv", SigraInstallGoldenTmpWeb.Admin.AuditExportController, :index
    get "/users/:id/audit/export.csv", SigraInstallGoldenTmpWeb.Admin.AuditExportController, :index
  end

  scope "/admin/organizations/:org", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_organization]

    live_session :admin_organization,
      layout: {SigraInstallGoldenTmpWeb.Layouts, :admin},
      on_mount: [
        {SigraInstallGoldenTmpWeb.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [
           mode: :organization,
           organizations: SigraInstallGoldenTmp.Organizations,
           policy: SigraInstallGoldenTmp.SigraAdminPolicy,
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

  scope "/", SigraInstallGoldenTmpWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/impersonation", Admin.ImpersonationController, :delete
  end

end
