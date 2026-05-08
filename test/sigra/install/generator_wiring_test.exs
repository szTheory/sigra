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
      assert content =~ "endpoint_policy: &__MODULE__.webhook_endpoint_policy/1"
      assert content =~ "webhook_subscription_schema: WebhookSubscription"
      assert content =~ "webhook_event_schema: WebhookEvent"
      assert content =~ "webhook_delivery_schema: WebhookDelivery"
      assert content =~ "webhook_delivery_attempt_schema: WebhookDeliveryAttempt"
      assert content =~ ~s(oban_queue: "sigra_webhooks")
      assert content =~ "signature_tolerance: 300"
      assert content =~ "def webhook_endpoint_policy(_context), do: :ok"
      assert content =~ "def webhook_event_types do"
      assert content =~ "Sigra.Webhooks.public_event_types()"
      assert content =~ "def list_webhook_subscriptions do"
      assert content =~ "def create_webhook_subscription(attrs) do"
      assert content =~ "def update_webhook_subscription(subscription, attrs) do"
      assert content =~ "def enable_webhook_subscription(subscription) do"
      assert content =~ "def disable_webhook_subscription(subscription) do"
      assert content =~ "def list_admin_webhook_subscriptions(admin_scope, params \\\\ %{}) do"
      assert content =~ "def get_admin_webhook_subscription!(admin_scope, subscription_id) do"
      assert content =~ "def list_admin_webhook_failures(admin_scope, params \\\\ %{}) do"
      assert content =~ "def get_admin_webhook_delivery!(admin_scope, delivery_id) do"

      assert content =~
               "def replay_admin_webhook_delivery(admin_scope, delivery_id, opts \\\\ []) do"

      assert content =~ "def create_admin_webhook_subscription(admin_scope, attrs) do"

      assert content =~
               "def update_admin_webhook_subscription(admin_scope, subscription_id, attrs) do"

      assert content =~ "def enable_admin_webhook_subscription(admin_scope, subscription_id) do"
      assert content =~ "def disable_admin_webhook_subscription(admin_scope, subscription_id) do"
      assert content =~ "def reveal_admin_webhook_secret(admin_scope, subscription_id) do"
      assert content =~ "def rotate_admin_webhook_secret(admin_scope, subscription_id) do"
      assert content =~ "def prepare_admin_webhook_secret(admin_scope, subscription_id) do"

      assert content =~
               "def discard_prepared_admin_webhook_secret(admin_scope, subscription_id) do"

      assert content =~
               "def start_admin_webhook_secret_overlap(admin_scope, subscription_id, opts \\\\ []) do"

      assert content =~
               "def complete_admin_webhook_secret_rotation(admin_scope, subscription_id) do"

      assert content =~
               "Sigra.Admin.Webhooks.Actions.replay_delivery(sigra_config(), admin_scope, delivery_id, opts)"
    end

    test "example, template, and golden auth surfaces expose the same replay wrapper" do
      example =
        File.read!(Path.join([File.cwd!(), "test", "example", "lib", "example", "accounts.ex"]))

      template = File.read!(Path.join(@template_dir, "auth.ex"))
      golden = render_fixture("lib/sigra_install_golden_tmp/accounts.ex")

      for content <- [example, template, golden] do
        assert content =~
                 "def replay_admin_webhook_delivery(admin_scope, delivery_id, opts \\\\ []) do"

        assert content =~
                 "Sigra.Admin.Webhooks.Actions.replay_delivery(sigra_config(), admin_scope, delivery_id, opts)"
      end
    end

    test "generated migration and schemas for webhook tables exist" do
      migration = render_fixture("priv/repo/migrations/TIMESTAMP_create_webhook_tables.exs")

      subscription =
        render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_subscription.ex")

      event = render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_event.ex")
      delivery = render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex")

      attempt =
        render_fixture("lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex")

      assert migration =~ "create table(:webhook_subscriptions"
      assert migration =~ "create table(:webhook_events"
      assert migration =~ "create table(:webhook_deliveries"
      assert migration =~ "create table(:webhook_delivery_attempts"
      assert migration =~ "add(:signing_secret, :binary, null: false)"
      assert migration =~ "add(:next_signing_secret, :binary)"
      assert migration =~ "add(:rotation_state, :string, null: false, default: \"stable\")"
      assert migration =~ "add(:rotation_prepared_at, :utc_datetime_usec)"
      assert migration =~ "add(:rotation_overlap_started_at, :utc_datetime_usec)"
      assert migration =~ "add(:rotation_retire_after_at, :utc_datetime_usec)"
      assert migration =~ "add(:rotation_completed_at, :utc_datetime_usec)"
      assert migration =~ "add(:rotation_last_changed_by_user_id, :binary_id)"
      assert migration =~ "add(:signing_secret_fingerprint, :string)"
      assert migration =~ "add(:next_signing_secret_fingerprint, :string)"
      assert migration =~ "add(:event_id, :string, null: false)"
      assert migration =~ "add(:delivery_id, :string, null: false)"
      assert migration =~ "add(:attempt_count, :integer, null: false, default: 0)"
      assert migration =~ "add(:replayed_from_webhook_delivery_id"
      assert migration =~ "add(:replay_root_webhook_delivery_id"
      assert migration =~ "add(:replayed_at, :utc_datetime_usec)"
      assert migration =~ "add(:replayed_by_user_id, :binary_id)"
      assert migration =~ "add(:replay_source, :string)"
      assert migration =~ "unique_index(:webhook_deliveries, [:replayed_from_webhook_delivery_id]"
      assert migration =~ "index(:webhook_deliveries, [:replay_root_webhook_delivery_id])"
      assert migration =~ "add(:retry_after_seconds, :integer)"

      assert subscription =~ "schema \"webhook_subscriptions\""
      assert subscription =~ "field :event_types, {:array, :string}, default: []"
      assert subscription =~ "field :signing_secret"
      assert subscription =~ "field :next_signing_secret"
      assert subscription =~ "field :rotation_state, Ecto.Enum"
      assert subscription =~ "values: [:stable, :prepared, :overlap_active, :completed]"
      assert subscription =~ "field :rotation_prepared_at, :utc_datetime_usec"
      assert subscription =~ "field :rotation_overlap_started_at, :utc_datetime_usec"
      assert subscription =~ "field :rotation_retire_after_at, :utc_datetime_usec"
      assert subscription =~ "field :rotation_completed_at, :utc_datetime_usec"
      assert subscription =~ "field :rotation_last_changed_by_user_id, :binary_id"
      assert subscription =~ "field :signing_secret_fingerprint, :string"
      assert subscription =~ "field :next_signing_secret_fingerprint, :string"
      assert event =~ "schema \"webhook_events\""
      assert event =~ "field :event_id, :string"
      assert delivery =~ "schema \"webhook_deliveries\""
      assert delivery =~ "field :delivery_id, :string"
      assert delivery =~ "field :replayed_from_webhook_delivery_id, :binary_id"
      assert delivery =~ "field :replay_root_webhook_delivery_id, :binary_id"
      assert delivery =~ "field :replayed_at, :utc_datetime_usec"
      assert delivery =~ "field :replayed_by_user_id, :binary_id"
      assert delivery =~ "field :replay_source, :string"
      assert delivery =~ "has_many :attempts"
      assert delivery =~ "field :terminal_reason, :string"
      assert attempt =~ "schema \"webhook_delivery_attempts\""
      assert attempt =~ "field :attempt_number, :integer"
      assert attempt =~ "field :retryable, :boolean, default: false"
      assert attempt =~ "field :terminal_reason, :string"
    end

    test "generated admin router and shell expose webhook routes and navigation" do
      router = render_fixture("lib/sigra_install_golden_tmp_web/router.ex")
      shell = render_fixture("lib/sigra_install_golden_tmp_web/components/admin_shell.ex")

      assert router =~
               ~s(live "/admin/webhooks", Elixir.Sigra.Admin.Live.WebhookSubscriptionsIndexLive, :index)

      assert router =~
               ~s(live "/admin/webhooks/failures", Elixir.Sigra.Admin.Live.WebhookDeliveryFailuresLive, :index)

      assert router =~ ~s(live "/admin/webhooks/subscriptions/:id")
      assert router =~ "Elixir.Sigra.Admin.Live.WebhookSubscriptionShowLive"
      assert router =~ ":show"

      assert router =~ ~s(live "/admin/webhooks/deliveries/:id")
      assert router =~ "Elixir.Sigra.Admin.Live.WebhookDeliveryShowLive"

      assert shell =~ "Webhooks"
      assert shell =~ "Failures"
      assert shell =~ ~s(href={~p"/admin/webhooks"})
      assert shell =~ ~s(href={~p"/admin/webhooks/failures"})
    end

    test "admin feature emits a webhook receiver setup document" do
      admin_feature =
        File.read!(Path.join([File.cwd!(), "lib", "sigra", "install", "features", "admin.ex"]))

      doc = render_fixture("docs/webhook_receiver_setup.md")

      assert admin_feature =~ "Path.join([\"docs\", \"webhook_receiver_setup.md\"])"
      assert doc =~ "raw request body"
      assert doc =~ "body_reader"
      assert doc =~ "delivery_id"
      assert doc =~ "SIGRA_WEBHOOK_SECRET_CURRENT"
      assert doc =~ "prepare the next secret"
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
