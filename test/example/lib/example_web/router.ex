defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  # Sigra authentication — imported at top so pipelines can reference function plugs
  import ExampleWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope
  end

  pipeline :browser_passkey_options do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Phase 17 D-06: single unscoped InvitationAcceptLive at
    # /invitations/:token/accept. This route MUST remain outside any
    # `:require_authenticated_user` pipeline so both anonymous visitors
    # (signup branch) and signed-in visitors (accept / mismatch branch)
    # reach the same LiveView, which branches on `@branch` at mount.
    live_session :invitations_public,
      on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}] do
      live "/invitations/:token/accept", InvitationAcceptLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExampleWeb do
  #   pipe_through :api
  # end

  pipeline :require_authenticated do
    plug :require_authenticated_user
    plug :require_mfa
  end

  pipeline :require_sudo do
    plug Sigra.Plug.RequireSudo, error_handler: ExampleWeb.AuthErrorHandler
  end

  pipeline :admin_global do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: ExampleWeb.AuthErrorHandler,
      policy: Example.SigraAdminPolicy,
      mode: :global
  end

  pipeline :admin_organization do
    plug Sigra.Plug.RequireAdminAccess,
      error_handler: ExampleWeb.AuthErrorHandler,
      policy: Example.SigraAdminPolicy,
      mode: :organization,
      organizations: Example.Organizations
  end

  # MFA challenge (accessible with mfa_pending sessions, D-24)
  scope "/users", ExampleWeb do
    pipe_through [:browser_passkey_options]

    post "/mfa/passkey/options", SessionController, :passkey_mfa_options
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser]

    post "/mfa/passkey", SessionController, :complete_mfa_passkey

    live_session :mfa_challenge, on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}] do
      live "/mfa", MFAChallengeLive
    end
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser_passkey_options, :redirect_if_user_is_authenticated]

    post "/log_in/passkey/options", SessionController, :passkey_authentication_options
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    # Phase 10.1.1 B9: login page is a plain controller + HEEx render,
    # NOT a LiveView. Keeping it outside the live_session ensures
    # `Phoenix.Component.form/1` renders a plain `<form action=... method="post">`
    # with no phx-submit interception.
    get "/log_in", SessionController, :new

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{ExampleWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", RegistrationLive

      live "/confirm", ConfirmationLive

      live "/reset-password", ResetPasswordLive
      live "/reset-password/:token", ResetPasswordLive, :edit
    end

    get "/confirm/:token", ConfirmationController, :confirm
    post "/log_in", SessionController, :create
    post "/log_in/passkey", SessionController, :complete_passkey
    get "/log_in/:token", SessionController, :magic_link
  end

  scope "/", ExampleWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/impersonation", Admin.ImpersonationController, :delete
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/log_out", SessionController, :delete

    get "/sudo", Auth.SudoController, :new
    post "/sudo", Auth.SudoController, :create

    live_session :require_authenticated,
      on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
      live "/sessions", Auth.SessionLive, :index
      live "/settings", SettingsLive, :edit
      live "/reactivation", ReactivationLive
    end
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :require_authenticated, :require_sudo]

    live_session :require_authenticated_sudo_mfa,
      on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
      live "/settings/mfa", MFASettingsLive
    end
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser_passkey_options, :require_authenticated, :require_sudo]

    post "/settings/mfa/passkeys/options", SessionController, :passkey_registration_options
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :require_authenticated, :require_sudo]

    post "/settings/mfa/passkeys", SessionController, :complete_passkey_registration
    post "/settings/mfa/passkeys/:id/delete", SessionController, :delete_passkey
  end

  # Dev-only routes for local UAT — Swoosh local-mailbox preview at /dev/mailbox
  # so manual testers can inspect rendered emails (confirmation, password reset,
  # lockout, suspicious login, account lifecycle). Compile-only gate ensures
  # this scope is excluded from prod and test builds.
  if Application.compile_env(:example, :dev_routes) do
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Sigra organizations (Phase 16)
  pipeline :org_scoped do
    plug Sigra.Plug.LoadOrganizationFromSlug,
      error_handler: ExampleWeb.AuthErrorHandler,
      organizations: Example.Organizations,
      session_store: Sigra.SessionStores.Ecto,
      session_store_opts: [repo: Example.Repo, session_schema: Example.Accounts.UserSession],
      scope_module: Example.Accounts.Scope

    plug Sigra.Plug.RequireMembership, error_handler: ExampleWeb.AuthErrorHandler
  end

  scope "/", ExampleWeb do
    pipe_through [:browser, :require_authenticated]

    # POST /organizations/switch MUST be defined before the scoped block
    # below so Phoenix's definition-order matching doesn't interpret
    # "switch" as a slug (D-06).
    post "/organizations/switch", OrganizationSwitchController, :update

    live_session :organizations_unscoped,
      on_mount: [
        {ExampleWeb.UserAuth, :ensure_authenticated},
        {ExampleWeb.UserAuth, :assign_user_organizations}
      ] do
      live "/organizations", OrganizationsLive.Index, :index
      live "/organizations/new", OrganizationsLive.New, :new
    end
  end

  scope "/organizations/:org", ExampleWeb do
    pipe_through [:browser]

    get "/sso", EnterpriseSSOController, :new
    post "/sso", EnterpriseSSOController, :create
    get "/sso/callback", EnterpriseSSOController, :callback
  end

  scope "/organizations/:org", ExampleWeb do
    pipe_through [:browser, :require_authenticated, :org_scoped]

    live_session :organization_scoped,
      on_mount: [
        {ExampleWeb.UserAuth, :ensure_authenticated},
        {ExampleWeb.UserAuth, :assign_user_organizations},
        {Sigra.LiveView.OrganizationScope,
         [organizations: Example.Organizations, scope_module: Example.Accounts.Scope]}
      ] do
      live "/settings", OrganizationSettingsLive, :edit
      live "/members", OrganizationMembersLive, :index
    end
  end

  # Sigra admin
  scope "/", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_global]

    post "/admin/users/:id/impersonation", ExampleWeb.Admin.ImpersonationController, :create
    get "/admin/audit/export.csv", ExampleWeb.Admin.AuditExportController, :index
    get "/admin/users/:id/audit/export.csv", ExampleWeb.Admin.AuditExportController, :index
  end

  scope "/", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_global]

    live_session :admin_global,
      layout: {ExampleWeb.Layouts, :admin},
      on_mount: [
        {ExampleWeb.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
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

    post "/users/:id/impersonation", ExampleWeb.Admin.ImpersonationController, :create
    get "/audit/export.csv", ExampleWeb.Admin.AuditExportController, :index
    get "/users/:id/audit/export.csv", ExampleWeb.Admin.AuditExportController, :index
  end

  scope "/admin/organizations/:org", alias: false do
    pipe_through [:browser, :require_authenticated, :admin_organization]

    live_session :admin_organization,
      layout: {ExampleWeb.Layouts, :admin},
      on_mount: [
        {ExampleWeb.UserAuth, :ensure_authenticated},
        {Sigra.LiveView.AdminScope,
         [
           mode: :organization,
           organizations: Example.Organizations,
           policy: Example.SigraAdminPolicy,
           login_path: "/users/log_in"
         ]}
      ] do
      live "/", Elixir.Sigra.Admin.Live.OrganizationLive, :show
      live "/audit", Elixir.Sigra.Admin.Live.AuditIndexLive, :index
      # Mounted at /admin/organizations/:org/users
      live "/users", Elixir.Sigra.Admin.Live.UsersIndexLive, :index
      # Mounted at /admin/organizations/:org/users/:id
      live "/users/:id", Elixir.Sigra.Admin.Live.UserShowLive, :show
      live "/users/:id/audit", Elixir.Sigra.Admin.Live.AuditUserLive, :show
    end
  end
end
