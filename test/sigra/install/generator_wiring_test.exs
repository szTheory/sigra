defmodule Sigra.Install.GeneratorWiringTest do
  use ExUnit.Case, async: true

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  @base_binding [
    context_module: "MyApp.Auth",
    schema_module: "MyApp.Auth.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    otp_app: :my_app,
    repo_module: "MyApp.Repo",
    app_module: "MyApp",
    app_name: "MyApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    binary_id: false,
    adapter: :postgres,
    organizations?: true,
    passkeys?: true
  ]

  describe "generator file list includes Phase 3 templates" do
    test "emails.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "emails.ex"))
    end

    test "auth_mailer.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "auth_mailer.ex"))
    end

    test "confirmation_controller.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "confirmation_controller.ex"))
    end

    test "confirmation_html.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "confirmation_html.ex"))
    end

    test "reset_password_controller.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "reset_password_controller.ex"))
    end

    test "reset_password_html.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "reset_password_html.ex"))
    end

    test "confirmation_live.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "confirmation_live.ex"))
    end

    test "reset_password_live.ex template exists" do
      assert File.exists?(Path.join(@template_dir, "reset_password_live.ex"))
    end
  end

  describe "auth.ex template wiring" do
    test "email request helpers receive configured limiter and per-flow windows" do
      content = render_template("auth.ex")

      assert content =~ "rate_limiter: Keyword.get(config.rate_limiting, :limiter)"
      assert content =~ "max_requests: Keyword.get(config.magic_link, :max_requests, 3)"
      assert content =~ "window_ms: Keyword.get(config.magic_link, :window_seconds, 900) * 1_000"
      assert content =~ "max_requests: Keyword.get(config.reset, :max_requests, 3)"
      assert content =~ "window_ms: Keyword.get(config.reset, :window_seconds, 900) * 1_000"
      assert content =~ "magic_link_ttl: Keyword.get(config.magic_link, :ttl, 600)"

      assert content =~
               "reset_ttl = Keyword.get(sigra_config().token_ttl, :reset_password, 3_600)"

      assert content =~ "reset_ttl: reset_ttl"
      assert content =~ "rate_limiting: Keyword.get(runtime_config, :rate_limiting"
      assert content =~ "token_ttl: Keyword.get(runtime_config, :token_ttl"
      assert content =~ "magic_link: Keyword.get(runtime_config, :magic_link"
      assert content =~ "reset: Keyword.get(runtime_config, :reset"
    end

    test "contains Sigra.Auth.generate_confirmation_token call" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Auth.generate_confirmation_token(Repo, user,"
    end

    test "contains Sigra.Delivery.deliver for confirmation" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Delivery.deliver(:confirmation, %{"
    end

    test "contains Sigra.Delivery.deliver for reset_password" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Delivery.deliver(:reset_password, %{"
    end

    test "contains confirm_user_by_code function" do
      content = render_template("auth.ex")
      assert content =~ "def confirm_user_by_code(%User{} = user, code)"
    end

    test "contains Sigra.Auth.confirm_user call" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Auth.confirm_user(Repo, signed_token,"
    end

    test "contains Sigra.Auth.request_password_reset call" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Auth.request_password_reset(Repo, email,"
    end

    test "register_user triggers confirmation email" do
      content = render_template("auth.ex")
      assert content =~ "deliver_user_confirmation_instructions(user, confirmation_url_fun)"
    end

    test "register_user accepts confirmation_url_fun option" do
      content = render_template("auth.ex")
      assert content =~ "confirmation_url_fun = Keyword.get(opts, :confirmation_url_fun)"
    end

    test "contains delivery_opts private function" do
      content = render_template("auth.ex")
      assert content =~ "defp delivery_opts do"
    end

    test "delivery_opts references the generated Mailer module" do
      content = render_template("auth.ex")
      assert content =~ "mailer: MyApp.Auth.Mailer"
    end

    test "uses Emails module for building email structs" do
      content = render_template("auth.ex")
      assert content =~ "MyApp.Auth.Emails.confirmation_email(user, url, code)"
      assert content =~ "MyApp.Auth.Emails.reset_password_email(user, url)"
    end

    test "get_user_by_reset_password_token uses HMAC verification" do
      content = render_template("auth.ex")
      assert content =~ "Plug.Crypto.verify(secret_key_base, \"sigra-reset-token\", signed"
    end

    test "reset_user_password delegates to Sigra.Auth.reset_password" do
      content = render_template("auth.ex")
      assert content =~ "Sigra.Auth.reset_password(Repo, signed_token, attrs,"
    end
  end

  describe "password reset request wiring" do
    test "live and controller templates pass the raw email to the enumeration-safe context" do
      live = render_template("reset_password_live.ex")
      controller = render_template("reset_password_controller.ex")

      assert live =~ "deliver_user_reset_password_instructions(\n        email,"
      assert controller =~ "deliver_user_reset_password_instructions(\n        email,"
      refute live =~ "get_user_by_email(email)"
      refute controller =~ "get_user_by_email(email)"
    end
  end

  describe "controller confirmation request wiring" do
    test "code and resend actions handle anonymous visitors without dereferencing a missing scope" do
      content = render_template("confirmation_controller.ex")

      assert content =~ "case conn.assigns[:current_scope] do"
      assert content =~ "Please sign in to confirm your email."
      refute content =~ "conn.assigns.current_scope.user"
    end
  end

  describe "registration changeset timing" do
    test "registration hashes before the database uniqueness constraint" do
      content = render_template("user.ex")
      registration = content |> String.split("def registration_changeset", parts: 2) |> Enum.at(1)
      registration = registration |> String.split("defp validate_email", parts: 2) |> hd()

      assert registration =~ "validate_email(opts, false)"
      assert content =~ "unique_constraint(changeset, :email, name: :users_email_active_index)"
      assert content =~ "unsafe_validate_unique(changeset, :email, MyApp.Repo)"
    end
  end

  describe "user_token.ex template wiring" do
    test "contains build_confirmation_code_token function" do
      content = render_template("user_token.ex")
      assert content =~ "def build_confirmation_code_token(user, code)"
    end

    test "contains verify_confirmation_code_query function" do
      content = render_template("user_token.ex")
      assert content =~ "def verify_confirmation_code_query(code, user_id)"
    end

    test "days_for_context handles confirm_code" do
      content = render_template("user_token.ex")
      assert content =~ ~s|defp days_for_context("confirm_code")|
    end

    test "confirmation code token uses SHA-256 hash" do
      content = render_template("user_token.ex")
      assert content =~ "Sigra.Token.hash_token(code)"
    end

    test "confirmation code query scopes by user_id" do
      content = render_template("user_token.ex")
      assert content =~ "token.user_id == ^user_id"
    end
  end

  describe "route injection produces correct routes (via Features.Core)" do
    # Phase 11 Wave 4: router route templates moved from sigra.install.ex
    # to Sigra.Install.Features.Core.router_injection/3. Re-point asserts.
    @features_core_path Path.join([
                          File.cwd!(),
                          "lib",
                          "sigra",
                          "install",
                          "features",
                          "core.ex"
                        ])

    test "controller routes include confirmation paths" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(get "/confirm", ConfirmationController, :new)
      assert source =~ ~s(post "/confirm", ConfirmationController, :create)
      assert source =~ ~s(get "/confirm/:token", ConfirmationController, :confirm)
      assert source =~ ~s(post "/confirm/resend", ConfirmationController, :resend)
    end

    test "controller routes include reset password paths" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(get "/reset-password", ResetPasswordController, :new)
      assert source =~ ~s(post "/reset-password", ResetPasswordController, :create)
      assert source =~ ~s(get "/reset-password/:token", ResetPasswordController, :edit)
      assert source =~ ~s(put "/reset-password/:token", ResetPasswordController, :update)
    end

    test "LiveView routes include confirmation paths" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(live "/confirm", ConfirmationLive)
      assert source =~ ~s(live "/confirm/:token", ConfirmationLive, :confirm)
      assert source =~ "live_session :sigra_confirmation"
    end

    test "LiveView routes include reset password paths" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(live "/reset-password", ResetPasswordLive, :new)
      assert source =~ ~s(live "/reset-password/:token", ResetPasswordLive, :edit)
    end
  end

  describe "confirmation LiveView anonymous safety" do
    test "code and resend events require a signed-in scope and provide a login link" do
      content = render_template("confirmation_live.ex")

      assert content =~ "defp with_confirmation_user(socket, callback)"
      assert content =~ "case socket.assigns[:current_scope] do"
      assert content =~ "Please sign in to confirm your email."
      assert content =~ ~s|navigate={~p"/users/log_in"}|
      refute content =~ ~s|%{"user_id" => user_id}|
    end
  end

  describe "Oban queue detection" do
    # Phase 11 Wave 4: moved from sigra.install.ex to
    # Sigra.Install.Features.Core.oban_instructions/1.
    test "Features.Core contains Oban detection logic" do
      source =
        File.read!(Path.join([File.cwd!(), "lib", "sigra", "install", "features", "core.ex"]))

      assert source =~ "oban_instructions"
      assert source =~ "sigra_mailer"
    end
  end

  describe "Swoosh config detection" do
    # Phase 11 Wave 4: moved from sigra.install.ex to
    # Sigra.Install.Features.Core.swoosh_instructions/2.
    test "Features.Core contains Swoosh detection logic" do
      source =
        File.read!(Path.join([File.cwd!(), "lib", "sigra", "install", "features", "core.ex"]))

      assert source =~ "swoosh_instructions"
      assert source =~ "Swoosh.Adapters.Local"
    end
  end

  # -- Helpers --

  defp render_template(name) do
    path = Path.join(@template_dir, name)
    EEx.eval_file(path, @base_binding)
  end
end
