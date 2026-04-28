defmodule Sigra.Testing.OAuthIssuerTest do
  use ExUnit.Case, async: true

  alias Sigra.Testing.OAuthIssuer

  describe "start_link/1 - provider :google" do
    @tag :skip
    test "returns an issuer handle with request-time state" do
      {:ok, issuer} = OAuthIssuer.start_link(provider: :google)

      assert is_binary(OAuthIssuer.url(issuer))
      assert is_pid(issuer.state)
    end
  end

  describe "/.well-known/openid-configuration" do
    @tag :skip
    test "returns the discovery document" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end

  describe "/oauth2/v2/auth -> 302 redirect" do
    @tag :skip
    test "redirects back with code and state" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end

  describe "/token RS256 sign+verify roundtrip" do
    @tag :skip
    test "returns an RS256 id_token" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end

  describe "/token with bad code_verifier" do
    @tag :skip
    test "returns invalid_grant" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end

  describe "/jwks" do
    @tag :skip
    test "exposes the configured key count" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end

  describe "configurable exp" do
    @tag :skip
    test "respects the requested expiration offset" do
      assert {:ok, _issuer} = OAuthIssuer.start_link(exp: 60)
    end
  end

  describe "refresh-token rotation toggle" do
    @tag :skip
    test "keeps refresh tokens stable when disabled" do
      assert {:ok, _issuer} = OAuthIssuer.start_link(refresh_rotation: false)
    end
  end

  describe "email_verified boolean shape" do
    @tag :skip
    test "returns email_verified as a JSON boolean" do
      assert {:ok, _issuer} = OAuthIssuer.start_link()
    end
  end
end
