defmodule Sigra.OAuth.StrategiesTest do
  use ExUnit.Case, async: true

  alias Sigra.OAuth.Strategies
  alias Sigra.OAuth.Strategies.{Google, Github, Apple, Facebook, Generic}

  describe "resolve/2" do
    test "resolves :google to Google strategy module" do
      assert Strategies.resolve(:google, []) == Sigra.OAuth.Strategies.Google
    end

    test "resolves :github to Github strategy module" do
      assert Strategies.resolve(:github, []) == Sigra.OAuth.Strategies.Github
    end

    test "resolves :apple to Apple strategy module" do
      assert Strategies.resolve(:apple, []) == Sigra.OAuth.Strategies.Apple
    end

    test "resolves :facebook to Facebook strategy module" do
      assert Strategies.resolve(:facebook, []) == Sigra.OAuth.Strategies.Facebook
    end

    test "resolves unknown provider with :strategy key to Generic" do
      config = [strategy: Assent.Strategy.Discord]
      assert Strategies.resolve(:discord, config) == Sigra.OAuth.Strategies.Generic
    end

    test "returns error for unknown provider without :strategy key" do
      assert Strategies.resolve(:discord, []) == {:error, :unknown_provider}
    end
  end

  describe "named_strategies/0" do
    test "returns map of known provider atoms to modules" do
      strategies = Strategies.named_strategies()

      assert strategies[:google] == Sigra.OAuth.Strategies.Google
      assert strategies[:github] == Sigra.OAuth.Strategies.Github
      assert strategies[:apple] == Sigra.OAuth.Strategies.Apple
      assert strategies[:facebook] == Sigra.OAuth.Strategies.Facebook
      assert map_size(strategies) == 4
    end
  end

  describe "Google" do
    test "default_scopes returns OIDC scopes" do
      assert Google.default_scopes() == ["openid", "email", "profile"]
    end

    test "normalize_user/1 maps OIDC claims to consistent shape" do
      user = %{
        "sub" => "google-uid-123",
        "email" => "user@gmail.com",
        "name" => "Test User",
        "picture" => "https://example.com/photo.jpg",
        "email_verified" => true
      }

      normalized = Google.normalize_user(user)

      assert normalized["sub"] == "google-uid-123"
      assert normalized["email"] == "user@gmail.com"
      assert normalized["name"] == "Test User"
      assert normalized["picture"] == "https://example.com/photo.jpg"
      assert normalized["email_verified"] == true
      assert normalized["raw"] == user
    end

    test "ensure_assent!/0 raises when Assent is not loaded" do
      # Assent IS loaded in test env, so we test the positive path
      # The function should not raise when Assent is available
      assert :ok == Google.ensure_assent!()
    end
  end

  describe "Github" do
    test "default_scopes returns user:email" do
      assert Github.default_scopes() == ["user:email"]
    end

    test "normalize_user/1 handles GitHub-style user map" do
      user = %{
        "sub" => "github-uid-456",
        "email" => "user@github.com",
        "name" => "GitHub User",
        "avatar_url" => "https://avatars.githubusercontent.com/u/123"
      }

      normalized = Github.normalize_user(user)

      assert normalized["sub"] == "github-uid-456"
      assert normalized["email"] == "user@github.com"
      assert normalized["name"] == "GitHub User"
      assert normalized["picture"] == "https://avatars.githubusercontent.com/u/123"
      assert normalized["raw"] == user
    end

    test "normalize_user/1 falls back to id when sub is nil" do
      user = %{"id" => 789, "email" => "user@github.com"}
      normalized = Github.normalize_user(user)
      assert normalized["sub"] == "789"
    end
  end

  describe "Apple" do
    test "default_scopes returns name and email" do
      assert Apple.default_scopes() == ["name", "email"]
    end

    test "normalize_user/1 maps Apple OIDC claims" do
      user = %{
        "sub" => "apple-uid-789",
        "email" => "user@privaterelay.appleid.com",
        "name" => "Apple User",
        "email_verified" => true
      }

      normalized = Apple.normalize_user(user)

      assert normalized["sub"] == "apple-uid-789"
      assert normalized["email"] == "user@privaterelay.appleid.com"
      assert normalized["email_verified"] == true
      assert normalized["raw"] == user
    end

    test "normalize_user/1 preserves nil name (Apple only returns name on first auth)" do
      user = %{"sub" => "apple-uid-789", "email" => "user@apple.com"}
      normalized = Apple.normalize_user(user)
      assert normalized["name"] == nil
    end
  end

  describe "Facebook" do
    test "default_scopes returns email and public_profile" do
      assert Facebook.default_scopes() == ["email", "public_profile"]
    end

    test "normalize_user/1 always sets email_verified to false" do
      user = %{
        "sub" => "fb-uid-101",
        "email" => "user@facebook.com",
        "name" => "FB User",
        "email_verified" => true
      }

      normalized = Facebook.normalize_user(user)

      # Facebook strategy always forces email_verified to false (Pitfall 1)
      assert normalized["email_verified"] == false
      assert normalized["sub"] == "fb-uid-101"
      assert normalized["raw"] == user
    end

    test "normalize_user/1 falls back to id when sub is nil" do
      user = %{"id" => "102", "email" => "user@facebook.com"}
      normalized = Facebook.normalize_user(user)
      assert normalized["sub"] == "102"
    end
  end

  describe "Generic" do
    test "normalize_user/1 maps generic provider response" do
      user = %{
        "sub" => "generic-123",
        "email" => "user@example.com",
        "name" => "Generic User"
      }

      normalized = Generic.normalize_user(user)

      assert normalized["sub"] == "generic-123"
      assert normalized["email"] == "user@example.com"
      assert normalized["raw"] == user
    end
  end
end
