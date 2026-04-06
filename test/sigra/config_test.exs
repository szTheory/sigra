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

      assert config.password[:min_length] == 12
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
  end
end
