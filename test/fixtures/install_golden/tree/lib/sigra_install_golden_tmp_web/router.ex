defmodule SigraInstallGoldenTmpWeb.Router do
  use SigraInstallGoldenTmpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SigraInstallGoldenTmpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

  # Enable LiveDashboard in development
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
    end
  end

  # Sigra authentication
  import SigraInstallGoldenTmpWeb.UserAuth

  pipeline :require_authenticated do
    plug :require_authenticated_user
    plug :require_mfa
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

    live "/settings/mfa", MFASettingsLive

    live "/settings", SettingsLive, :edit
    live "/reactivation", ReactivationLive

  end

end
