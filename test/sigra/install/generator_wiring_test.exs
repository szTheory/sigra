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
    passkeys?: true,
    api: false,
    jwt: false
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
    end

    test "LiveView routes include reset password paths" do
      source = File.read!(@features_core_path)
      assert source =~ ~s(live "/reset-password", ResetPasswordLive)
      assert source =~ ~s(live "/reset-password/:token", ResetPasswordLive, :edit)
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

  describe "webhook wiring" do
    test "generated accounts config includes webhook schemas and queue defaults" do
      content = render_fixture("lib/sigra_install_golden_tmp/accounts.ex")

      assert content =~ "webhooks: ["
      assert content =~ "webhook_subscription_schema: WebhookSubscription"
      assert content =~ "webhook_event_schema: WebhookEvent"
      assert content =~ "webhook_delivery_schema: WebhookDelivery"
      assert content =~ ~s(oban_queue: "sigra_webhooks")
      assert content =~ "def list_webhook_subscriptions do"
      assert content =~ "def create_webhook_subscription(attrs) do"
      assert content =~ "def update_webhook_subscription(subscription, attrs) do"
      assert content =~ "def enable_webhook_subscription(subscription) do"
      assert content =~ "def disable_webhook_subscription(subscription) do"
    end

    test "generated migration and schemas for webhook tables exist" do
      migration = render_fixture("priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs")
      subscription = render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_subscription.ex")
      event = render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_event.ex")
      delivery = render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex")

      assert migration =~ "create table(:webhook_subscriptions"
      assert migration =~ "create table(:webhook_events"
      assert migration =~ "create table(:webhook_deliveries"
      assert migration =~ "add :signing_secret, :binary, null: false"
      assert migration =~ "add :event_id, :string, null: false"
      assert migration =~ "add :delivery_id, :string, null: false"

      assert subscription =~ "schema \"webhook_subscriptions\""
      assert subscription =~ "field :event_types, {:array, :string}, default: []"
      assert subscription =~ "field :signing_secret"
      assert event =~ "schema \"webhook_events\""
      assert event =~ "field :event_id, :string"
      assert delivery =~ "schema \"webhook_deliveries\""
      assert delivery =~ "field :delivery_id, :string"
    end
  end

  # -- Helpers --

  defp render_template(name) do
    path = Path.join(@template_dir, name)
    EEx.eval_file(path, @base_binding)
  end

  defp render_fixture(relative_path) do
    Path.join([File.cwd!(), "test", "fixtures", "install_golden", "tree", relative_path])
    |> File.read!()
  end
end
