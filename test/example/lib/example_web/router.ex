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

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{ExampleWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/register", RegistrationLive
      live "/log_in", LoginLive

      live "/confirm", ConfirmationLive
      live "/confirm/:token", ConfirmationLive, :confirm

      live "/reset-password", ResetPasswordLive
      live "/reset-password/:token", ResetPasswordLive, :edit
    end

    post "/log_in", SessionController, :create
    get "/log-in/:token", SessionController, :magic_link
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
end
