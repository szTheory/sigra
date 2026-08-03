defmodule Sigra.EnterpriseConnections.ValidationTest do
  use ExUnit.Case, async: true

  alias Sigra.EnterpriseConnections.Validation

  defmodule TestOIDCSettings do
    defstruct [
      :issuer,
      :discovery_document_uri,
      :client_id,
      :encrypted_client_secret,
      :client_authentication_method,
      :scopes
    ]
  end

  defmodule TestConnection do
    defstruct [:oidc_settings]
  end

  test "accepts a discovery document with OIDC-required endpoints" do
    connection =
      %TestConnection{
        oidc_settings: %TestOIDCSettings{
          issuer: "https://issuer.example",
          client_id: "client-123",
          encrypted_client_secret: "secret",
          client_authentication_method: "client_secret_basic",
          scopes: ["openid", "email"]
        }
      }

    config = %{
      dns_resolver: fn _host -> {:ok, [{93, 184, 216, 34}]} end,
      http_client: fn opts ->
        assert Keyword.fetch!(opts, :url) ==
                 "https://issuer.example/.well-known/openid-configuration"

        assert Keyword.fetch!(opts, :redirect) == false

        {:ok,
         %{
           status: 200,
           body: %{
             "issuer" => "https://issuer.example",
             "authorization_endpoint" => "https://issuer.example/auth",
             "token_endpoint" => "https://issuer.example/token",
             "jwks_uri" => "https://issuer.example/jwks"
           }
         }}
      end
    }

    assert {:ok, %{validated_at: %DateTime{}}} = Validation.validate(config, connection)
  end

  for {description, uri, expected_message} <- [
        {"an HTTP loopback URL", "http://127.0.0.1/.well-known/openid-configuration",
         "OIDC discovery URL must use HTTPS."},
        {"a link-local metadata URL", "https://169.254.169.254/.well-known/openid-configuration",
         "OIDC discovery host resolves to a private address."},
        {"an IPv6 loopback URL", "https://[::1]/.well-known/openid-configuration",
         "OIDC discovery host resolves to a private address."}
      ] do
    test "rejects #{description} before making an HTTP request" do
      connection = connection_with_discovery_uri(unquote(uri))

      assert {:error, :validation_failed, unquote(expected_message)} =
               Validation.validate(
                 %{http_client: fn _opts -> flunk("HTTP client must not be called") end},
                 connection
               )
    end
  end

  test "rejects a hostname with a private DNS answer before making an HTTP request" do
    connection =
      connection_with_discovery_uri("https://idp.example/.well-known/openid-configuration")

    assert {:error, :validation_failed, "OIDC discovery host resolves to a private address."} =
             Validation.validate(
               %{
                 dns_resolver: fn _host -> {:ok, [{10, 0, 0, 1}]} end,
                 http_client: fn _opts -> flunk("HTTP client must not be called") end
               },
               connection
             )
  end

  defp connection_with_discovery_uri(uri) do
    %TestConnection{
      oidc_settings: %TestOIDCSettings{
        issuer: "https://issuer.example",
        discovery_document_uri: uri,
        client_id: "client-123",
        encrypted_client_secret: "secret",
        client_authentication_method: "client_secret_basic",
        scopes: ["openid", "email"]
      }
    }
  end

  test "rejects configs whose scopes omit openid" do
    connection =
      %TestConnection{
        oidc_settings: %TestOIDCSettings{
          issuer: "https://issuer.example",
          client_id: "client-123",
          encrypted_client_secret: "secret",
          client_authentication_method: "client_secret_basic",
          scopes: ["email"]
        }
      }

    assert {:error, :validation_failed, "Scopes must include openid."} =
             Validation.validate(%{}, connection)
  end
end
