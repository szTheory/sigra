defmodule Sigra.EnterpriseConnections.ContextTest do
  use ExUnit.Case, async: true

  import Mox

  defmodule TestOrg do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "organizations" do
      field :name, :string
    end
  end

  defmodule TestScope do
    defstruct [:user, :active_organization, :membership]
  end

  defmodule TestOIDCSettings do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :issuer, :string
      field :discovery_document_uri, :string
      field :client_id, :string
      field :encrypted_client_secret, :binary
      field :client_authentication_method, :string, default: "client_secret_basic"
      field :scopes, {:array, :string}, default: ["openid"]
    end

    def changeset(settings, attrs) do
      settings
      |> cast(attrs, [:issuer, :discovery_document_uri, :client_id, :encrypted_client_secret, :client_authentication_method, :scopes])
      |> validate_required([:issuer, :client_id, :encrypted_client_secret, :client_authentication_method])
    end
  end

  defmodule TestConnection do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    schema "enterprise_connections" do
      field :protocol, Ecto.Enum, values: [:oidc], default: :oidc
      field :status, Ecto.Enum, values: [:draft, :validation_failed, :active, :disabled], default: :draft
      field :display_name, :string
      field :login_hint_domains, {:array, :string}, default: []
      field :last_validated_at, :utc_datetime_usec
      field :last_validation_error, :string
      field :organization_id, :binary_id
      embeds_one :oidc_settings, TestOIDCSettings, on_replace: :update
      timestamps(type: :utc_datetime)
    end

    def changeset(connection, attrs) do
      connection
      |> cast(attrs, [:organization_id, :protocol, :status, :display_name, :login_hint_domains, :last_validated_at, :last_validation_error])
      |> validate_required([:organization_id, :protocol, :status, :display_name])
      |> cast_embed(:oidc_settings, required: true, with: &TestOIDCSettings.changeset/2)
    end
  end

  setup :verify_on_exit!

  defp scope(org_id) do
    %TestScope{active_organization: %TestOrg{id: org_id}}
  end

  defp config do
    %{
      repo: Sigra.MockRepo,
      schemas: %{enterprise_connection: TestConnection},
      http_client:
        fn _opts ->
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
  end

  defp valid_attrs do
    %{
      "display_name" => "Acme Workforce",
      "oidc_settings" => %{
        "issuer" => "https://issuer.example",
        "client_id" => "client-123",
        "encrypted_client_secret" => "secret",
        "client_authentication_method" => "client_secret_basic",
        "scopes" => ["openid", "email"]
      }
    }
  end

  test "save_connection forces the active organization onto the persisted row" do
    org_id = Ecto.UUID.generate()

    Sigra.MockRepo
    |> expect(:get_by, fn TestConnection, [organization_id: ^org_id] -> nil end)
    |> expect(:insert, fn changeset ->
      assert Ecto.Changeset.get_change(changeset, :organization_id) == org_id
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end)

    assert {:ok, connection} =
             Sigra.EnterpriseConnections.save_connection(config(), scope(org_id), valid_attrs())
    assert connection.organization_id == org_id
  end

  test "disable_connection rejects mutating another organization's connection" do
    foreign =
      struct(TestConnection,
        id: Ecto.UUID.generate(),
        organization_id: Ecto.UUID.generate(),
        status: :active,
        protocol: :oidc,
        display_name: "Foreign"
      )

    assert {:error, :forbidden} =
             Sigra.EnterpriseConnections.disable_connection(
               config(),
               scope(Ecto.UUID.generate()),
               foreign
             )
  end
end
