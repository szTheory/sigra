defmodule Sigra.CookieDomainTest do
  use ExUnit.Case, async: true

  alias Sigra.Config
  alias Sigra.MFA.Trust

  @base_opts [repo: MyApp.Repo, user_schema: MyApp.User]

  describe "Sigra.Config :cookie_domain" do
    test "defaults to nil" do
      config = Config.new!(@base_opts)
      assert config.cookie_domain == nil
    end

    test "accepts nil" do
      config = Config.new!(@base_opts ++ [cookie_domain: nil])
      assert config.cookie_domain == nil
    end

    test "accepts string" do
      config = Config.new!(@base_opts ++ [cookie_domain: ".example.com"])
      assert config.cookie_domain == ".example.com"
    end

    test "rejects atom :parent (D-10 forbids atoms)" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(@base_opts ++ [cookie_domain: :parent])
      end
    end

    test "rejects atom :auto (D-10 forbids atoms)" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(@base_opts ++ [cookie_domain: :auto])
      end
    end

    test "rejects integer" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(@base_opts ++ [cookie_domain: 123])
      end
    end
  end

  describe "Sigra.MFA.Trust.cookie_opts/1" do
    test "returns base opts WITHOUT :domain when cookie_domain is nil" do
      config = Config.new!(@base_opts)
      opts = Trust.cookie_opts(config)

      refute Keyword.has_key?(opts, :domain)
      assert opts[:http_only] == true
      assert opts[:secure] == true
      assert opts[:same_site] == "Lax"
    end

    test "returns opts WITH :domain set when cookie_domain is a string" do
      config = Config.new!(@base_opts ++ [cookie_domain: ".example.com"])
      opts = Trust.cookie_opts(config)

      assert opts[:domain] == ".example.com"
      assert opts[:http_only] == true
      assert opts[:secure] == true
      assert opts[:same_site] == "Lax"
    end
  end

  describe "Sigra.MFA.Trust.cookie_opts/0 (deprecated shim)" do
    test "still returns base opts without :domain" do
      # Call via apply/3 to exercise the deprecated shim without tripping
      # compile-time deprecation warnings (warnings-as-errors in CI).
      opts = apply(Trust, :cookie_opts, [])
      refute Keyword.has_key?(opts, :domain)
      assert opts[:http_only] == true
    end
  end
end
