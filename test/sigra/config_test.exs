defmodule Sigra.ConfigTest do
  use ExUnit.Case, async: true

  alias Sigra.Config

  describe "new!/1" do
    test "creates config with required options" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert %Config{} = config
      assert config.repo == MyApp.Repo
      assert config.user_schema == MyApp.User
    end

    test "raises when :repo is missing" do
      assert_raise NimbleOptions.ValidationError, ~r/:repo/, fn ->
        Config.new!(user_schema: MyApp.User)
      end
    end

    test "raises when :user_schema is missing" do
      assert_raise NimbleOptions.ValidationError, ~r/:user_schema/, fn ->
        Config.new!(repo: MyApp.Repo)
      end
    end

    test "raises when :repo is not an atom" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(repo: "not_atom", user_schema: MyApp.User)
      end
    end

    test "raises when given empty options" do
      assert_raise NimbleOptions.ValidationError, ~r/:repo/, fn ->
        Config.new!([])
      end
    end

    test "provides correct password defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.password[:min_length] == 8
      assert config.password[:max_length] == 72
      assert config.password[:hasher] == Sigra.Hashers.Argon2
    end

    test "allows overriding nested password options" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, password: [min_length: 8])

      assert config.password[:min_length] == 8
      # Other defaults remain
      assert config.password[:max_length] == 72
      assert config.password[:hasher] == Sigra.Hashers.Argon2
    end

    test "provides correct session defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.session[:remember_me_max_age] == 1_209_600
      assert config.session[:store] == Sigra.SessionStores.Ecto
    end

    test "provides correct token_ttl defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.token_ttl[:confirm] == 172_800
      assert config.token_ttl[:reset_password] == 3_600
      assert config.token_ttl[:magic_link] == 900
    end

    test "provides correct rate_limiting defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.rate_limiting[:limiter] == nil
      assert config.rate_limiting[:ip_limit] == 10
      assert config.rate_limiting[:ip_window_ms] == 60_000
      assert config.rate_limiting[:account_limit] == 5
    end

    test "accepts optional otp_app" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, otp_app: :my_app)

      assert config.otp_app == :my_app
    end

    test "accepts optional mailer" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, mailer: MyApp.Mailer)

      assert config.mailer == MyApp.Mailer
    end

    test "provides correct password_policy defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.password_policy[:min_length] == 8
      assert config.password_policy[:max_bytes] == 72
      assert config.password_policy[:require_uppercase] == false
      assert config.password_policy[:require_digit] == false
      assert config.password_policy[:require_special] == false
      assert config.password_policy[:check_common] == true
      assert config.password_policy[:check_breached] == false
      assert config.password_policy[:password_max_age] == nil
    end

    test "provides correct magic_link defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.magic_link[:ttl] == 600
      assert config.magic_link[:max_requests] == 3
      assert config.magic_link[:window_seconds] == 900
    end

    test "provides correct require_confirmation default" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.require_confirmation == false
    end

    test "provides correct session_ttl default" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.session_ttl == 5_184_000
    end

    test "allows overriding require_confirmation" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, require_confirmation: true)

      assert config.require_confirmation == true
    end

    test "allows overriding session_ttl" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, session_ttl: 3600)

      assert config.session_ttl == 3600
    end

    # Phase 3: Confirmation config section
    test "accepts confirmation with unconfirmed_access: :allow_with_banner" do
      config =
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          confirmation: [unconfirmed_access: :allow_with_banner]
        )

      assert config.confirmation[:unconfirmed_access] == :allow_with_banner
    end

    test "accepts confirmation with unconfirmed_access: :block" do
      config =
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          confirmation: [unconfirmed_access: :block]
        )

      assert config.confirmation[:unconfirmed_access] == :block
    end

    test "rejects confirmation with unconfirmed_access: :invalid" do
      assert_raise NimbleOptions.ValidationError, ~r/unconfirmed_access/, fn ->
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          confirmation: [unconfirmed_access: :invalid]
        )
      end
    end

    test "accepts confirmation with code_length: 6" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.confirmation[:code_length] == 6
    end

    test "provides correct confirmation defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.confirmation[:unconfirmed_access] == :allow_with_banner
      assert config.confirmation[:code_length] == 6
      assert config.confirmation[:max_resends] == 3
      assert config.confirmation[:resend_window_seconds] == 900
      assert config.confirmation[:code_max_attempts] == 5
      assert config.confirmation[:code_window_seconds] == 900
    end

    # Phase 3: Reset config section
    test "accepts reset with rate_limit options" do
      config =
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          reset: [max_requests: 3, window_seconds: 900]
        )

      assert config.reset[:max_requests] == 3
      assert config.reset[:window_seconds] == 900
    end

    test "provides correct reset defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.reset[:max_requests] == 3
      assert config.reset[:window_seconds] == 900
    end

    # Phase 3: Email config section
    test "accepts email with from_address, delivery_mode, and oban_queue" do
      config =
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          email: [
            from_address: "noreply@example.com",
            delivery_mode: :auto,
            oban_queue: "sigra_mailer"
          ]
        )

      assert config.email[:from_address] == "noreply@example.com"
      assert config.email[:delivery_mode] == :auto
      assert config.email[:oban_queue] == "sigra_mailer"
    end

    test "rejects email with delivery_mode: :invalid" do
      assert_raise NimbleOptions.ValidationError, ~r/delivery_mode/, fn ->
        Config.new!(
          repo: MyApp.Repo,
          user_schema: MyApp.User,
          email: [delivery_mode: :invalid]
        )
      end
    end

    test "provides correct email defaults" do
      config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

      assert config.email[:delivery_mode] == :auto
      assert config.email[:oban_queue] == "sigra_mailer"
      assert config.email[:oban_concurrency] == 10
    end
  end
end
