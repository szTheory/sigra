defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

  # Sigra authentication
  import ExampleWeb.UserAuth

  pipeline :require_authenticated do
    plug :require_authenticated_user
    plug :require_mfa
  end

  # MFA challenge (accessible with mfa_pending sessions, D-24)
  scope "/users", ExampleWeb do
    pipe_through [:browser]

    live "/mfa", MFAChallengeLive

  end

  scope "/users", ExampleWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live "/register", RegistrationLive
    live "/log_in", LoginLive

    post "/log_in", SessionController, :create
    get "/log-in/:token", SessionController, :magic_link

    live "/confirm", ConfirmationLive
    live "/confirm/:token", ConfirmationLive, :confirm


    live "/reset-password", ResetPasswordLive
    live "/reset-password/:token", ResetPasswordLive, :edit

  end

  scope "/users", ExampleWeb do
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
