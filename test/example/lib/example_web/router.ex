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

  # MFA challenge (accessible with mfa_pending sessions, D-24)
  scope "/users", ExampleWeb do
    pipe_through [:browser]

    live_session :mfa_challenge, on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}] do
      live "/mfa", MFAChallengeLive
    end
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
      live "/confirm/:token", ConfirmationLive, :confirm

      live "/reset-password", ResetPasswordLive
      live "/reset-password/:token", ResetPasswordLive, :edit
    end

    post "/log_in", SessionController, :create
    get "/log_in/:token", SessionController, :magic_link
  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :require_authenticated]

    delete "/log_out", SessionController, :delete

    get "/sudo", Auth.SudoController, :new
    post "/sudo", Auth.SudoController, :create

    live_session :require_authenticated,
      on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
      live "/sessions", Auth.SessionLive, :index
      live "/settings/mfa", MFASettingsLive
      live "/settings", SettingsLive, :edit
      live "/reactivation", ReactivationLive
    end
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
end
