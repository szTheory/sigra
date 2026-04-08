defmodule Sigra.APIToken.ScopeRegistryTest do
  use ExUnit.Case, async: true

  alias Sigra.APIToken.ScopeRegistry

  defp config(opts \\ []) do
    defaults = [
      repo: MyApp.Repo,
      user_schema: MyApp.User,
      otp_app: :my_app
    ]

    Sigra.Config.new!(Keyword.merge(defaults, opts))
  end

  describe "valid_format?/1" do
    test "returns true for valid resource:action format" do
      assert ScopeRegistry.valid_format?("profile:read") == true
    end

    test "returns true for underscored resource:action" do
      assert ScopeRegistry.valid_format?("api_tokens:write") == true
    end

    test "returns false for uppercase" do
      assert ScopeRegistry.valid_format?("PROFILE:READ") == false
    end

    test "returns false for missing colon" do
      assert ScopeRegistry.valid_format?("nocolon") == false
    end

    test "returns false for empty string" do
      assert ScopeRegistry.valid_format?("") == false
    end

    test "returns true for wildcard *" do
      assert ScopeRegistry.valid_format?("*") == true
    end

    test "returns false for partial wildcard" do
      assert ScopeRegistry.valid_format?("profile:*") == false
    end
  end

  describe "all_scopes/1" do
    test "returns built-in scopes without custom scopes" do
      cfg = config()
      scopes = ScopeRegistry.all_scopes(cfg)

      assert "profile:read" in scopes
      assert "profile:write" in scopes
      assert "sessions:read" in scopes
      assert "sessions:write" in scopes
      assert "api_tokens:read" in scopes
      assert "api_tokens:write" in scopes
      assert "mfa:read" in scopes
      assert "mfa:write" in scopes
      assert length(scopes) == 8
    end

    test "returns built-in + custom scopes" do
      cfg = config(api_token: [custom_scopes: ["billing:read", "billing:write"]])
      scopes = ScopeRegistry.all_scopes(cfg)

      assert "billing:read" in scopes
      assert "billing:write" in scopes
      assert "profile:read" in scopes
      assert length(scopes) == 10
    end
  end

  describe "validate_scopes/2" do
    test "returns :ok for registered scopes" do
      cfg = config()
      assert ScopeRegistry.validate_scopes(cfg, ["profile:read"]) == :ok
    end

    test "returns :ok for multiple registered scopes" do
      cfg = config()
      assert ScopeRegistry.validate_scopes(cfg, ["profile:read", "sessions:write"]) == :ok
    end

    test "returns :ok for wildcard scope" do
      cfg = config()
      assert ScopeRegistry.validate_scopes(cfg, ["*"]) == :ok
    end

    test "returns error for unregistered scopes" do
      cfg = config()

      assert ScopeRegistry.validate_scopes(cfg, ["unknown:scope"]) ==
               {:error, {:unregistered_scopes, ["unknown:scope"]}}
    end

    test "returns error with only unregistered scopes listed" do
      cfg = config()

      assert ScopeRegistry.validate_scopes(cfg, ["profile:read", "unknown:scope"]) ==
               {:error, {:unregistered_scopes, ["unknown:scope"]}}
    end

    test "returns error for empty scopes list" do
      cfg = config()
      assert ScopeRegistry.validate_scopes(cfg, []) == {:error, :scopes_required}
    end

    test "returns error for invalid format scopes" do
      cfg = config()

      assert {:error, {:invalid_format, _}} =
               ScopeRegistry.validate_scopes(cfg, ["nocolon"])
    end

    test "accepts custom scopes from config" do
      cfg = config(api_token: [custom_scopes: ["billing:read"]])
      assert ScopeRegistry.validate_scopes(cfg, ["billing:read"]) == :ok
    end
  end
end
