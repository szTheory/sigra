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
      http_client: fn url: _url ->
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
