defmodule Sigra.OAuth.ConfigTest do
  use ExUnit.Case, async: true

  alias Sigra.Config

  @base_opts [repo: Sigra.MockRepo, user_schema: Sigra.MockUser]

  describe "oauth: config section" do
    test "succeeds with valid oauth config" do
      opts =
        @base_opts ++
          [
            oauth: [
              enabled: true,
              providers: [google: [client_id: "x", client_secret: "y"]],
              session_type: :remember_me
            ]
          ]

      config = Config.new!(opts)

      assert config.oauth[:enabled] == true
      assert config.oauth[:providers] == [google: [client_id: "x", client_secret: "y"]]
      assert config.oauth[:session_type] == :remember_me
    end

    test "defaults enabled to true" do
      opts = @base_opts ++ [oauth: []]
      config = Config.new!(opts)
      assert config.oauth[:enabled] == true
    end

    test "supports kill switch with enabled: false (D-63)" do
      opts = @base_opts ++ [oauth: [enabled: false]]
      config = Config.new!(opts)
      assert config.oauth[:enabled] == false
    end

    test "defaults session_type to :remember_me (D-43)" do
      opts = @base_opts ++ [oauth: []]
      config = Config.new!(opts)
      assert config.oauth[:session_type] == :remember_me
    end

    test "defaults link_confirmation to :required (D-01)" do
      opts = @base_opts ++ [oauth: []]
      config = Config.new!(opts)
      assert config.oauth[:link_confirmation] == :required
    end

    test "defaults trust_provider_email to true" do
      opts = @base_opts ++ [oauth: []]
      config = Config.new!(opts)
      assert config.oauth[:trust_provider_email] == true
    end

    test "validates session_type is :standard or :remember_me" do
      opts = @base_opts ++ [oauth: [session_type: :invalid]]

      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(opts)
      end
    end

    test "validates link_confirmation is :required or :auto" do
      opts = @base_opts ++ [oauth: [link_confirmation: :invalid]]

      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(opts)
      end
    end

    test "validates enabled is boolean" do
      opts = @base_opts ++ [oauth: [enabled: "yes"]]

      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(opts)
      end
    end

    test "defaults to empty when oauth not specified" do
      config = Config.new!(@base_opts)
      assert config.oauth[:enabled] == true
      assert config.oauth[:providers] == []
    end
  end

  describe "oauth_enabled?/1" do
    test "returns true when oauth is enabled" do
      config = Config.new!(@base_opts ++ [oauth: [enabled: true]])
      assert Config.oauth_enabled?(config) == true
    end

    test "returns false when oauth is disabled" do
      config = Config.new!(@base_opts ++ [oauth: [enabled: false]])
      assert Config.oauth_enabled?(config) == false
    end
  end

  describe "oauth_providers/1" do
    test "returns providers list from config" do
      config =
        Config.new!(
          @base_opts ++
            [oauth: [providers: [google: [client_id: "x", client_secret: "y"]]]]
        )

      providers = Config.oauth_providers(config)
      assert providers == [google: [client_id: "x", client_secret: "y"]]
    end

    test "returns empty list when no providers configured" do
      config = Config.new!(@base_opts)
      assert Config.oauth_providers(config) == []
    end
  end
end
